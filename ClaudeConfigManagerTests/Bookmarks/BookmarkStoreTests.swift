import XCTest
@testable import ClaudeConfigManager

final class BookmarkStoreTests: XCTestCase {
    func testUpsertStoresRecordAndBookmarkBlob() throws {
        let persistence = InMemoryBookmarkPersistence()
        let dataCoder = MockBookmarkDataCoder(
            dataByURL: ["/tmp/global": Data("blob".utf8)],
            resolvedByData: [:]
        )
        let access = MockSecurityScopeAccessManager()
        let store = BookmarkStore(persistence: persistence, dataCoder: dataCoder, accessManager: access)

        let record = try store.upsertBookmark(
            id: BookmarkStore.globalRootBookmarkID,
            kind: .globalClaudeRoot,
            folderURL: URL(fileURLWithPath: "/tmp/global"),
            displayName: "Global Root"
        )

        XCTAssertEqual(record.id, BookmarkStore.globalRootBookmarkID)
        XCTAssertEqual(record.kind, .globalClaudeRoot)

        let records = try store.allRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.displayName, "Global Root")

        let blob = try persistence.loadBookmarkData(for: BookmarkStore.globalRootBookmarkID)
        XCTAssertEqual(blob, Data("blob".utf8))
    }

    func testRestoreMarksMissingBlobForReauthorization() throws {
        let persistence = InMemoryBookmarkPersistence()
        let dataCoder = MockBookmarkDataCoder(
            dataByURL: ["/tmp/project": Data("missing".utf8)],
            resolvedByData: [:]
        )
        let access = MockSecurityScopeAccessManager()
        let store = BookmarkStore(persistence: persistence, dataCoder: dataCoder, accessManager: access)

        _ = try store.upsertBookmark(
            id: "project-one",
            kind: .projectRoot,
            folderURL: URL(fileURLWithPath: "/tmp/project"),
            displayName: "Project"
        )
        try persistence.removeBookmarkData(for: "project-one")

        let results = try store.restoreAccessToKnownFolders()
        XCTAssertEqual(results.count, 1)

        guard case .requiresReauthorization(let reason, let resolvedURL) = results[0].status else {
            return XCTFail("Expected reauthorization result")
        }

        XCTAssertEqual(reason, .missingBookmarkData)
        XCTAssertNil(resolvedURL)
    }

    func testRestoreMarksStaleBookmarkForReauthorization() throws {
        let staleData = Data("stale".utf8)
        let persistence = InMemoryBookmarkPersistence()
        let dataCoder = MockBookmarkDataCoder(
            dataByURL: ["/tmp/project": staleData],
            resolvedByData: [
                staleData: ResolvedBookmark(url: URL(fileURLWithPath: "/tmp/project"), isStale: true)
            ]
        )
        let access = MockSecurityScopeAccessManager()
        let store = BookmarkStore(persistence: persistence, dataCoder: dataCoder, accessManager: access)

        _ = try store.upsertBookmark(
            id: "project-one",
            kind: .projectRoot,
            folderURL: URL(fileURLWithPath: "/tmp/project")
        )

        let result = try XCTUnwrap(try store.resolveBookmark(id: "project-one"))

        guard case .requiresReauthorization(let reason, let resolvedURL) = result.status else {
            return XCTFail("Expected stale bookmark reauthorization")
        }

        XCTAssertEqual(reason, .staleBookmark)
        XCTAssertEqual(resolvedURL, URL(fileURLWithPath: "/tmp/project"))
    }

    func testRestoreStartsSecurityScopeForAccessibleBookmark() throws {
        let bookmarkData = Data("ok".utf8)
        let persistence = InMemoryBookmarkPersistence()
        let dataCoder = MockBookmarkDataCoder(
            dataByURL: ["/tmp/project": bookmarkData],
            resolvedByData: [
                bookmarkData: ResolvedBookmark(url: URL(fileURLWithPath: "/tmp/project"), isStale: false)
            ]
        )
        let access = MockSecurityScopeAccessManager(startResult: true)
        let store = BookmarkStore(persistence: persistence, dataCoder: dataCoder, accessManager: access)

        _ = try store.upsertBookmark(
            id: "project-one",
            kind: .projectRoot,
            folderURL: URL(fileURLWithPath: "/tmp/project")
        )

        let result = try XCTUnwrap(try store.resolveBookmark(id: "project-one"))

        guard case .accessible(let url) = result.status else {
            return XCTFail("Expected accessible bookmark")
        }

        XCTAssertEqual(url, URL(fileURLWithPath: "/tmp/project"))
        XCTAssertEqual(access.startedURLs, [URL(fileURLWithPath: "/tmp/project")])
    }

    func testRemoveBookmarkDeletesRecordAndBlob() throws {
        let bookmarkData = Data("ok".utf8)
        let persistence = InMemoryBookmarkPersistence()
        let dataCoder = MockBookmarkDataCoder(dataByURL: ["/tmp/project": bookmarkData], resolvedByData: [:])
        let access = MockSecurityScopeAccessManager()
        let store = BookmarkStore(persistence: persistence, dataCoder: dataCoder, accessManager: access)

        _ = try store.upsertBookmark(
            id: "project-one",
            kind: .projectRoot,
            folderURL: URL(fileURLWithPath: "/tmp/project")
        )

        try store.removeBookmark(id: "project-one")

        XCTAssertTrue(try store.allRecords().isEmpty)
        XCTAssertNil(try persistence.loadBookmarkData(for: "project-one"))
    }

    func testProjectRegistryPreventsDuplicateNormalizedPath() throws {
        let persistence = InMemoryBookmarkPersistence()
        let dataCoder = MockBookmarkDataCoder(
            dataByURL: [
                "/tmp/project-alpha": Data("alpha".utf8)
            ],
            resolvedByData: [:]
        )
        let access = MockSecurityScopeAccessManager()
        let bookmarkStore = BookmarkStore(persistence: persistence, dataCoder: dataCoder, accessManager: access)
        let stateStore = GlobalStateStore(persistence: InMemoryGlobalStatePersistence())
        let registry = ProjectRegistry(bookmarkStore: bookmarkStore, globalStateStore: stateStore)

        let first = try registry.addProject(folderURL: URL(fileURLWithPath: "/tmp/project-alpha/"))
        XCTAssertFalse(first.wasDuplicate)

        let duplicate = try registry.addProject(folderURL: URL(fileURLWithPath: "/tmp/project-alpha"))
        XCTAssertTrue(duplicate.wasDuplicate)

        let state = try registry.loadState()
        XCTAssertEqual(state.projectRegistrations.count, 1)
    }

    func testProjectRegistryPersistsSelectedProject() throws {
        let persistence = InMemoryBookmarkPersistence()
        let dataCoder = MockBookmarkDataCoder(
            dataByURL: [
                "/tmp/project-a": Data("a".utf8),
                "/tmp/project-b": Data("b".utf8)
            ],
            resolvedByData: [:]
        )
        let access = MockSecurityScopeAccessManager()
        let bookmarkStore = BookmarkStore(persistence: persistence, dataCoder: dataCoder, accessManager: access)
        let stateStore = GlobalStateStore(persistence: InMemoryGlobalStatePersistence())
        let registry = ProjectRegistry(bookmarkStore: bookmarkStore, globalStateStore: stateStore)

        _ = try registry.addProject(folderURL: URL(fileURLWithPath: "/tmp/project-a"))
        let second = try registry.addProject(folderURL: URL(fileURLWithPath: "/tmp/project-b"))
        try registry.setSelectedProject(id: second.registration.id)

        let restored = try registry.loadState()
        XCTAssertEqual(restored.selectedProjectRegistrationID, second.registration.id)
    }

    @MainActor
    func testRootSelectionViewModelRejectsInvalidGlobalRootFolder() {
        let persistence = InMemoryBookmarkPersistence()
        let dataCoder = MockBookmarkDataCoder(dataByURL: [:], resolvedByData: [:])
        let access = MockSecurityScopeAccessManager()
        let bookmarkStore = BookmarkStore(persistence: persistence, dataCoder: dataCoder, accessManager: access)
        let stateStore = GlobalStateStore(persistence: InMemoryGlobalStatePersistence())
        let registry = ProjectRegistry(bookmarkStore: bookmarkStore, globalStateStore: stateStore)
        let selector = MockFolderSelector(
            nextURL: URL(fileURLWithPath: "/tmp/not-claude-root")
        )

        let viewModel = RootSelectionViewModel(
            bookmarkStore: bookmarkStore,
            projectRegistry: registry,
            folderSelector: selector
        )

        viewModel.selectGlobalRootOverride()

        guard case .invalidGlobalRoot(let path) = viewModel.issue else {
            return XCTFail("Expected invalid global root issue")
        }
        XCTAssertEqual(path, "/tmp/not-claude-root")
        XCTAssertEqual(viewModel.globalRootSource, .defaultHomeClaude)
    }
}

private final class InMemoryBookmarkPersistence: BookmarkMetadataPersisting {
    private var records: [BookmarkRecord] = []
    private var blobsByID: [String: Data] = [:]

    func loadRecords() throws -> [BookmarkRecord] {
        records
    }

    func saveRecords(_ records: [BookmarkRecord]) throws {
        self.records = records
    }

    func loadBookmarkData(for id: String) throws -> Data? {
        blobsByID[id]
    }

    func saveBookmarkData(_ data: Data, for id: String) throws {
        blobsByID[id] = data
    }

    func removeBookmarkData(for id: String) throws {
        blobsByID[id] = nil
    }
}

private struct MockBookmarkDataCoder: BookmarkDataCoding {
    let dataByURL: [String: Data]
    let resolvedByData: [Data: ResolvedBookmark]

    func makeBookmarkData(for url: URL) throws -> Data {
        guard let value = dataByURL[url.path] else {
            throw BookmarkError.failedToCreateBookmark
        }
        return value
    }

    func resolveBookmarkData(_ data: Data) throws -> ResolvedBookmark {
        guard let value = resolvedByData[data] else {
            throw BookmarkError.failedToLoadBookmarkData
        }
        return value
    }
}

private final class MockSecurityScopeAccessManager: SecurityScopedAccessing {
    private let startResult: Bool
    private(set) var startedURLs: [URL] = []
    private(set) var stoppedURLs: [URL] = []

    init(startResult: Bool = true) {
        self.startResult = startResult
    }

    func startAccessing(_ url: URL) -> Bool {
        startedURLs.append(url)
        return startResult
    }

    func stopAccessing(_ url: URL) {
        stoppedURLs.append(url)
    }
}

@MainActor
private final class MockFolderSelector: FolderSelecting {
    var nextURL: URL?

    init(nextURL: URL?) {
        self.nextURL = nextURL
    }

    func selectFolder(
        title: String,
        message: String,
        prompt: String,
        initialDirectory: URL?
    ) -> URL? {
        nextURL
    }
}

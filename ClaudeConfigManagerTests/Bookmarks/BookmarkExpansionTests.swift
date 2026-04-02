import XCTest
@testable import ClaudeConfigManager

final class BookmarkExpansionTests: XCTestCase {

    // MARK: - BookmarkKind new cases

    func testBookmarkKindUserClaudeJsonRawValue() {
        XCTAssertEqual(BookmarkKind.userClaudeJson.rawValue, "userClaudeJson")
    }

    func testBookmarkKindEtcClaudeCodeRootRawValue() {
        XCTAssertEqual(BookmarkKind.etcClaudeCodeRoot.rawValue, "etcClaudeCodeRoot")
    }

    // MARK: - GlobalAppState new properties default to nil

    func testGlobalAppStateDefaultHasNilUserClaudeJsonBookmarkID() {
        let state = GlobalAppState.default
        XCTAssertNil(state.userClaudeJsonBookmarkID)
    }

    func testGlobalAppStateDefaultHasNilEtcClaudeCodeRootBookmarkID() {
        let state = GlobalAppState.default
        XCTAssertNil(state.etcClaudeCodeRootBookmarkID)
    }

    func testGlobalAppStateDecodesWithoutNewFields() throws {
        // Simulate existing persisted state without the new fields
        let json = """
        {
            "globalClaudeRootSource": "defaultHomeClaude",
            "hasCompletedInitialGlobalRootSetup": false,
            "projectRegistrations": []
        }
        """
        let data = Data(json.utf8)
        let state = try JSONDecoder().decode(GlobalAppState.self, from: data)
        XCTAssertNil(state.userClaudeJsonBookmarkID)
        XCTAssertNil(state.etcClaudeCodeRootBookmarkID)
        XCTAssertNil(state.managedRootBookmarkID)
    }

    // MARK: - BookmarkStore ID constants

    func testBookmarkStoreUserClaudeJsonBookmarkID() {
        XCTAssertEqual(BookmarkStore.userClaudeJsonBookmarkID, "user-claude-json")
    }

    func testBookmarkStoreEtcClaudeCodeRootBookmarkID() {
        XCTAssertEqual(BookmarkStore.etcClaudeCodeRootBookmarkID, "etc-claude-code-root")
    }

    // MARK: - ProjectRegistry: setUserClaudeJson / clearUserClaudeJson

    func testSetUserClaudeJsonCreatesBookmarkAndSavesState() throws {
        let persistence = InMemoryBookmarkPersistence()
        let dataCoder = MockBookmarkDataCoder(
            dataByURL: ["/Users/Test/.claude.json": Data("cjson".utf8)],
            resolvedByData: [:]
        )
        let access = MockSecurityScopeAccessManager()
        let bookmarkStore = BookmarkStore(persistence: persistence, dataCoder: dataCoder, accessManager: access)
        let stateStore = GlobalStateStore(persistence: InMemoryGlobalStatePersistence())
        let registry = ProjectRegistry(bookmarkStore: bookmarkStore, globalStateStore: stateStore)

        try registry.setUserClaudeJson(fileURL: URL(fileURLWithPath: "/Users/Test/.claude.json"))

        let state = try registry.loadState()
        XCTAssertEqual(state.userClaudeJsonBookmarkID, BookmarkStore.userClaudeJsonBookmarkID)

        let records = try bookmarkStore.allRecords()
        XCTAssertTrue(records.contains(where: { $0.id == BookmarkStore.userClaudeJsonBookmarkID && $0.kind == .userClaudeJson }))
    }

    func testClearUserClaudeJsonRemovesBookmarkAndClearsState() throws {
        let persistence = InMemoryBookmarkPersistence()
        let dataCoder = MockBookmarkDataCoder(
            dataByURL: ["/Users/Test/.claude.json": Data("cjson".utf8)],
            resolvedByData: [:]
        )
        let access = MockSecurityScopeAccessManager()
        let bookmarkStore = BookmarkStore(persistence: persistence, dataCoder: dataCoder, accessManager: access)
        let stateStore = GlobalStateStore(persistence: InMemoryGlobalStatePersistence())
        let registry = ProjectRegistry(bookmarkStore: bookmarkStore, globalStateStore: stateStore)

        try registry.setUserClaudeJson(fileURL: URL(fileURLWithPath: "/Users/Test/.claude.json"))
        try registry.clearUserClaudeJson()

        let state = try registry.loadState()
        XCTAssertNil(state.userClaudeJsonBookmarkID)

        let records = try bookmarkStore.allRecords()
        XCTAssertFalse(records.contains(where: { $0.id == BookmarkStore.userClaudeJsonBookmarkID }))
    }

    // MARK: - ProjectRegistry: setEtcClaudeCodeRoot / clearEtcClaudeCodeRoot

    func testSetEtcClaudeCodeRootCreatesBookmarkAndSavesState() throws {
        let persistence = InMemoryBookmarkPersistence()
        let dataCoder = MockBookmarkDataCoder(
            dataByURL: ["/etc/claude-code": Data("etc".utf8)],
            resolvedByData: [:]
        )
        let access = MockSecurityScopeAccessManager()
        let bookmarkStore = BookmarkStore(persistence: persistence, dataCoder: dataCoder, accessManager: access)
        let stateStore = GlobalStateStore(persistence: InMemoryGlobalStatePersistence())
        let registry = ProjectRegistry(bookmarkStore: bookmarkStore, globalStateStore: stateStore)

        try registry.setEtcClaudeCodeRoot(folderURL: URL(fileURLWithPath: "/etc/claude-code"))

        let state = try registry.loadState()
        XCTAssertEqual(state.etcClaudeCodeRootBookmarkID, BookmarkStore.etcClaudeCodeRootBookmarkID)

        let records = try bookmarkStore.allRecords()
        XCTAssertTrue(records.contains(where: { $0.id == BookmarkStore.etcClaudeCodeRootBookmarkID && $0.kind == .etcClaudeCodeRoot }))
    }

    func testClearEtcClaudeCodeRootRemovesBookmarkAndClearsState() throws {
        let persistence = InMemoryBookmarkPersistence()
        let dataCoder = MockBookmarkDataCoder(
            dataByURL: ["/etc/claude-code": Data("etc".utf8)],
            resolvedByData: [:]
        )
        let access = MockSecurityScopeAccessManager()
        let bookmarkStore = BookmarkStore(persistence: persistence, dataCoder: dataCoder, accessManager: access)
        let stateStore = GlobalStateStore(persistence: InMemoryGlobalStatePersistence())
        let registry = ProjectRegistry(bookmarkStore: bookmarkStore, globalStateStore: stateStore)

        try registry.setEtcClaudeCodeRoot(folderURL: URL(fileURLWithPath: "/etc/claude-code"))
        try registry.clearEtcClaudeCodeRoot()

        let state = try registry.loadState()
        XCTAssertNil(state.etcClaudeCodeRootBookmarkID)

        let records = try bookmarkStore.allRecords()
        XCTAssertFalse(records.contains(where: { $0.id == BookmarkStore.etcClaudeCodeRootBookmarkID }))
    }

    // MARK: - RootSelectionViewModel: new authorization flags

    @MainActor
    func testViewModelReflectsUserClaudeJsonAuthorization() throws {
        let persistence = InMemoryBookmarkPersistence()
        let dataCoder = MockBookmarkDataCoder(
            dataByURL: ["/Users/Test/.claude.json": Data("cjson".utf8)],
            resolvedByData: [:]
        )
        let access = MockSecurityScopeAccessManager()
        let bookmarkStore = BookmarkStore(persistence: persistence, dataCoder: dataCoder, accessManager: access)
        let stateStore = GlobalStateStore(persistence: InMemoryGlobalStatePersistence())
        let registry = ProjectRegistry(bookmarkStore: bookmarkStore, globalStateStore: stateStore)
        let selector = MockFolderSelector(nextURL: nil)

        let viewModel = RootSelectionViewModel(
            bookmarkStore: bookmarkStore,
            projectRegistry: registry,
            folderSelector: selector,
            accessChecker: MockAccessChecker(statusesByPath: [:])
        )

        XCTAssertFalse(viewModel.hasAuthorizedUserClaudeJson)

        try registry.setUserClaudeJson(fileURL: URL(fileURLWithPath: "/Users/Test/.claude.json"))
        viewModel.refreshFromStores()

        XCTAssertTrue(viewModel.hasAuthorizedUserClaudeJson)
    }

    @MainActor
    func testViewModelReflectsEtcClaudeCodeRootAuthorization() throws {
        let persistence = InMemoryBookmarkPersistence()
        let dataCoder = MockBookmarkDataCoder(
            dataByURL: ["/etc/claude-code": Data("etc".utf8)],
            resolvedByData: [:]
        )
        let access = MockSecurityScopeAccessManager()
        let bookmarkStore = BookmarkStore(persistence: persistence, dataCoder: dataCoder, accessManager: access)
        let stateStore = GlobalStateStore(persistence: InMemoryGlobalStatePersistence())
        let registry = ProjectRegistry(bookmarkStore: bookmarkStore, globalStateStore: stateStore)
        let selector = MockFolderSelector(nextURL: nil)

        let viewModel = RootSelectionViewModel(
            bookmarkStore: bookmarkStore,
            projectRegistry: registry,
            folderSelector: selector,
            accessChecker: MockAccessChecker(statusesByPath: [:])
        )

        XCTAssertFalse(viewModel.hasAuthorizedEtcClaudeCodeRoot)

        try registry.setEtcClaudeCodeRoot(folderURL: URL(fileURLWithPath: "/etc/claude-code"))
        viewModel.refreshFromStores()

        XCTAssertTrue(viewModel.hasAuthorizedEtcClaudeCodeRoot)
    }

    @MainActor
    func testViewModelClearUserClaudeJsonResetsFlag() throws {
        let persistence = InMemoryBookmarkPersistence()
        let dataCoder = MockBookmarkDataCoder(
            dataByURL: ["/Users/Test/.claude.json": Data("cjson".utf8)],
            resolvedByData: [:]
        )
        let access = MockSecurityScopeAccessManager()
        let bookmarkStore = BookmarkStore(persistence: persistence, dataCoder: dataCoder, accessManager: access)
        let stateStore = GlobalStateStore(persistence: InMemoryGlobalStatePersistence())
        let registry = ProjectRegistry(bookmarkStore: bookmarkStore, globalStateStore: stateStore)
        let selector = MockFolderSelector(nextURL: URL(fileURLWithPath: "/Users/Test/.claude.json"))

        let viewModel = RootSelectionViewModel(
            bookmarkStore: bookmarkStore,
            projectRegistry: registry,
            folderSelector: selector,
            accessChecker: MockAccessChecker(statusesByPath: [:])
        )

        // Authorize
        try registry.setUserClaudeJson(fileURL: URL(fileURLWithPath: "/Users/Test/.claude.json"))
        viewModel.refreshFromStores()
        XCTAssertTrue(viewModel.hasAuthorizedUserClaudeJson)

        // Clear
        viewModel.clearUserClaudeJsonSelection()
        XCTAssertFalse(viewModel.hasAuthorizedUserClaudeJson)
    }

    @MainActor
    func testViewModelClearEtcClaudeCodeRootResetsFlag() throws {
        let persistence = InMemoryBookmarkPersistence()
        let dataCoder = MockBookmarkDataCoder(
            dataByURL: ["/etc/claude-code": Data("etc".utf8)],
            resolvedByData: [:]
        )
        let access = MockSecurityScopeAccessManager()
        let bookmarkStore = BookmarkStore(persistence: persistence, dataCoder: dataCoder, accessManager: access)
        let stateStore = GlobalStateStore(persistence: InMemoryGlobalStatePersistence())
        let registry = ProjectRegistry(bookmarkStore: bookmarkStore, globalStateStore: stateStore)
        let selector = MockFolderSelector(nextURL: URL(fileURLWithPath: "/etc/claude-code"))

        let viewModel = RootSelectionViewModel(
            bookmarkStore: bookmarkStore,
            projectRegistry: registry,
            folderSelector: selector,
            accessChecker: MockAccessChecker(statusesByPath: [:])
        )

        // Authorize
        try registry.setEtcClaudeCodeRoot(folderURL: URL(fileURLWithPath: "/etc/claude-code"))
        viewModel.refreshFromStores()
        XCTAssertTrue(viewModel.hasAuthorizedEtcClaudeCodeRoot)

        // Clear
        viewModel.clearEtcClaudeCodeRootSelection()
        XCTAssertFalse(viewModel.hasAuthorizedEtcClaudeCodeRoot)
    }
}

// MARK: - Test Doubles (duplicated from BookmarkStoreTests as they are file-private)

private final class InMemoryBookmarkPersistence: BookmarkMetadataPersisting {
    private var records: [BookmarkRecord] = []
    private var blobsByID: [String: Data] = [:]

    func loadRecords() throws -> [BookmarkRecord] { records }
    func saveRecords(_ records: [BookmarkRecord]) throws { self.records = records }
    func loadBookmarkData(for id: String) throws -> Data? { blobsByID[id] }
    func saveBookmarkData(_ data: Data, for id: String) throws { blobsByID[id] = data }
    func removeBookmarkData(for id: String) throws { blobsByID[id] = nil }
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

    init(startResult: Bool = true) { self.startResult = startResult }

    func startAccessing(_ url: URL) -> Bool {
        startedURLs.append(url)
        return startResult
    }

    func stopAccessing(_ url: URL) {
        stoppedURLs.append(url)
    }
}

private struct MockAccessChecker: RootDirectoryAccessChecking {
    let statusesByPath: [String: RootAccessStatus]

    func accessStatus(forDirectoryAt url: URL) -> RootAccessStatus {
        let normalizedPath = RootLocator.normalizedIdentityPath(url.path)
        return statusesByPath[normalizedPath] ?? .inaccessible
    }
}

@MainActor
private final class MockFolderSelector: FolderSelecting {
    var nextURL: URL?

    init(nextURL: URL?) { self.nextURL = nextURL }

    func selectFolder(
        title: String,
        message: String,
        prompt: String,
        initialDirectory: URL?,
        showsHiddenFiles: Bool
    ) async -> URL? {
        nextURL
    }
}

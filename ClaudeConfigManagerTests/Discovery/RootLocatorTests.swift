import XCTest
@testable import ClaudeConfigManager

final class RootLocatorTests: XCTestCase {
    func testResolvesAccessibleOverrideAsEffectiveGlobalRoot() {
        let state = GlobalAppState(
            globalClaudeRootSource: .overrideBookmark,
            globalClaudeRootBookmarkID: BookmarkStore.globalRootBookmarkID,
            projectRegistrations: [],
            selectedProjectRegistrationID: nil
        )

        let bookmarkResolver = MockRootBookmarkResolver(
            resultsByID: [
                BookmarkStore.globalRootBookmarkID: BookmarkResolutionResult(
                    record: BookmarkRecord(
                        id: BookmarkStore.globalRootBookmarkID,
                        kind: .globalClaudeRoot,
                        displayName: "Global Override",
                        preferredPath: "/Users/Test/.claude"
                    ),
                    status: .accessible(url: URL(fileURLWithPath: "/Users/Test/.claude/"))
                )
            ]
        )

        let accessChecker = MockRootDirectoryAccessChecker(
            statusesByPath: [
                "/users/test/.claude": .accessible,
                "/users/default/.claude": .accessible
            ]
        )

        let locator = RootLocator(
            bookmarkResolver: bookmarkResolver,
            accessChecker: accessChecker,
            homeDirectoryProvider: { URL(fileURLWithPath: "/Users/Default") }
        )

        let result = locator.resolveRoots(state: state)

        XCTAssertEqual(result.globalRoot.source, .overrideBookmark)
        XCTAssertEqual(result.globalRoot.normalizedPath, "/users/test/.claude")
        XCTAssertEqual(result.globalRoot.accessStatus, .accessible)
        XCTAssertTrue(result.issues.isEmpty)
    }

    func testFallsBackToDefaultWhenOverrideNeedsReauthorization() {
        let state = GlobalAppState(
            globalClaudeRootSource: .overrideBookmark,
            globalClaudeRootBookmarkID: BookmarkStore.globalRootBookmarkID,
            projectRegistrations: [],
            selectedProjectRegistrationID: nil
        )

        let bookmarkResolver = MockRootBookmarkResolver(
            resultsByID: [
                BookmarkStore.globalRootBookmarkID: BookmarkResolutionResult(
                    record: BookmarkRecord(
                        id: BookmarkStore.globalRootBookmarkID,
                        kind: .globalClaudeRoot,
                        displayName: "Global Override",
                        preferredPath: "/Users/Test/.claude"
                    ),
                    status: .requiresReauthorization(reason: .staleBookmark, resolvedURL: URL(fileURLWithPath: "/Users/Test/.claude"))
                )
            ]
        )

        let accessChecker = MockRootDirectoryAccessChecker(
            statusesByPath: [
                "/users/default/.claude": .accessible
            ]
        )

        let locator = RootLocator(
            bookmarkResolver: bookmarkResolver,
            accessChecker: accessChecker,
            homeDirectoryProvider: { URL(fileURLWithPath: "/Users/Default") }
        )

        let result = locator.resolveRoots(state: state)

        XCTAssertEqual(result.globalRoot.source, .defaultHomeClaude)
        XCTAssertEqual(result.globalRoot.normalizedPath, "/users/default/.claude")
        XCTAssertEqual(result.issues.count, 1)
        XCTAssertEqual(result.issues.first?.kind, .globalOverrideRequiresReauthorization)
    }

    func testGlobalRootIsUnresolvedWhenOverrideMissingAndDefaultInaccessible() {
        let state = GlobalAppState(
            globalClaudeRootSource: .overrideBookmark,
            globalClaudeRootBookmarkID: BookmarkStore.globalRootBookmarkID,
            projectRegistrations: [],
            selectedProjectRegistrationID: nil
        )

        let bookmarkResolver = MockRootBookmarkResolver(resultsByID: [:])
        let accessChecker = MockRootDirectoryAccessChecker(
            statusesByPath: [
                "/users/default/.claude": .inaccessible
            ]
        )

        let locator = RootLocator(
            bookmarkResolver: bookmarkResolver,
            accessChecker: accessChecker,
            homeDirectoryProvider: { URL(fileURLWithPath: "/Users/Default") }
        )

        let result = locator.resolveRoots(state: state)

        XCTAssertEqual(result.globalRoot.source, .unresolved)
        XCTAssertNil(result.globalRoot.rootURL)
        XCTAssertEqual(result.issues.map(\.kind), [.defaultRootInaccessible, .globalOverrideMissingBookmark])
    }

    func testNormalizesProjectRootsIntoStableReferences() {
        let state = GlobalAppState(
            globalClaudeRootSource: .defaultHomeClaude,
            globalClaudeRootBookmarkID: nil,
            projectRegistrations: [
                ProjectRegistration(
                    id: "project-b",
                    displayName: "Beta",
                    preferredPath: "/Users/Test/Work/BETA/",
                    normalizedPath: "ignored",
                    createdAt: .distantPast,
                    updatedAt: .distantPast
                ),
                ProjectRegistration(
                    id: "project-a",
                    displayName: "Alpha",
                    preferredPath: "/Users/Test/Work/alpha",
                    normalizedPath: "ignored",
                    createdAt: .distantPast,
                    updatedAt: .distantPast
                )
            ],
            selectedProjectRegistrationID: nil
        )

        let accessChecker = MockRootDirectoryAccessChecker(
            statusesByPath: [
                "/users/default/.claude": .accessible,
                "/users/test/work/alpha": .accessible,
                "/users/test/work/beta": .missing
            ]
        )

        let locator = RootLocator(
            bookmarkResolver: MockRootBookmarkResolver(resultsByID: [:]),
            accessChecker: accessChecker,
            homeDirectoryProvider: { URL(fileURLWithPath: "/Users/Default") }
        )

        let result = locator.resolveRoots(state: state)

        XCTAssertEqual(result.projectRoots.map(\.reference.id), ["project-a", "project-b"])
        XCTAssertEqual(result.projectRoots[0].reference.normalizedPath, "/users/test/work/alpha")
        XCTAssertEqual(result.projectRoots[1].reference.normalizedPath, "/users/test/work/beta")
        XCTAssertEqual(result.projectRoots[1].accessStatus, .missing)
    }
}

private struct MockRootBookmarkResolver: RootBookmarkResolving {
    let resultsByID: [String: BookmarkResolutionResult]

    func resolveBookmark(id: String) throws -> BookmarkResolutionResult? {
        resultsByID[id]
    }
}

private struct MockRootDirectoryAccessChecker: RootDirectoryAccessChecking {
    let statusesByPath: [String: RootAccessStatus]

    func accessStatus(forDirectoryAt url: URL) -> RootAccessStatus {
        let normalizedPath = RootLocator.normalizedIdentityPath(url.path)
        return statusesByPath[normalizedPath] ?? .inaccessible
    }
}

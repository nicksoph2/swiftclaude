import XCTest
@testable import ClaudeConfigManager

final class EtcManagedScanTests: XCTestCase {

    // MARK: - /etc/claude-code discovery

    func testScanDiscoversManagedFilesFromEtcClaudeCode() throws {
        let roots = makeRootResolution(
            globalRoot: ResolvedGlobalRoot(
                source: .unresolved,
                rootURL: nil,
                normalizedPath: nil,
                accessStatus: .notAuthorized,
                explanation: "test"
            ),
            projectRoots: [],
            issues: []
        )

        let fileSystem = MockWorkspaceScanningFileSystem(
            nodeKindByPath: [
                "/etc/claude-code": .directory,
                "/etc/claude-code/managed-settings.json": .file,
                "/etc/claude-code/claude.md": .file,
                "/etc/claude-code/rules": .directory,
                "/etc/claude-code/rules/team-policy.md": .file,
                "/etc/claude-code/rules/security.md": .file
            ],
            directoryChildrenByPath: [
                "/etc/claude-code/rules": [
                    "/etc/claude-code/rules/team-policy.md",
                    "/etc/claude-code/rules/security.md"
                ]
            ],
            unreadablePaths: [],
            listFailurePaths: []
        )

        let scanner = WorkspaceScanner(
            fileSystem: fileSystem,
            homeDirectoryProvider: { URL(fileURLWithPath: "/Users/Test", isDirectory: true) }
        )

        let result = scanner.scan(ScanRequest(rootResolution: roots))

        let managedWorkspace = try XCTUnwrap(result.managedWorkspace)

        // Check that /etc/claude-code root directory is discovered
        XCTAssertTrue(managedWorkspace.directories.contains(where: {
            $0.kind == .etcManagedRoot && $0.status == .present
        }))

        // Check managed-settings.json from /etc/claude-code
        let etcSettingsFiles = managedWorkspace.files.filter {
            $0.kind == .managedSettingsJSON && $0.url.path.contains("/etc/claude-code")
        }
        XCTAssertEqual(etcSettingsFiles.count, 1)
        XCTAssertEqual(etcSettingsFiles.first?.status, .present)

        // Check CLAUDE.md from /etc/claude-code
        let etcClaudeMdFiles = managedWorkspace.files.filter {
            $0.kind == .managedClaudeMarkdown && $0.url.path.contains("/etc/claude-code")
        }
        XCTAssertEqual(etcClaudeMdFiles.count, 1)
        XCTAssertEqual(etcClaudeMdFiles.first?.status, .present)

        // Check rules/*.md from /etc/claude-code
        let etcRuleFiles = managedWorkspace.files.filter {
            $0.kind == .managedRuleMarkdown && $0.url.path.contains("/etc/claude-code")
        }
        XCTAssertEqual(etcRuleFiles.count, 2)

        // Check rules/ directory is discovered
        let etcRulesDirs = managedWorkspace.directories.filter {
            $0.kind == .managedRulesRoot && $0.url.path.contains("/etc/claude-code")
        }
        XCTAssertEqual(etcRulesDirs.count, 1)
        XCTAssertEqual(etcRulesDirs.first?.status, .present)
    }

    func testScanReportsCanonicalPathsWhenEtcClaudeCodeMissing() throws {
        let roots = makeRootResolution(
            globalRoot: ResolvedGlobalRoot(
                source: .unresolved,
                rootURL: nil,
                normalizedPath: nil,
                accessStatus: .notAuthorized,
                explanation: "test"
            ),
            projectRoots: [],
            issues: []
        )

        let scanner = WorkspaceScanner(
            fileSystem: MockWorkspaceScanningFileSystem(
                nodeKindByPath: [:],
                directoryChildrenByPath: [:],
                unreadablePaths: [],
                listFailurePaths: []
            ),
            homeDirectoryProvider: { URL(fileURLWithPath: "/Users/Test", isDirectory: true) }
        )

        let result = scanner.scan(ScanRequest(rootResolution: roots))
        let managedWorkspace = try XCTUnwrap(result.managedWorkspace)

        // /etc/claude-code root should be missing
        XCTAssertTrue(managedWorkspace.directories.contains(where: {
            $0.kind == .etcManagedRoot && $0.status == .missing
        }))

        // Should still report canonical files as missing
        let etcSettingsFiles = managedWorkspace.files.filter {
            $0.kind == .managedSettingsJSON && $0.url.path.contains("/etc/claude-code")
        }
        XCTAssertEqual(etcSettingsFiles.count, 1)
        XCTAssertEqual(etcSettingsFiles.first?.status, .missing)
    }

    // MARK: - rules/ scanning in primary managed root

    func testScanDiscoversRulesFromPrimaryManagedRoot() throws {
        let roots = makeRootResolution(
            globalRoot: ResolvedGlobalRoot(
                source: .unresolved,
                rootURL: nil,
                normalizedPath: nil,
                accessStatus: .notAuthorized,
                explanation: "test"
            ),
            projectRoots: [],
            issues: []
        )

        let managedFileSystem = MockManagedSettingsFileSystem(
            existingPaths: [
                "/library/application support/claudecode",
                "/library/application support/claudecode/managed-settings.json"
            ],
            directoryPaths: [
                "/library/application support/claudecode"
            ],
            unreadablePaths: [],
            directoryContentsByPath: [:],
            directoryErrorsByPath: [:]
        )

        // The workspace scanner filesystem sees rules/ in the primary managed root
        let fileSystem = MockWorkspaceScanningFileSystem(
            nodeKindByPath: [
                "/library/application support/claudecode/rules": .directory,
                "/library/application support/claudecode/rules/org-policy.md": .file
            ],
            directoryChildrenByPath: [
                "/library/application support/claudecode/rules": [
                    "/Library/Application Support/ClaudeCode/rules/org-policy.md"
                ]
            ],
            unreadablePaths: [],
            listFailurePaths: []
        )

        let scanner = WorkspaceScanner(
            fileSystem: fileSystem,
            managedSettingsLocator: ManagedSettingsLocator(fileSystem: managedFileSystem),
            homeDirectoryProvider: { URL(fileURLWithPath: "/Users/Test", isDirectory: true) }
        )

        let result = scanner.scan(ScanRequest(rootResolution: roots))
        let managedWorkspace = try XCTUnwrap(result.managedWorkspace)

        // Check rules/ directory in primary managed root
        let primaryRulesDirs = managedWorkspace.directories.filter {
            $0.kind == .managedRulesRoot && $0.url.path.contains("ClaudeCode")
        }
        XCTAssertEqual(primaryRulesDirs.count, 1)
        XCTAssertEqual(primaryRulesDirs.first?.status, .present)

        // Check rules/*.md files in primary managed root
        let primaryRuleFiles = managedWorkspace.files.filter {
            $0.kind == .managedRuleMarkdown && $0.url.path.contains("ClaudeCode")
        }
        XCTAssertEqual(primaryRuleFiles.count, 1)
    }

    // MARK: - DiscoveredFileKind / DiscoveredDirectoryKind new cases

    func testManagedRuleMarkdownRawValue() {
        XCTAssertEqual(DiscoveredFileKind.managedRuleMarkdown.rawValue, "managedRuleMarkdown")
    }

    func testManagedRulesRootRawValue() {
        XCTAssertEqual(DiscoveredDirectoryKind.managedRulesRoot.rawValue, "managedRulesRoot")
    }

    func testEtcManagedRootRawValue() {
        XCTAssertEqual(DiscoveredDirectoryKind.etcManagedRoot.rawValue, "etcManagedRoot")
    }

    func testEtcManagedRootPathConstant() {
        XCTAssertEqual(ManagedSettingsLocator.etcManagedRootPath, "/etc/claude-code")
    }

    func testManagedRulesDirectoryNameConstant() {
        XCTAssertEqual(ManagedSettingsLocator.managedRulesDirectoryName, "rules")
    }

    // MARK: - Helpers

    private func makeRootResolution(
        globalRoot: ResolvedGlobalRoot,
        projectRoots: [ResolvedProjectRoot],
        issues: [DiscoveryIssue]
    ) -> RootResolutionResult {
        RootResolutionResult(globalRoot: globalRoot, projectRoots: projectRoots, issues: issues)
    }
}

// MARK: - Test Doubles

private struct MockWorkspaceScanningFileSystem: WorkspaceScanningFileSystem {
    let nodeKindByPath: [String: WorkspaceScanningNodeKind]
    let directoryChildrenByPath: [String: [String]]
    let unreadablePaths: Set<String>
    let listFailurePaths: Set<String>

    func nodeKind(at url: URL) -> WorkspaceScanningNodeKind {
        nodeKindByPath[normalizedPath(url)] ?? .missing
    }

    func isReadable(at url: URL) -> Bool {
        !unreadablePaths.contains(normalizedPath(url))
    }

    func contentsOfDirectory(at url: URL) throws -> [URL] {
        let path = normalizedPath(url)
        if listFailurePaths.contains(path) {
            throw NSError(domain: "MockWorkspaceScanningFileSystem", code: 13)
        }
        return (directoryChildrenByPath[path] ?? []).map { URL(fileURLWithPath: $0) }
    }

    private func normalizedPath(_ url: URL) -> String {
        RootLocator.normalizedIdentityPath(url.path)
    }
}

private struct MockManagedSettingsFileSystem: ManagedSettingsFileSystem {
    let existingPaths: Set<String>
    let directoryPaths: Set<String>
    let unreadablePaths: Set<String>
    let directoryContentsByPath: [String: [String]]
    let directoryErrorsByPath: [String: NSError]

    func fileExists(atPath: String) -> Bool {
        existingPaths.contains(normalized(atPath))
    }

    func isReadable(atPath: String) -> Bool {
        existingPaths.contains(normalized(atPath)) && !unreadablePaths.contains(normalized(atPath))
    }

    func contentsOfDirectory(atPath: String, error: inout NSError?) -> [String] {
        let path = normalized(atPath)
        if let directoryError = directoryErrorsByPath[path] {
            error = directoryError
            return []
        }
        return directoryContentsByPath[path] ?? []
    }

    func fileExists(atPath: String, isDirectory: inout ObjCBool) -> Bool {
        let path = normalized(atPath)
        let exists = existingPaths.contains(path)
        isDirectory = ObjCBool(directoryPaths.contains(path))
        return exists
    }

    private func normalized(_ path: String) -> String {
        RootLocator.normalizedIdentityPath(path)
    }
}

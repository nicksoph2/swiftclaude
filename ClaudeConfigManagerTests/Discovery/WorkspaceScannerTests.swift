import XCTest
@testable import ClaudeConfigManager

final class WorkspaceScannerTests: XCTestCase {
    func testScanClassifiesSupportedClaudePathsAndRecursesDeterministically() throws {
        let roots = makeRootResolution(
            globalRoot: ResolvedGlobalRoot(
                source: .defaultHomeClaude,
                rootURL: URL(fileURLWithPath: "/Users/Test/.claude", isDirectory: true),
                normalizedPath: "/users/test/.claude",
                accessStatus: .accessible,
                explanation: "test"
            ),
            projectRoots: [
                ResolvedProjectRoot(
                    reference: ProjectRootReference(
                        id: "project-a",
                        displayName: "Project A",
                        preferredPath: "/Users/Test/Work/ProjectA",
                        normalizedPath: "/users/test/work/projecta"
                    ),
                    rootURL: URL(fileURLWithPath: "/Users/Test/Work/ProjectA", isDirectory: true),
                    accessStatus: .accessible
                )
            ],
            issues: []
        )

        let fileSystem = MockWorkspaceScanningFileSystem(
            nodeKindByPath: [
                "/users/test/.claude": .directory,
                "/users/test/.claude/settings.json": .file,
                "/users/test/.claude/claude.md": .file,
                "/users/test/.claude/agents": .directory,
                "/users/test/.claude/agents/alpha.md": .file,
                "/users/test/.claude/agents/team": .directory,
                "/users/test/.claude/agents/team/beta.md": .file,
                "/users/test/.claude/agents/ignore.txt": .file,
                "/users/test/.claude/skills": .directory,
                "/users/test/.claude/skills/skill-one": .directory,
                "/users/test/.claude/skills/skill-one/skill.md": .file,
                "/users/test/.claude/skills/skill-one/notes.md": .file,
                "/users/test/.claude/projects": .directory,
                "/users/test/.claude/projects/project-a": .directory,
                "/users/test/.claude/projects/project-a/memory": .directory,
                "/users/test/.claude.json": .file,

                "/users/test/work/projecta": .directory,
                "/users/test/work/projecta/.mcp.json": .file,
                "/users/test/work/projecta/claude.md": .file,
                "/users/test/work/projecta/.claude": .directory,
                "/users/test/work/projecta/.claude/settings.json": .file,
                "/users/test/work/projecta/.claude/settings.local.json": .file,
                "/users/test/work/projecta/.claude/claude.md": .file,
                "/users/test/work/projecta/.claude/agents": .directory,
                "/users/test/work/projecta/.claude/agents/project-agent.md": .file,
                "/users/test/work/projecta/.claude/skills": .directory,
                "/users/test/work/projecta/.claude/skills/skill-project": .directory,
                "/users/test/work/projecta/.claude/skills/skill-project/skill.md": .file
            ],
            directoryChildrenByPath: [
                "/users/test/.claude/agents": [
                    "/Users/Test/.claude/agents/alpha.md",
                    "/Users/Test/.claude/agents/team",
                    "/Users/Test/.claude/agents/ignore.txt"
                ],
                "/users/test/.claude/agents/team": [
                    "/Users/Test/.claude/agents/team/beta.md"
                ],
                "/users/test/.claude/skills": [
                    "/Users/Test/.claude/skills/skill-one"
                ],
                "/users/test/.claude/skills/skill-one": [
                    "/Users/Test/.claude/skills/skill-one/SKILL.md",
                    "/Users/Test/.claude/skills/skill-one/notes.md"
                ],
                "/users/test/.claude/projects": [
                    "/Users/Test/.claude/projects/project-a"
                ],
                "/users/test/work/projecta/.claude/agents": [
                    "/Users/Test/Work/ProjectA/.claude/agents/project-agent.md"
                ],
                "/users/test/work/projecta/.claude/skills": [
                    "/Users/Test/Work/ProjectA/.claude/skills/skill-project"
                ],
                "/users/test/work/projecta/.claude/skills/skill-project": [
                    "/Users/Test/Work/ProjectA/.claude/skills/skill-project/SKILL.md"
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

        let userWorkspace = try XCTUnwrap(result.userWorkspace)
        XCTAssertTrue(result.issues.isEmpty)

        XCTAssertEqual(userWorkspace.files.filter { $0.kind == .userAgentMarkdown }.count, 2)
        XCTAssertEqual(userWorkspace.files.filter { $0.kind == .userSkillDefinition }.count, 1)
        XCTAssertEqual(userWorkspace.directories.filter { $0.kind == .userProjectMemoryDirectory }.count, 1)

        XCTAssertTrue(userWorkspace.files.contains { $0.kind == .userSettingsJSON && $0.status == .present })
        XCTAssertTrue(userWorkspace.files.contains { $0.kind == .userClaudeMarkdown && $0.status == .present })
        XCTAssertTrue(userWorkspace.files.contains { $0.kind == .userClaudeJSON && $0.status == .present })

        let projectWorkspace = try XCTUnwrap(result.projectWorkspaces.first)
        XCTAssertTrue(projectWorkspace.files.contains { $0.kind == .projectSettingsJSON && $0.status == .present })
        XCTAssertTrue(projectWorkspace.files.contains { $0.kind == .projectSettingsLocalJSON && $0.status == .present })
        XCTAssertTrue(projectWorkspace.files.contains { $0.kind == .projectMCPJSON && $0.status == .present })
        XCTAssertTrue(projectWorkspace.files.contains { $0.kind == .projectClaudeMarkdown && $0.status == .present })
        XCTAssertTrue(projectWorkspace.files.contains { $0.kind == .projectClaudeDotMarkdown && $0.status == .present })
        XCTAssertEqual(projectWorkspace.files.filter { $0.kind == .projectAgentMarkdown }.count, 1)
        XCTAssertEqual(projectWorkspace.files.filter { $0.kind == .projectSkillDefinition }.count, 1)

        XCTAssertEqual(
            userWorkspace.files.map(\.normalizedPath),
            userWorkspace.files.map(\.normalizedPath).sorted()
        )
        XCTAssertEqual(
            userWorkspace.directories.map(\.normalizedPath),
            userWorkspace.directories.map(\.normalizedPath).sorted()
        )
    }

    func testScanRepresentsCanonicalPathsWhenRootsAreMissing() throws {
        let roots = makeRootResolution(
            globalRoot: ResolvedGlobalRoot(
                source: .defaultHomeClaude,
                rootURL: URL(fileURLWithPath: "/Users/Test/.claude", isDirectory: true),
                normalizedPath: "/users/test/.claude",
                accessStatus: .missing,
                explanation: "test"
            ),
            projectRoots: [
                ResolvedProjectRoot(
                    reference: ProjectRootReference(
                        id: "project-a",
                        displayName: "Project A",
                        preferredPath: "/Users/Test/Work/ProjectA",
                        normalizedPath: "/users/test/work/projecta"
                    ),
                    rootURL: URL(fileURLWithPath: "/Users/Test/Work/ProjectA", isDirectory: true),
                    accessStatus: .missing
                )
            ],
            issues: []
        )

        let scanner = WorkspaceScanner(
            fileSystem: MockWorkspaceScanningFileSystem(nodeKindByPath: [:], directoryChildrenByPath: [:], unreadablePaths: [], listFailurePaths: []),
            homeDirectoryProvider: { URL(fileURLWithPath: "/Users/Test", isDirectory: true) }
        )

        let result = scanner.scan(ScanRequest(rootResolution: roots))

        let userWorkspace = try XCTUnwrap(result.userWorkspace)
        XCTAssertEqual(userWorkspace.files.filter { $0.status == .missing }.count, 3)
        XCTAssertTrue(userWorkspace.files.allSatisfy { $0.status == .missing })
        XCTAssertTrue(userWorkspace.directories.allSatisfy { $0.status == .missing })
        XCTAssertFalse(userWorkspace.files.contains { $0.kind == .userAgentMarkdown })
        XCTAssertFalse(userWorkspace.files.contains { $0.kind == .userSkillDefinition })

        let projectWorkspace = try XCTUnwrap(result.projectWorkspaces.first)
        XCTAssertEqual(projectWorkspace.files.count, 5)
        XCTAssertTrue(projectWorkspace.files.allSatisfy { $0.status == .missing })
        XCTAssertTrue(projectWorkspace.directories.allSatisfy { $0.status == .missing })
        XCTAssertFalse(projectWorkspace.files.contains { $0.kind == .projectAgentMarkdown })
        XCTAssertFalse(projectWorkspace.files.contains { $0.kind == .projectSkillDefinition })
    }

    func testScanReportsPartialTraversalIssuesAndKeepsOtherResults() throws {
        let preservedIssue = DiscoveryIssue(
            kind: .projectMissingBookmark,
            scope: .projectRoot(projectID: "project-a"),
            message: "Preserved from B1",
            path: "/Users/Test/Work/ProjectA"
        )

        let roots = makeRootResolution(
            globalRoot: ResolvedGlobalRoot(
                source: .defaultHomeClaude,
                rootURL: URL(fileURLWithPath: "/Users/Test/.claude", isDirectory: true),
                normalizedPath: "/users/test/.claude",
                accessStatus: .accessible,
                explanation: "test"
            ),
            projectRoots: [
                ResolvedProjectRoot(
                    reference: ProjectRootReference(
                        id: "project-a",
                        displayName: "Project A",
                        preferredPath: "/Users/Test/Work/ProjectA",
                        normalizedPath: "/users/test/work/projecta"
                    ),
                    rootURL: URL(fileURLWithPath: "/Users/Test/Work/ProjectA", isDirectory: true),
                    accessStatus: .accessible
                )
            ],
            issues: [preservedIssue]
        )

        let fileSystem = MockWorkspaceScanningFileSystem(
            nodeKindByPath: [
                "/users/test/.claude": .directory,
                "/users/test/.claude/settings.json": .file,
                "/users/test/.claude/claude.md": .file,
                "/users/test/.claude/agents": .directory,
                "/users/test/.claude/skills": .directory,
                "/users/test/.claude/skills/skill-one": .directory,
                "/users/test/.claude/skills/skill-one/skill.md": .file,
                "/users/test/.claude/projects": .missing,
                "/users/test/.claude.json": .file,

                "/users/test/work/projecta": .directory,
                "/users/test/work/projecta/.mcp.json": .missing,
                "/users/test/work/projecta/claude.md": .missing,
                "/users/test/work/projecta/.claude": .directory,
                "/users/test/work/projecta/.claude/settings.json": .missing,
                "/users/test/work/projecta/.claude/settings.local.json": .missing,
                "/users/test/work/projecta/.claude/claude.md": .missing,
                "/users/test/work/projecta/.claude/agents": .missing,
                "/users/test/work/projecta/.claude/skills": .missing
            ],
            directoryChildrenByPath: [
                "/users/test/.claude/skills": [
                    "/Users/Test/.claude/skills/skill-one"
                ],
                "/users/test/.claude/skills/skill-one": [
                    "/Users/Test/.claude/skills/skill-one/SKILL.md"
                ]
            ],
            unreadablePaths: [
                "/users/test/.claude/skills/skill-one/skill.md"
            ],
            listFailurePaths: [
                "/users/test/.claude/agents"
            ]
        )

        let scanner = WorkspaceScanner(
            fileSystem: fileSystem,
            homeDirectoryProvider: { URL(fileURLWithPath: "/Users/Test", isDirectory: true) }
        )

        let result = scanner.scan(ScanRequest(rootResolution: roots))

        XCTAssertTrue(result.issues.contains(where: { $0.id == preservedIssue.id }))
        XCTAssertTrue(result.issues.contains(where: { $0.kind == .scanDirectoryEnumerationFailed }))
        XCTAssertTrue(result.issues.contains(where: { $0.kind == .scanDescendantInaccessible }))

        let userWorkspace = try XCTUnwrap(result.userWorkspace)
        XCTAssertTrue(userWorkspace.files.contains { $0.kind == .userSettingsJSON && $0.status == .present })
        XCTAssertTrue(userWorkspace.files.contains { $0.kind == .userSkillDefinition && $0.status == .unreadable })
    }

    private func makeRootResolution(
        globalRoot: ResolvedGlobalRoot,
        projectRoots: [ResolvedProjectRoot],
        issues: [DiscoveryIssue]
    ) -> RootResolutionResult {
        RootResolutionResult(globalRoot: globalRoot, projectRoots: projectRoots, issues: issues)
    }
}

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

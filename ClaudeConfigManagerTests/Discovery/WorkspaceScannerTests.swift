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

    func testScanIncludesManagedWorkspaceWithManagedFiles() throws {
        let roots = makeRootResolution(
            globalRoot: ResolvedGlobalRoot(
                source: .defaultHomeClaude,
                rootURL: URL(fileURLWithPath: "/Users/Test/.claude", isDirectory: true),
                normalizedPath: "/users/test/.claude",
                accessStatus: .missing,
                explanation: "test"
            ),
            projectRoots: [],
            issues: []
        )

        let scanner = WorkspaceScanner(
            fileSystem: MockWorkspaceScanningFileSystem(nodeKindByPath: [:], directoryChildrenByPath: [:], unreadablePaths: [], listFailurePaths: []),
            managedSettingsLocator: ManagedSettingsLocator(
                fileSystem: MockManagedSettingsFileSystem(
                    existingPaths: [
                        "/library/application support/claudecode",
                        "/library/application support/claudecode/managed-settings.json",
                        "/library/application support/claudecode/managed-mcp.json",
                        "/library/application support/claudecode/managed-settings.d",
                        "/library/application support/claudecode/managed-settings.d/02-override.json",
                        "/library/application support/claudecode/managed-settings.d/01-base.json"
                    ],
                    directoryPaths: [
                        "/library/application support/claudecode",
                        "/library/application support/claudecode/managed-settings.d"
                    ],
                    unreadablePaths: [],
                    directoryContentsByPath: [
                        "/library/application support/claudecode/managed-settings.d": [
                            "02-override.json",
                            "01-base.json"
                        ]
                    ],
                    directoryErrorsByPath: [:]
                )
            ),
            homeDirectoryProvider: { URL(fileURLWithPath: "/Users/Test", isDirectory: true) }
        )

        let result = scanner.scan(ScanRequest(rootResolution: roots))

        let managedWorkspace = try XCTUnwrap(result.managedWorkspace)
        XCTAssertEqual(managedWorkspace.scope.scopeKind, .managed)
        XCTAssertEqual(managedWorkspace.rootScope, .managedRoot)
        XCTAssertTrue(managedWorkspace.directories.contains { $0.kind == .managedSettingsRoot && $0.status == .present })
        XCTAssertEqual(
            managedWorkspace.files.map(\.kind),
            [.managedMcpJSON, .managedSettingsDropIn, .managedSettingsDropIn, .managedSettingsJSON]
        )
        XCTAssertTrue(managedWorkspace.files.allSatisfy { $0.scope.scopeKind == .managed })

        let userWorkspace = try XCTUnwrap(result.userWorkspace)
        XCTAssertLessThan(managedWorkspace.scope.stableIdentifier, userWorkspace.scope.stableIdentifier)
    }

    func testScanManagedWorkspaceReportsUnreadableManagedPaths() {
        let roots = makeRootResolution(
            globalRoot: ResolvedGlobalRoot(
                source: .unresolved,
                rootURL: nil,
                normalizedPath: nil,
                accessStatus: .notAuthorized,
                explanation: "none"
            ),
            projectRoots: [],
            issues: []
        )

        let scanner = WorkspaceScanner(
            fileSystem: MockWorkspaceScanningFileSystem(nodeKindByPath: [:], directoryChildrenByPath: [:], unreadablePaths: [], listFailurePaths: []),
            managedSettingsLocator: ManagedSettingsLocator(
                fileSystem: MockManagedSettingsFileSystem(
                    existingPaths: [
                        "/library/application support/claudecode",
                        "/library/application support/claudecode/managed-settings.json",
                        "/library/application support/claudecode/managed-settings.d"
                    ],
                    directoryPaths: [
                        "/library/application support/claudecode",
                        "/library/application support/claudecode/managed-settings.d"
                    ],
                    unreadablePaths: [
                        "/library/application support/claudecode/managed-settings.json",
                        "/library/application support/claudecode/managed-settings.d"
                    ],
                    directoryContentsByPath: [:],
                    directoryErrorsByPath: [:]
                )
            )
        )

        let result = scanner.scan(ScanRequest(rootResolution: roots))

        XCTAssertTrue(result.issues.contains { $0.code == .managedSettingsFileUnreadable })
        XCTAssertTrue(result.issues.contains { $0.code == .managedSettingsDropInInaccessible })
    }

    private func makeRootResolution(
        globalRoot: ResolvedGlobalRoot,
        projectRoots: [ResolvedProjectRoot],
        issues: [DiscoveryIssue]
    ) -> RootResolutionResult {
        RootResolutionResult(globalRoot: globalRoot, projectRoots: projectRoots, issues: issues)
    }
}

final class ManagedSettingsLocatorTests: XCTestCase {
    func testLocateManagedSettingsFile_WhenFileExists_ReturnsURL() {
        let locator = ManagedSettingsLocator(
            fileSystem: MockManagedSettingsFileSystem(
                existingPaths: [
                    "/library/application support/claudecode/managed-settings.json"
                ],
                directoryPaths: [],
                unreadablePaths: [],
                directoryContentsByPath: [:],
                directoryErrorsByPath: [:]
            )
        )

        let url = locator.locateManagedSettingsFile()

        XCTAssertEqual(url?.path, "/Library/Application Support/ClaudeCode/managed-settings.json")
    }

    func testLocateManagedSettingsFile_WhenFileDoesNotExist_ReturnsNil() {
        let locator = ManagedSettingsLocator(
            fileSystem: MockManagedSettingsFileSystem(
                existingPaths: [],
                directoryPaths: [],
                unreadablePaths: [],
                directoryContentsByPath: [:],
                directoryErrorsByPath: [:]
            )
        )

        XCTAssertNil(locator.locateManagedSettingsFile())
    }

    func testLocateManagedSettingsFile_WhenFileUnreadable_ReturnsNil() {
        let locator = ManagedSettingsLocator(
            fileSystem: MockManagedSettingsFileSystem(
                existingPaths: [
                    "/library/application support/claudecode/managed-settings.json"
                ],
                directoryPaths: [],
                unreadablePaths: [
                    "/library/application support/claudecode/managed-settings.json"
                ],
                directoryContentsByPath: [:],
                directoryErrorsByPath: [:]
            )
        )

        XCTAssertNil(locator.locateManagedSettingsFile())
    }

    func testLocateManagedSettingsDirectory_WhenDropInExists_ReturnsSortedURLs() {
        let locator = ManagedSettingsLocator(
            fileSystem: MockManagedSettingsFileSystem(
                existingPaths: [
                    "/library/application support/claudecode/managed-settings.d",
                    "/library/application support/claudecode/managed-settings.d/02-override.json",
                    "/library/application support/claudecode/managed-settings.d/01-base.json",
                    "/library/application support/claudecode/managed-settings.d/03-final.json"
                ],
                directoryPaths: [
                    "/library/application support/claudecode/managed-settings.d"
                ],
                unreadablePaths: [],
                directoryContentsByPath: [
                    "/library/application support/claudecode/managed-settings.d": [
                        "02-override.json",
                        "01-base.json",
                        "03-final.json"
                    ]
                ],
                directoryErrorsByPath: [:]
            )
        )

        XCTAssertEqual(
            locator.locateManagedSettingsDirectory().map(\.lastPathComponent),
            ["01-base.json", "02-override.json", "03-final.json"]
        )
    }

    func testLocateManagedSettingsDirectory_IgnoresNonJsonFiles() {
        let locator = ManagedSettingsLocator(
            fileSystem: MockManagedSettingsFileSystem(
                existingPaths: [
                    "/library/application support/claudecode/managed-settings.d",
                    "/library/application support/claudecode/managed-settings.d/01-base.json",
                    "/library/application support/claudecode/managed-settings.d/readme.txt",
                    "/library/application support/claudecode/managed-settings.d/config.yaml"
                ],
                directoryPaths: [
                    "/library/application support/claudecode/managed-settings.d"
                ],
                unreadablePaths: [],
                directoryContentsByPath: [
                    "/library/application support/claudecode/managed-settings.d": [
                        "01-base.json",
                        "readme.txt",
                        "config.yaml"
                    ]
                ],
                directoryErrorsByPath: [:]
            )
        )

        XCTAssertEqual(locator.locateManagedSettingsDirectory().map(\.lastPathComponent), ["01-base.json"])
    }

    func testLocateManagedSettingsDirectory_WhenDirectoryMissing_ReturnsEmpty() {
        let locator = ManagedSettingsLocator(
            fileSystem: MockManagedSettingsFileSystem(
                existingPaths: [],
                directoryPaths: [],
                unreadablePaths: [],
                directoryContentsByPath: [:],
                directoryErrorsByPath: [:]
            )
        )

        XCTAssertTrue(locator.locateManagedSettingsDirectory().isEmpty)
    }

    func testLocateManagedMcpFile_WhenFileExists_ReturnsURL() {
        let locator = ManagedSettingsLocator(
            fileSystem: MockManagedSettingsFileSystem(
                existingPaths: [
                    "/library/application support/claudecode/managed-mcp.json"
                ],
                directoryPaths: [],
                unreadablePaths: [],
                directoryContentsByPath: [:],
                directoryErrorsByPath: [:]
            )
        )

        XCTAssertEqual(urlPath(locator.locateManagedMcpFile()), "/Library/Application Support/ClaudeCode/managed-mcp.json")
    }

    // MARK: - M4: probeManagedAccessOutcome tests

    func testProbeManagedAccessOutcome_WhenRootReadable_ReturnsAccessible() {
        let locator = ManagedSettingsLocator(
            fileSystem: MockManagedSettingsFileSystem(
                existingPaths: [
                    "/library/application support/claudecode"
                ],
                directoryPaths: [
                    "/library/application support/claudecode"
                ],
                unreadablePaths: [],
                directoryContentsByPath: [:],
                directoryErrorsByPath: [:]
            )
        )

        let outcome = locator.probeManagedAccessOutcome(sandboxProbe: MockSandboxProbe(isSandboxed: false))

        XCTAssertEqual(outcome, .accessible)
        XCTAssertFalse(outcome.requiresExplicitFallbackUI)
    }

    func testProbeManagedAccessOutcome_WhenRootMissing_NotSandboxed_ReturnsMissing() {
        let locator = ManagedSettingsLocator(
            fileSystem: MockManagedSettingsFileSystem(
                existingPaths: [],
                directoryPaths: [],
                unreadablePaths: [],
                directoryContentsByPath: [:],
                directoryErrorsByPath: [:]
            )
        )

        let outcome = locator.probeManagedAccessOutcome(sandboxProbe: MockSandboxProbe(isSandboxed: false))

        XCTAssertEqual(outcome, .missing)
        XCTAssertFalse(outcome.requiresExplicitFallbackUI)
    }

    func testProbeManagedAccessOutcome_WhenRootMissing_InSandbox_ReturnsSandboxRestricted() {
        let locator = ManagedSettingsLocator(
            fileSystem: MockManagedSettingsFileSystem(
                existingPaths: [],
                directoryPaths: [],
                unreadablePaths: [],
                directoryContentsByPath: [:],
                directoryErrorsByPath: [:]
            )
        )

        let outcome = locator.probeManagedAccessOutcome(sandboxProbe: MockSandboxProbe(isSandboxed: true))

        XCTAssertEqual(outcome, .sandboxRestricted)
        XCTAssertTrue(outcome.requiresExplicitFallbackUI)
    }

    func testProbeManagedAccessOutcome_WhenRootUnreadable_NotSandboxed_ReturnsInaccessible() {
        let locator = ManagedSettingsLocator(
            fileSystem: MockManagedSettingsFileSystem(
                existingPaths: [
                    "/library/application support/claudecode"
                ],
                directoryPaths: [
                    "/library/application support/claudecode"
                ],
                unreadablePaths: [
                    "/library/application support/claudecode"
                ],
                directoryContentsByPath: [:],
                directoryErrorsByPath: [:]
            )
        )

        let outcome = locator.probeManagedAccessOutcome(sandboxProbe: MockSandboxProbe(isSandboxed: false))

        if case .inaccessible(let diagnostics) = outcome {
            XCTAssertNotNil(diagnostics)
        } else {
            XCTFail("Expected .inaccessible, got \(outcome)")
        }
        XCTAssertTrue(outcome.requiresExplicitFallbackUI)
    }

    func testProbeManagedAccessOutcome_WhenRootUnreadable_InSandbox_ReturnsSandboxRestricted() {
        let locator = ManagedSettingsLocator(
            fileSystem: MockManagedSettingsFileSystem(
                existingPaths: [
                    "/library/application support/claudecode"
                ],
                directoryPaths: [
                    "/library/application support/claudecode"
                ],
                unreadablePaths: [
                    "/library/application support/claudecode"
                ],
                directoryContentsByPath: [:],
                directoryErrorsByPath: [:]
            )
        )

        let outcome = locator.probeManagedAccessOutcome(sandboxProbe: MockSandboxProbe(isSandboxed: true))

        XCTAssertEqual(outcome, .sandboxRestricted)
        XCTAssertTrue(outcome.requiresExplicitFallbackUI)
    }

    func testProbeManagedAccessOutcome_WhenRootIsAFile_ReturnsInaccessible() {
        // The managed root path points to a file instead of a directory — unusual but handled.
        let locator = ManagedSettingsLocator(
            fileSystem: MockManagedSettingsFileSystem(
                existingPaths: [
                    "/library/application support/claudecode"
                ],
                directoryPaths: [],   // NOT a directory → nodeStatus returns .readableFile or .unreadableFile
                unreadablePaths: [],
                directoryContentsByPath: [:],
                directoryErrorsByPath: [:]
            )
        )

        let outcome = locator.probeManagedAccessOutcome(sandboxProbe: MockSandboxProbe(isSandboxed: false))

        if case .inaccessible = outcome {
            // expected
        } else {
            XCTFail("Expected .inaccessible, got \(outcome)")
        }
        XCTAssertTrue(outcome.requiresExplicitFallbackUI)
    }

    // MARK: - M4: ManagedScopeStatusModel accessOutcome tests

    func testManagedScopeStatusModel_DefaultAccessOutcomeIsMissing() {
        let model = ManagedScopeStatusModel(resolution: nil)
        XCTAssertEqual(model.accessOutcome, .missing)
    }

    func testManagedScopeStatusModel_CarriesSandboxRestrictedOutcome() {
        let model = ManagedScopeStatusModel(resolution: nil, accessOutcome: .sandboxRestricted)
        XCTAssertEqual(model.accessOutcome, .sandboxRestricted)
        XCTAssertTrue(model.accessOutcome.requiresExplicitFallbackUI)
    }

    func testManagedScopeStatusModel_CarriesAccessibleOutcome() {
        let model = ManagedScopeStatusModel(resolution: nil, accessOutcome: .accessible)
        XCTAssertEqual(model.accessOutcome, .accessible)
        XCTAssertFalse(model.accessOutcome.requiresExplicitFallbackUI)
    }

    func testManagedScopeStatusModel_CarriesInaccessibleOutcome() {
        let diagnosticsMessage = "Managed root directory exists but is not readable by this process."
        let model = ManagedScopeStatusModel(
            resolution: nil,
            accessOutcome: .inaccessible(diagnostics: diagnosticsMessage)
        )
        if case .inaccessible(let d) = model.accessOutcome {
            XCTAssertEqual(d, diagnosticsMessage)
        } else {
            XCTFail("Expected .inaccessible outcome")
        }
        XCTAssertTrue(model.accessOutcome.requiresExplicitFallbackUI)
    }

    func testDefaultManagedSettingsFileSystem_DelegatesToFileManager() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = rootURL.appendingPathComponent("managed-settings.json", isDirectory: false)
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        XCTAssertTrue(fileManager.createFile(atPath: fileURL.path, contents: Data("{}".utf8)))
        defer { try? fileManager.removeItem(at: rootURL) }

        let fileSystem = DefaultManagedSettingsFileSystem(fileManager: fileManager)

        XCTAssertTrue(fileSystem.fileExists(atPath: fileURL.path))
        XCTAssertTrue(fileSystem.isReadable(atPath: fileURL.path))

        var error: NSError?
        let contents = fileSystem.contentsOfDirectory(atPath: rootURL.path, error: &error)
        XCTAssertNil(error)
        XCTAssertTrue(contents.contains("managed-settings.json"))

        var isDirectory = ObjCBool(false)
        XCTAssertTrue(fileSystem.fileExists(atPath: rootURL.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testManagedSettingsLocator_WithCustomFileSystem() {
        let locator = ManagedSettingsLocator(
            fileSystem: MockManagedSettingsFileSystem(
                existingPaths: [
                    "/library/application support/claudecode/managed-settings.json",
                    "/library/application support/claudecode/managed-mcp.json"
                ],
                directoryPaths: [],
                unreadablePaths: [],
                directoryContentsByPath: [:],
                directoryErrorsByPath: [:]
            )
        )

        XCTAssertEqual(urlPath(locator.locateManagedSettingsFile()), "/Library/Application Support/ClaudeCode/managed-settings.json")
        XCTAssertEqual(urlPath(locator.locateManagedMcpFile()), "/Library/Application Support/ClaudeCode/managed-mcp.json")
    }

    private func urlPath(_ url: URL?) -> String? {
        url?.path
    }
}

final class MDMPolicyReaderTests: XCTestCase {
    func testReadPoliciesWithEmptyDomain() {
        let reader = MDMPolicyReader(
            userDefaultsReader: { nil },
            cfPreferencesReader: { nil }
        )

        let result = reader.readPolicies()

        XCTAssertEqual(result.value, [:])
        XCTAssertEqual(result.issues, [])
    }

    func testReadPoliciesWithSimpleTypes() {
        let reader = MDMPolicyReader(
            userDefaultsReader: {
                [
                    "stringKey": "value",
                    "numberKey": NSNumber(value: 42),
                    "boolKey": NSNumber(value: true),
                    "nullKey": NSNull()
                ]
            }
        )

        let result = reader.readPolicies()

        XCTAssertEqual(
            result.value,
            [
                "stringKey": .string("value"),
                "numberKey": .number(42),
                "boolKey": .bool(true),
                "nullKey": .null
            ]
        )
        XCTAssertTrue(result.issues.isEmpty)
    }

    func testReadPoliciesWithArrays() {
        let reader = MDMPolicyReader(
            userDefaultsReader: {
                [
                    "stringArray": ["a", "b", "c"],
                    "numberArray": [NSNumber(value: 1), NSNumber(value: 2)],
                    "mixedArray": ["text", NSNumber(value: 42), NSNumber(value: true), NSNull()]
                ]
            }
        )

        let result = reader.readPolicies()

        XCTAssertEqual(
            result.value,
            [
                "stringArray": .array([.string("a"), .string("b"), .string("c")]),
                "numberArray": .array([.number(1), .number(2)]),
                "mixedArray": .array([.string("text"), .number(42), .bool(true), .null])
            ]
        )
        XCTAssertTrue(result.issues.isEmpty)
    }

    func testReadPoliciesWithNestedObjects() {
        let reader = MDMPolicyReader(
            userDefaultsReader: {
                [
                    "config": [
                        "nested": [
                            "value": "deep"
                        ]
                    ]
                ]
            }
        )

        let result = reader.readPolicies()

        XCTAssertEqual(
            result.value,
            [
                "config": .object([
                    "nested": .object([
                        "value": .string("deep")
                    ])
                ])
            ]
        )
        XCTAssertTrue(result.issues.isEmpty)
    }

    func testReadPoliciesWithUnsupportedTypes() {
        let reader = MDMPolicyReader(
            userDefaultsReader: {
                [
                    "dataKey": Data([0x01, 0x02]),
                    "dateKey": Date(timeIntervalSince1970: 0)
                ]
            }
        )

        let result = reader.readPolicies()

        XCTAssertEqual(result.value, [:])
        XCTAssertEqual(result.issues.count, 2)
        XCTAssertTrue(result.issues.allSatisfy { $0.severity == .info })
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .preservedUnknownValue &&
            $0.keyPath == "dataKey" &&
            $0.message.contains("NSData")
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .preservedUnknownValue &&
            $0.keyPath == "dateKey" &&
            $0.message.contains("NSDate")
        }))
    }

    func testReadPoliciesWithMixedValidAndUnsupported() {
        let reader = MDMPolicyReader(
            userDefaultsReader: {
                [
                    "stringKey": "value",
                    "dataKey": Data([0xAA]),
                    "numberKey": NSNumber(value: 7),
                    "dateKey": Date(timeIntervalSince1970: 42)
                ]
            }
        )

        let result = reader.readPolicies()

        XCTAssertEqual(
            result.value,
            [
                "stringKey": .string("value"),
                "numberKey": .number(7)
            ]
        )
        XCTAssertEqual(result.issues.count, 2)
        XCTAssertTrue(result.issues.contains(where: { $0.keyPath == "dataKey" }))
        XCTAssertTrue(result.issues.contains(where: { $0.keyPath == "dateKey" }))
    }

    func testReadPoliciesFallsBackToCFPreferencesWhenUserDefaultsIsEmpty() {
        let reader = MDMPolicyReader(
            userDefaultsReader: { nil },
            cfPreferencesReader: {
                [
                    "managedSetting": "fromCFPreferences"
                ]
            }
        )

        let result = reader.readPolicies()

        XCTAssertEqual(result.value, ["managedSetting": .string("fromCFPreferences")])
        XCTAssertTrue(result.issues.isEmpty)
    }

    func testMDMPolicyReadingProtocolSupportsDependencyInjection() {
        let reader: any MDMPolicyReading = MockMDMPolicyReader(
            result: ParseResult(
                value: ["managed": .bool(true)],
                issues: []
            )
        )

        let result = reader.readPolicies()

        XCTAssertEqual(result.value, ["managed": .bool(true)])
        XCTAssertTrue(result.issues.isEmpty)
    }

    func testMDMFixturesExistForPacketCases() throws {
        let loader = FixtureLoader.shared
        let cases: [FixtureCaseID] = [
            "empty-domain",
            "simple-types",
            "arrays",
            "nested-objects",
            "unsupported-types"
        ]

        for caseID in cases {
            let descriptor = try loader.descriptor(familyPath: "mdm", caseID: caseID)
            XCTAssertTrue(FileManager.default.fileExists(atPath: descriptor.inputDirectoryURL.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: descriptor.expectedDirectoryURL.path))
        }
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

private struct MockMDMPolicyReader: MDMPolicyReading {
    let result: ParseResult<[String: JSONValue]>

    func readPolicies() -> ParseResult<[String: JSONValue]> {
        result
    }
}

/// Test double for `SandboxProbing`. Lets tests inject a fixed sandboxed/non-sandboxed state
/// without relying on the process environment variable.
private struct MockSandboxProbe: SandboxProbing {
    let isSandboxed: Bool

    var isRunningInSandbox: Bool {
        isSandboxed
    }
}

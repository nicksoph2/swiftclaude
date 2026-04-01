import XCTest
@testable import ClaudeConfigManager

final class ResolverModelsTests: XCTestCase {
    func testSettingsResolverAppliesCanonicalPrecedenceLadder() {
        let resolver = SettingsResolver()
        let key = "cleanupPeriodDays"

        let user = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: [key: .number(10)]
        )
        let shared = makeCandidate(
            tier: .projectShared,
            identifier: "project-shared-settings",
            scope: .project,
            sourcePath: "/tmp/project/.claude/settings.json",
            rawTopLevel: [key: .number(20)]
        )
        let local = makeCandidate(
            tier: .projectLocal,
            identifier: "project-local-settings",
            scope: .projectLocal,
            sourcePath: "/tmp/project/.claude/settings.local.json",
            rawTopLevel: [key: .number(30)]
        )
        let cli = makeCandidate(
            tier: .cli,
            identifier: "cli-overrides",
            scope: .cli,
            kind: .cli,
            rawTopLevel: [key: .number(40)]
        )
        let managed = makeCandidate(
            tier: .managed,
            identifier: "managed-policy",
            scope: .managed,
            kind: .managed,
            rawTopLevel: [key: .number(50)]
        )

        let selection = resolver.resolvePrecedence(candidates: [user, shared, local, cli, managed])
        let entry = selection.entries.first(where: { $0.keyPath == key })

        XCTAssertEqual(entry?.winningSource?.identifier, "managed-policy")
        XCTAssertEqual(entry?.participants.map(\.identifier), [
            "managed-policy",
            "cli-overrides",
            "project-local-settings",
            "project-shared-settings",
            "user-settings"
        ])
    }

    func testSettingsResolverFallsBackWhenHigherPrecedenceSourceIsInvalid() {
        let resolver = SettingsResolver()
        let key = "autoMode"

        let invalidLocalSource = ResolutionSource(
            scope: .projectLocal,
            kind: .file,
            identifier: "project-local-settings",
            sourcePath: "/tmp/project/.claude/settings.local.json",
            availability: .invalid
        )
        let invalidLocal = SettingsSourceCandidate(
            tier: .projectLocal,
            source: invalidLocalSource,
            document: nil,
            issues: [
                ResolutionIssue(
                    code: .parserSyntaxIssue,
                    severity: .error,
                    message: "Invalid JSON in project local settings.",
                    source: invalidLocalSource
                )
            ]
        )
        let shared = makeCandidate(
            tier: .projectShared,
            identifier: "project-shared-settings",
            scope: .project,
            sourcePath: "/tmp/project/.claude/settings.json",
            rawTopLevel: [key: .bool(true)]
        )
        let user = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: [key: .bool(false)]
        )

        let selection = resolver.resolvePrecedence(candidates: [user, shared, invalidLocal])
        let entry = selection.entries.first(where: { $0.keyPath == key })

        XCTAssertEqual(entry?.winningSource?.identifier, "project-shared-settings")
        XCTAssertEqual(entry?.participants.map(\.identifier), ["project-shared-settings", "user-settings"])
        XCTAssertTrue(selection.issues.contains(where: { $0.code == .invalidSource && $0.source?.identifier == "project-local-settings" }))
        XCTAssertTrue(selection.issues.contains(where: { $0.code == .parserSyntaxIssue && $0.source?.identifier == "project-local-settings" }))
    }

    func testSettingsResolverUsesStableTieBreakWithinSameTier() {
        let resolver = SettingsResolver()
        let key = "companyAnnouncements"

        let candidateB = makeCandidate(
            tier: .user,
            identifier: "z-user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings-z.json",
            rawTopLevel: [key: .bool(false)]
        )
        let candidateA = makeCandidate(
            tier: .user,
            identifier: "a-user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings-a.json",
            rawTopLevel: [key: .bool(true)]
        )

        let selection = resolver.resolvePrecedence(candidates: [candidateB, candidateA])
        let entry = selection.entries.first(where: { $0.keyPath == key })

        XCTAssertEqual(entry?.winningSource?.identifier, "a-user-settings")
        XCTAssertEqual(entry?.participants.map(\.identifier), ["a-user-settings", "z-user-settings"])
    }

    func testSettingsResolverExcludesClaudeJsonLikeSourceWhenNoSettingsDocumentExists() {
        let resolver = SettingsResolver()
        let claudeJsonSource = ResolutionSource(
            scope: .user,
            kind: .file,
            identifier: "claude-json",
            sourcePath: "/tmp/.claude.json",
            availability: .present
        )

        let candidate = SettingsSourceCandidate(
            tier: .user,
            source: claudeJsonSource,
            document: nil,
            issues: []
        )

        let selection = resolver.resolvePrecedence(candidates: [candidate])

        XCTAssertTrue(selection.entries.isEmpty)
    }

    func testManagedSettingsResolverPrefersServerManagedTierOverMdmAndFileBased() {
        let managedResolver = ManagedSettingsResolver()
        let settingsResolver = SettingsResolver()

        let serverManaged = makeCandidate(
            tier: .managed,
            identifier: "server-managed",
            scope: .managed,
            kind: .managed,
            sourcePath: "/virtual/server-managed.json",
            rawTopLevel: ["cleanupPeriodDays": .number(90)]
        )
        let mdmManaged = makeCandidate(
            tier: .managed,
            identifier: "mdm-managed",
            scope: .managed,
            kind: .managed,
            sourcePath: "/virtual/mdm-policy.json",
            rawTopLevel: ["cleanupPeriodDays": .number(60)]
        )
        let baseManaged = makeCandidate(
            tier: .managed,
            identifier: "managed-settings",
            scope: .managed,
            kind: .managed,
            sourcePath: "/Library/Application Support/ClaudeCode/managed-settings.json",
            rawTopLevel: ["cleanupPeriodDays": .number(30)]
        )

        let resolution = managedResolver.resolve(
            input: ManagedSettingsResolver.Input(
                serverManagedSettings: serverManaged,
                mdmManagedSettings: mdmManaged,
                fileBasedSettings: [baseManaged],
                fileBasedManagedMcp: makeMcpDocument(
                    tier: .managed,
                    scope: .managed,
                    identifier: "managed-mcp",
                    sourcePath: "/Library/Application Support/ClaudeCode/managed-mcp.json",
                    servers: [makeMcpServer(serverID: "filesystem", parseOrder: 0, config: ["command": .string("managed")])]
                )
            )
        )

        XCTAssertEqual(resolution.activeTier?.kind, .serverManaged)
        XCTAssertEqual(resolution.settingsCandidates.map(\.source.identifier), ["server-managed"])
        XCTAssertTrue(resolution.managedMcpDocuments.isEmpty)

        let user = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: ["cleanupPeriodDays": .number(10)]
        )
        let selection = settingsResolver.resolvePrecedence(candidates: resolution.settingsCandidates + [user])
        let entry = selection.entries.first(where: { $0.keyPath == "cleanupPeriodDays" })

        XCTAssertEqual(entry?.winningSource?.identifier, "server-managed")
        XCTAssertEqual(entry?.participants.map(\.identifier), ["server-managed", "user-settings"])
    }

    func testManagedSettingsResolverPrefersMdmTierWhenServerManagedIsAbsent() {
        let managedResolver = ManagedSettingsResolver()
        let settingsResolver = SettingsResolver()

        let mdmManaged = makeCandidate(
            tier: .managed,
            identifier: "mdm-managed",
            scope: .managed,
            kind: .managed,
            sourcePath: "/virtual/mdm-policy.json",
            rawTopLevel: ["cleanupPeriodDays": .number(60)]
        )
        let dropIn = makeCandidate(
            tier: .managed,
            identifier: "drop-in",
            scope: .managed,
            kind: .managed,
            sourcePath: "/Library/Application Support/ClaudeCode/managed-settings.d/10-override.json",
            rawTopLevel: ["cleanupPeriodDays": .number(30)]
        )

        let resolution = managedResolver.resolve(
            input: ManagedSettingsResolver.Input(
                mdmManagedSettings: mdmManaged,
                fileBasedSettings: [dropIn],
                fileBasedManagedMcp: makeMcpDocument(
                    tier: .managed,
                    scope: .managed,
                    identifier: "managed-mcp",
                    sourcePath: "/Library/Application Support/ClaudeCode/managed-mcp.json",
                    servers: [makeMcpServer(serverID: "filesystem", parseOrder: 0, config: ["command": .string("managed")])]
                )
            )
        )

        XCTAssertEqual(resolution.activeTier?.kind, .mdmPolicy)
        XCTAssertEqual(resolution.settingsCandidates.map(\.source.identifier), ["mdm-managed"])
        XCTAssertTrue(resolution.managedMcpDocuments.isEmpty)

        let user = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: ["cleanupPeriodDays": .number(10)]
        )
        let selection = settingsResolver.resolvePrecedence(candidates: resolution.settingsCandidates + [user])
        let entry = selection.entries.first(where: { $0.keyPath == "cleanupPeriodDays" })

        XCTAssertEqual(entry?.winningSource?.identifier, "mdm-managed")
    }

    func testManagedSettingsResolverMergesFileBasedTierDeterministicallyAndIncludesManagedMcp() {
        let managedResolver = ManagedSettingsResolver()
        let settingsResolver = SettingsResolver()
        let mcpResolver = MCPResolver()

        let base = makeCandidate(
            tier: .managed,
            identifier: "managed-settings",
            scope: .managed,
            kind: .managed,
            sourcePath: "/Library/Application Support/ClaudeCode/managed-settings.json",
            rawTopLevel: [
                "cleanupPeriodDays": .number(15),
                "allowedHttpHookUrls": .array([.string("https://hooks.example.com/base")]),
                "env": .object(["BASE": .string("1"), "SHARED": .string("base")])
            ]
        )
        let firstDropIn = makeCandidate(
            tier: .managed,
            identifier: "01-base",
            scope: .managed,
            kind: .managed,
            sourcePath: "/Library/Application Support/ClaudeCode/managed-settings.d/01-base.json",
            rawTopLevel: [
                "cleanupPeriodDays": .number(20),
                "allowedHttpHookUrls": .array([.string("https://hooks.example.com/one")]),
                "env": .object(["SHARED": .string("one")])
            ]
        )
        let secondDropIn = makeCandidate(
            tier: .managed,
            identifier: "02-override",
            scope: .managed,
            kind: .managed,
            sourcePath: "/Library/Application Support/ClaudeCode/managed-settings.d/02-override.json",
            rawTopLevel: [
                "cleanupPeriodDays": .number(30),
                "allowedHttpHookUrls": .array([
                    .string("https://hooks.example.com/one"),
                    .string("https://hooks.example.com/two")
                ]),
                "env": .object(["FINAL": .string("2"), "SHARED": .string("two")])
            ]
        )

        let managedMcp = makeMcpDocument(
            tier: .managed,
            scope: .managed,
            identifier: "managed-mcp",
            sourcePath: "/Library/Application Support/ClaudeCode/managed-mcp.json",
            servers: [
                makeMcpServer(serverID: "filesystem", parseOrder: 0, config: ["command": .string("managed-filesystem")])
            ]
        )

        let resolution = managedResolver.resolve(
            input: ManagedSettingsResolver.Input(
                fileBasedSettings: [secondDropIn, base, firstDropIn],
                fileBasedManagedMcp: managedMcp
            )
        )

        XCTAssertEqual(resolution.activeTier?.kind, .fileBased)
        XCTAssertEqual(
            resolution.settingsCandidates.map(\.source.identifier),
            ["02-override", "01-base", "managed-settings"]
        )
        XCTAssertEqual(resolution.managedMcpDocuments.map(\.source.identifier), ["managed-mcp"])

        let user = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: [
                "cleanupPeriodDays": .number(5),
                "allowedHttpHookUrls": .array([.string("https://hooks.example.com/user")]),
                "env": .object(["USER": .string("1"), "SHARED": .string("user")])
            ]
        )

        let selection = settingsResolver.resolvePrecedence(candidates: resolution.settingsCandidates + [user])
        let snapshot = settingsResolver.buildSnapshot(from: selection)

        XCTAssertEqual(
            tryUnwrapEntry(snapshot: snapshot, keyPath: "cleanupPeriodDays").value.effectiveValue,
            .number(30)
        )
        XCTAssertEqual(
            tryUnwrapEntry(snapshot: snapshot, keyPath: "allowedHttpHookUrls").value.effectiveValue,
            .array([
                .string("https://hooks.example.com/one"),
                .string("https://hooks.example.com/two"),
                .string("https://hooks.example.com/base"),
                .string("https://hooks.example.com/user")
            ])
        )
        XCTAssertEqual(
            tryUnwrapEntry(snapshot: snapshot, keyPath: "env").value.effectiveValue,
            .object([
                "BASE": .string("1"),
                "FINAL": .string("2"),
                "SHARED": .string("two"),
                "USER": .string("1")
            ])
        )

        let mcpSnapshot = mcpResolver.resolve(
            documents: resolution.managedMcpDocuments + [
                makeMcpDocument(
                    tier: .user,
                    scope: .user,
                    identifier: "user-mcp",
                    sourcePath: "/tmp/.claude.json",
                    servers: [
                        makeMcpServer(serverID: "filesystem", parseOrder: 0, config: ["command": .string("user-filesystem")])
                    ]
                )
            ]
        )

        XCTAssertEqual(
            tryUnwrapMcpEntry(snapshot: mcpSnapshot, serverID: "filesystem").resolvedConfig.winningSource?.identifier,
            "user-mcp"
        )
    }

    func testManagedScopeStatusModelReportsActiveTier() {
        let resolution = ManagedSettingsResolution(
            activeTier: ManagedSettingsActiveTier(
                kind: .mdmPolicy,
                sources: [
                    ResolutionSource(
                        scope: .managed,
                        kind: .managed,
                        identifier: "mdm-managed",
                        sourcePath: "com.anthropic.claudecode"
                    )
                ]
            ),
            settingsCandidates: [],
            managedMcpDocuments: []
        )

        let model = ManagedScopeStatusModel(resolution: resolution)

        XCTAssertEqual(model.title, "Active managed tier")
        XCTAssertEqual(model.detail, "MDM / OS policy")
        XCTAssertEqual(model.activeTierLabel, "mdmPolicy")
        XCTAssertEqual(model.sourceSummaries, ["com.anthropic.claudecode"])
    }

    func testSettingsResolverManagedBeatsUser() {
        let resolver = SettingsResolver()
        let key = "cleanupPeriodDays"

        let user = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: [key: .number(10)]
        )
        let managed = makeCandidate(
            tier: .managed,
            identifier: "managed-policy",
            scope: .managed,
            kind: .managed,
            rawTopLevel: [key: .number(50)]
        )

        let selection = resolver.resolvePrecedence(candidates: [user, managed])
        let entry = selection.entries.first(where: { $0.keyPath == key })

        XCTAssertEqual(entry?.winningSource?.identifier, "managed-policy")
        XCTAssertEqual(entry?.participants.map(\.identifier), ["managed-policy", "user-settings"])
    }

    func testSettingsResolverManagedBeatsProject() {
        let resolver = SettingsResolver()
        let key = "autoMode"

        let project = makeCandidate(
            tier: .projectShared,
            identifier: "project-settings",
            scope: .project,
            sourcePath: "/tmp/project/.claude/settings.json",
            rawTopLevel: [key: .bool(true)]
        )
        let managed = makeCandidate(
            tier: .managed,
            identifier: "managed-policy",
            scope: .managed,
            kind: .managed,
            rawTopLevel: [key: .bool(false)]
        )

        let selection = resolver.resolvePrecedence(candidates: [project, managed])
        let entry = selection.entries.first(where: { $0.keyPath == key })

        XCTAssertEqual(entry?.winningSource?.identifier, "managed-policy")
        XCTAssertEqual(entry?.participants.map(\.identifier), ["managed-policy", "project-settings"])
    }

    func testManagedSettingsResolverMdmBeatsFileBased() {
        let managedResolver = ManagedSettingsResolver()
        let key = "cleanupPeriodDays"

        let mdm = makeCandidate(
            tier: .managed,
            identifier: "mdm-policy",
            scope: .managed,
            kind: .managed,
            sourcePath: "com.anthropic.claudecode",
            rawTopLevel: [key: .number(30)]
        )
        let fileBased = makeCandidate(
            tier: .managed,
            identifier: "file-based-managed",
            scope: .managed,
            sourcePath: "/Library/Application Support/ClaudeCode/managed-settings.json",
            rawTopLevel: [key: .number(10)]
        )

        let resolution = managedResolver.resolve(
            input: ManagedSettingsResolver.Input(
                mdmManagedSettings: mdm,
                fileBasedSettings: [fileBased]
            )
        )

        XCTAssertEqual(resolution.activeTier?.kind, .mdmPolicy)
        let winningCandidate = resolution.settingsCandidates.first
        XCTAssertEqual(winningCandidate?.source.identifier, "mdm-policy")
        XCTAssertEqual(winningCandidate?.value(for: key), .number(30))
    }

    func testManagedSettingsResolverFileOverrideBeatBase() {
        let managedResolver = ManagedSettingsResolver()
        let key = "cleanupPeriodDays"

        let fileBase = makeCandidate(
            tier: .managed,
            identifier: "file-base-managed",
            scope: .managed,
            sourcePath: "/Library/Application Support/ClaudeCode/managed-settings.json",
            rawTopLevel: [key: .number(10)]
        )
        let fileOverride = makeCandidate(
            tier: .managed,
            identifier: "file-override-managed",
            scope: .managed,
            sourcePath: "/Library/Application Support/ClaudeCode/managed-settings.d/z_override.json",
            rawTopLevel: [key: .number(20), "otherKey": .string("override")]
        )

        let resolution = managedResolver.resolve(
            input: ManagedSettingsResolver.Input(
                fileBasedSettings: [fileBase, fileOverride]
            )
        )

        XCTAssertEqual(resolution.activeTier?.kind, .fileBased)
        let candidates = resolution.settingsCandidates
        XCTAssertEqual(candidates.count, 2)
        let winningCandidate = candidates.first
        XCTAssertEqual(winningCandidate?.source.identifier, "file-override-managed")
        XCTAssertEqual(winningCandidate?.value(for: key), .number(20))
    }

    func testSettingsResolverBuildSnapshotUsesReplaceMergeMethodForScalarKeys() {
        let resolver = SettingsResolver()
        let candidate = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: ["includeGitInstructions": .bool(true)]
        )

        let selection = resolver.resolvePrecedence(candidates: [candidate])
        let snapshot = resolver.buildSnapshot(from: selection)
        let entry = snapshot.entries.first(where: { $0.keyPath == "includeGitInstructions" })

        XCTAssertEqual(entry?.value.mergeMethod, .replace)
        XCTAssertEqual(entry?.value.winningSource?.identifier, "user-settings")
    }

    func testSettingsResolverDeepMergesEnvWithHigherPrecedenceChildWins() {
        let resolver = SettingsResolver()
        let shared = makeCandidate(
            tier: .projectShared,
            identifier: "project-shared-settings",
            scope: .project,
            sourcePath: "/tmp/project/.claude/settings.json",
            rawTopLevel: [
                "env": .object([
                    "PATH": .string("/usr/bin"),
                    "FOO": .string("shared")
                ])
            ]
        )
        let local = makeCandidate(
            tier: .projectLocal,
            identifier: "project-local-settings",
            scope: .projectLocal,
            sourcePath: "/tmp/project/.claude/settings.local.json",
            rawTopLevel: [
                "env": .object([
                    "FOO": .string("local"),
                    "BAR": .string("local")
                ])
            ]
        )

        let selection = resolver.resolvePrecedence(candidates: [shared, local])
        let snapshot = resolver.buildSnapshot(from: selection)
        let entry = tryUnwrapEntry(snapshot: snapshot, keyPath: "env")

        XCTAssertEqual(entry.value.mergeMethod, .deepMergeObject)
        XCTAssertEqual(entry.value.winningSource?.identifier, "project-local-settings")
        XCTAssertEqual(
            entry.value.effectiveValue,
            .object([
                "PATH": .string("/usr/bin"),
                "FOO": .string("local"),
                "BAR": .string("local")
            ])
        )
    }

    func testSettingsResolverAppendUniqueForAllowedHttpHookUrls() {
        let resolver = SettingsResolver()
        let user = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: [
                "allowedHttpHookUrls": .array([
                    .string("https://hooks.example.com/a"),
                    .string("https://hooks.example.com/b")
                ])
            ]
        )
        let local = makeCandidate(
            tier: .projectLocal,
            identifier: "project-local-settings",
            scope: .projectLocal,
            sourcePath: "/tmp/project/.claude/settings.local.json",
            rawTopLevel: [
                "allowedHttpHookUrls": .array([
                    .string("https://hooks.example.com/b"),
                    .string("https://hooks.example.com/c")
                ])
            ]
        )

        let selection = resolver.resolvePrecedence(candidates: [user, local])
        let snapshot = resolver.buildSnapshot(from: selection)
        let entry = tryUnwrapEntry(snapshot: snapshot, keyPath: "allowedHttpHookUrls")

        XCTAssertEqual(entry.value.mergeMethod, .appendUnique)
        XCTAssertEqual(
            entry.value.effectiveValue,
            .array([
                .string("https://hooks.example.com/b"),
                .string("https://hooks.example.com/c"),
                .string("https://hooks.example.com/a")
            ])
        )
    }

    func testSettingsResolverMergesPermissionsAndReportsAllowDenyOverlap() {
        let resolver = SettingsResolver()
        let user = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: [
                "permissions": .object([
                    "allow": .array([.string("Read(./**)"), .string("Bash(git status)")]),
                    "deny": .array([.string("Bash(rm -rf /)")]),
                    "mode": .string("default")
                ])
            ]
        )
        let local = makeCandidate(
            tier: .projectLocal,
            identifier: "project-local-settings",
            scope: .projectLocal,
            sourcePath: "/tmp/project/.claude/settings.local.json",
            rawTopLevel: [
                "permissions": .object([
                    "allow": .array([.string("Bash(git status)")]),
                    "deny": .array([.string("Bash(git status)")]),
                    "mode": .string("strict")
                ])
            ]
        )

        let selection = resolver.resolvePrecedence(candidates: [user, local])
        let snapshot = resolver.buildSnapshot(from: selection)
        let entry = tryUnwrapEntry(snapshot: snapshot, keyPath: "permissions")

        XCTAssertEqual(entry.value.mergeMethod, .deepMergeObject)
        XCTAssertEqual(entry.value.winningSource?.identifier, "project-local-settings")
        XCTAssertEqual(
            entry.value.effectiveValue,
            .object([
                "allow": .array([.string("Bash(git status)"), .string("Read(./**)")]),
                "deny": .array([.string("Bash(git status)"), .string("Bash(rm -rf /)")]),
                "mode": .string("strict")
            ])
        )
        XCTAssertTrue(entry.value.issues.contains(where: { $0.code == .conflict && $0.keyPath == "permissions" }))
    }

    func testSettingsResolverMergesHooksByEventAndDeduplicatesActions() {
        let resolver = SettingsResolver()
        let user = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: [
                "hooks": .object([
                    "preToolUse": .array([
                        .object(["type": .string("command"), "command": .string("echo user")]),
                        .object(["type": .string("command"), "command": .string("echo shared")])
                    ])
                ])
            ]
        )
        let local = makeCandidate(
            tier: .projectLocal,
            identifier: "project-local-settings",
            scope: .projectLocal,
            sourcePath: "/tmp/project/.claude/settings.local.json",
            rawTopLevel: [
                "hooks": .object([
                    "preToolUse": .array([
                        .object(["type": .string("command"), "command": .string("echo shared")]),
                        .object(["type": .string("command"), "command": .string("echo local")])
                    ])
                ])
            ]
        )

        let selection = resolver.resolvePrecedence(candidates: [user, local])
        let snapshot = resolver.buildSnapshot(from: selection)
        let entry = tryUnwrapEntry(snapshot: snapshot, keyPath: "hooks")

        XCTAssertEqual(entry.value.mergeMethod, .keyedByIdentifier)
        XCTAssertEqual(
            entry.value.effectiveValue,
            .object([
                "PreToolUse": .array([
                    .object(["type": .string("command"), "command": .string("echo shared")]),
                    .object(["type": .string("command"), "command": .string("echo local")]),
                    .object(["type": .string("command"), "command": .string("echo user")])
                ])
            ])
        )
    }

    func testSettingsResolverNormalizesKnownHookEventAliasesToCanonicalCatalogNames() {
        let resolver = SettingsResolver()
        let user = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: [
                "hooks": .object([
                    "preToolUse": .array([
                        .object(["type": .string("command"), "command": .string("echo user")])
                    ])
                ])
            ]
        )
        let local = makeCandidate(
            tier: .projectLocal,
            identifier: "project-local-settings",
            scope: .projectLocal,
            sourcePath: "/tmp/project/.claude/settings.local.json",
            rawTopLevel: [
                "hooks": .object([
                    "PreToolUse": .array([
                        .object(["type": .string("command"), "command": .string("echo local")])
                    ])
                ])
            ]
        )

        let selection = resolver.resolvePrecedence(candidates: [user, local])
        let snapshot = resolver.buildSnapshot(from: selection)
        let entry = tryUnwrapEntry(snapshot: snapshot, keyPath: "hooks")

        XCTAssertEqual(
            entry.value.effectiveValue,
            .object([
                "PreToolUse": .array([
                    .object(["type": .string("command"), "command": .string("echo local")]),
                    .object(["type": .string("command"), "command": .string("echo user")])
                ])
            ])
        )
    }

    func testSettingsResolverFallsBackToUsableObjectWhenHigherPrecedenceShapeMismatches() {
        let resolver = SettingsResolver()
        let user = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: [
                "env": .object(["FOO": .string("user")])
            ]
        )
        let local = makeCandidate(
            tier: .projectLocal,
            identifier: "project-local-settings",
            scope: .projectLocal,
            sourcePath: "/tmp/project/.claude/settings.local.json",
            rawTopLevel: [
                "env": .string("not-an-object")
            ]
        )

        let selection = resolver.resolvePrecedence(candidates: [user, local])
        let snapshot = resolver.buildSnapshot(from: selection)
        let entry = tryUnwrapEntry(snapshot: snapshot, keyPath: "env")

        XCTAssertEqual(entry.value.winningSource?.identifier, "user-settings")
        XCTAssertEqual(entry.value.effectiveValue, .object(["FOO": .string("user")]))
        XCTAssertTrue(entry.value.issues.contains(where: { $0.code == .typeMismatch && $0.source?.identifier == "project-local-settings" }))
    }

    func testSharedFixtureCaseCanBeReusedByResolverSuite() throws {
        let loader = FixtureLoader.shared
        let parser = SettingsParser()

        let userJSON = try loader.loadString(
            familyPath: "shared/settings",
            caseID: "override_project_wins",
            section: "input",
            fileName: "user.settings.json"
        )
        let localJSON = try loader.loadString(
            familyPath: "shared/settings",
            caseID: "override_project_wins",
            section: "input",
            fileName: "project.settings.local.json"
        )

        let userDocument = try XCTUnwrap(
            parser.parse(
                jsonString: userJSON,
                sourceURL: URL(fileURLWithPath: "/tmp/.claude/settings.json", isDirectory: false)
            ).value
        )
        let localDocument = try XCTUnwrap(
            parser.parse(
                jsonString: localJSON,
                sourceURL: URL(fileURLWithPath: "/tmp/project/.claude/settings.local.json", isDirectory: false)
            ).value
        )

        let resolver = SettingsResolver()
        let user = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: userDocument.rawTopLevelObject
        )
        let local = makeCandidate(
            tier: .projectLocal,
            identifier: "project-local-settings",
            scope: .projectLocal,
            sourcePath: "/tmp/project/.claude/settings.local.json",
            rawTopLevel: localDocument.rawTopLevelObject
        )

        let selection = resolver.resolvePrecedence(candidates: [user, local])
        let snapshot = resolver.buildSnapshot(from: selection)
        let cleanupEntry = tryUnwrapEntry(snapshot: snapshot, keyPath: "cleanupPeriodDays")

        XCTAssertEqual(cleanupEntry.value.winningSource?.identifier, "project-local-settings")
        XCTAssertEqual(cleanupEntry.value.effectiveValue, .number(30))
    }

    func testInstructionResolverFixtureCycleAndMissingImportDeterministicOrdering() throws {
        let loader = FixtureLoader.shared
        let parser = ClaudeMdParser()
        let resolver = InstructionResolver(maxImportDepth: 8)
        let caseID: FixtureCaseID = "cycle_and_missing_import"

        let userPath = try fixtureInputPath(
            loader: loader,
            familyPath: "resolvers/instructions",
            caseID: caseID,
            fileName: "user.CLAUDE.md"
        )
        let importAPath = try fixtureInputPath(
            loader: loader,
            familyPath: "resolvers/instructions",
            caseID: caseID,
            fileName: "imports/a.md"
        )
        let importBPath = try fixtureInputPath(
            loader: loader,
            familyPath: "resolvers/instructions",
            caseID: caseID,
            fileName: "imports/b.md"
        )

        let userMarkdown = try loader.loadString(
            familyPath: "resolvers/instructions",
            caseID: caseID,
            section: "input",
            fileName: "user.CLAUDE.md"
        )
        let importAMarkdown = try loader.loadString(
            familyPath: "resolvers/instructions",
            caseID: caseID,
            section: "input",
            fileName: "imports/a.md"
        )
        let importBMarkdown = try loader.loadString(
            familyPath: "resolvers/instructions",
            caseID: caseID,
            section: "input",
            fileName: "imports/b.md"
        )

        let user = makeInstructionCandidate(
            scope: .user,
            identifier: "user-instructions",
            path: userPath,
            parser: parser,
            markdown: userMarkdown
        )
        let importedA = makeInstructionCandidate(
            scope: .imported,
            identifier: "import-a",
            path: importAPath,
            parser: parser,
            markdown: importAMarkdown
        )
        let importedB = makeInstructionCandidate(
            scope: .imported,
            identifier: "import-b",
            path: importBPath,
            parser: parser,
            markdown: importBMarkdown
        )

        let snapshot = resolver.resolve(
            InstructionResolverInput(
                user: user,
                importedDocuments: [importedA, importedB]
            )
        )

        let expected = try loadExpectedJSON(
            loader: loader,
            familyPath: "resolvers/instructions",
            caseID: caseID,
            fileName: "resolution_summary.json",
            as: ExpectedInstructionFixtureSummary.self
        )

        XCTAssertEqual(snapshot.orderedBlocks.count, expected.orderedBlockCount)
        XCTAssertEqual(snapshot.rootLoadOrder.map(\.identifier), expected.rootLoadOrder)
        XCTAssertEqual(snapshot.issues.map { $0.code.rawValue }, expected.issueCodes)
        XCTAssertEqual(snapshot.composedInstructions.mergeMethod, .append)
        XCTAssertEqual(snapshot.composedInstructions.winningSource?.identifier, "user-instructions")

        let blockIDs = snapshot.orderedBlocks.map(\.blockID)
        for suffix in expected.orderedBlockSuffixes {
            XCTAssertTrue(blockIDs.contains(where: { $0.hasSuffix(suffix) }), "Missing expected block suffix: \(suffix)")
        }

        let composed = snapshot.composedInstructions.effectiveValue ?? ""
        for needle in expected.composedContains {
            XCTAssertTrue(composed.contains(needle), "Missing expected instruction segment: \(needle)")
        }
    }

    func testMcpResolverFixtureFallbackAndEnvironmentNotesDeterministic() throws {
        let loader = FixtureLoader.shared
        let caseID: FixtureCaseID = "fallback_and_env_notes"
        let resolver = MCPResolver()

        let localDocument = try makeMcpFixtureDocument(
            loader: loader,
            caseID: caseID,
            fileName: "project-local.mcp.json",
            tier: .local,
            scope: .projectLocal,
            identifier: "local-mcp"
        )
        let projectDocument = try makeMcpFixtureDocument(
            loader: loader,
            caseID: caseID,
            fileName: "project.mcp.json",
            tier: .project,
            scope: .project,
            identifier: "project-mcp"
        )

        let snapshot = resolver.resolve(documents: [localDocument, projectDocument])
        let entry = tryUnwrapMcpEntry(snapshot: snapshot, serverID: "filesystem")

        let expected = try loadExpectedJSON(
            loader: loader,
            familyPath: "resolvers/mcp",
            caseID: caseID,
            fileName: "resolution_summary.json",
            as: ExpectedMcpFixtureSummary.self
        )

        XCTAssertEqual(entry.serverID, expected.serverID)
        XCTAssertEqual(entry.resolvedConfig.winningSource?.identifier, expected.winningSource)
        XCTAssertEqual(entry.resolvedConfig.trace.participants.map { $0.identifier }, expected.participantSources)
        XCTAssertEqual(
            Set(entry.resolvedConfig.issues.map { $0.code.rawValue }),
            Set(expected.issueCodes)
        )
        XCTAssertEqual(entry.resolvedConfig.mergeMethod, MergeMethod.selectHighestPrecedence)
        XCTAssertEqual(
            Set(entry.environmentNotes.map { $0.classification.rawValue }),
            Set(expected.environmentClassifications)
        )
    }

    func testAgentAndSkillResolverFixtureOverrideAndInvalidCases() throws {
        let loader = FixtureLoader.shared
        let caseID: FixtureCaseID = "override_and_invalid_entries"

        let agentParser = AgentParser()
        let skillParser = SkillParser()

        let userAgentMarkdown = try loader.loadString(
            familyPath: "resolvers/agents_skills",
            caseID: caseID,
            section: "input",
            fileName: "user.agent.md"
        )
        let projectAgentMarkdown = try loader.loadString(
            familyPath: "resolvers/agents_skills",
            caseID: caseID,
            section: "input",
            fileName: "project.agent.md"
        )
        let invalidAgentMarkdown = try loader.loadString(
            familyPath: "resolvers/agents_skills",
            caseID: caseID,
            section: "input",
            fileName: "invalid.agent.md"
        )

        let agentSnapshot = AgentResolver().resolve(candidates: [
            makeAgentCandidate(
                tier: .user,
                identifier: "user-agent",
                scope: .user,
                sourcePath: "/tmp/.claude/agents/reviewer.md",
                parser: agentParser,
                markdown: userAgentMarkdown
            ),
            makeAgentCandidate(
                tier: .project,
                identifier: "project-agent",
                scope: .project,
                sourcePath: "/tmp/project/.claude/agents/reviewer.md",
                parser: agentParser,
                markdown: projectAgentMarkdown
            ),
            makeAgentCandidate(
                tier: .project,
                identifier: "invalid-agent",
                scope: .project,
                sourcePath: "/tmp/project/.claude/agents/invalid.md",
                parser: agentParser,
                markdown: invalidAgentMarkdown
            )
        ])

        let userSkillMarkdown = try loader.loadString(
            familyPath: "resolvers/agents_skills",
            caseID: caseID,
            section: "input",
            fileName: "skills/user/research/SKILL.md"
        )
        let projectSkillMarkdown = try loader.loadString(
            familyPath: "resolvers/agents_skills",
            caseID: caseID,
            section: "input",
            fileName: "skills/project/research/SKILL.md"
        )

        let userSkill = makeSkillCandidate(
            tier: .user,
            identifier: "user-skill",
            scope: .user,
            directoryPath: "/tmp/.claude/skills/research",
            parser: skillParser,
            markdown: userSkillMarkdown
        )
        let projectSkill = makeSkillCandidate(
            tier: .project,
            identifier: "project-skill",
            scope: .project,
            directoryPath: "/tmp/project/.claude/skills/research",
            parser: skillParser,
            markdown: projectSkillMarkdown
        )

        let missingSkillSource = ResolutionSource(
            scope: .user,
            kind: .file,
            identifier: "missing-skill",
            sourcePath: "/tmp/.claude/skills/missing",
            availability: .present
        )
        let missingSkillParse = skillParser.parse(
            skillDirectoryURL: URL(fileURLWithPath: "/tmp/.claude/skills/missing"),
            skillMarkdownData: nil
        )
        let missingSkill = SkillDocumentCandidate(
            tier: .user,
            source: missingSkillSource,
            document: missingSkillParse.value,
            issues: missingSkillParse.issues.map { ResolutionIssue(syntaxIssue: $0, source: missingSkillSource) }
        )

        let skillSnapshot = SkillResolver().resolve(candidates: [userSkill, projectSkill, missingSkill])

        let expected = try loadExpectedJSON(
            loader: loader,
            familyPath: "resolvers/agents_skills",
            caseID: caseID,
            fileName: "resolution_summary.json",
            as: ExpectedAgentSkillFixtureSummary.self
        )

        let agentStatesBySource = Dictionary(uniqueKeysWithValues: agentSnapshot.agents.map {
            ($0.source.identifier, $0.visibility.effectiveValue?.rawValue ?? "unavailable")
        })
        let skillStatesBySource = Dictionary(uniqueKeysWithValues: skillSnapshot.skills.map {
            ($0.source.identifier, $0.visibility.effectiveValue?.rawValue ?? "unavailable")
        })

        XCTAssertEqual(agentStatesBySource, expected.agentStatesBySource)
        XCTAssertEqual(skillStatesBySource, expected.skillStatesBySource)
        XCTAssertEqual(
            Set(agentSnapshot.issues.map { $0.code.rawValue }),
            Set(expected.requiredAgentIssueCodes)
        )
        XCTAssertEqual(
            Set(skillSnapshot.issues.map { $0.code.rawValue }),
            Set(expected.requiredSkillIssueCodes)
        )
    }

    func testSessionProjectionFixturePartialSettingsOnlyCase() throws {
        let loader = FixtureLoader.shared
        let parser = SettingsParser()
        let caseID: FixtureCaseID = "partial_settings_only"

        let settingsJSON = try loader.loadString(
            familyPath: "resolvers/projection",
            caseID: caseID,
            section: "input",
            fileName: "settings.json"
        )
        let settingsDocument = try XCTUnwrap(
            parser.parse(
                jsonString: settingsJSON,
                sourceURL: URL(fileURLWithPath: "/tmp/.claude/settings.json", isDirectory: false)
            ).value
        )

        let settingsSnapshot = SettingsResolver().buildSnapshot(
            from: SettingsResolver().resolvePrecedence(candidates: [
                makeCandidate(
                    tier: .user,
                    identifier: "user-settings",
                    scope: .user,
                    sourcePath: "/tmp/.claude/settings.json",
                    rawTopLevel: settingsDocument.rawTopLevelObject
                )
            ])
        )

        let projection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(settings: settingsSnapshot)
        )

        let expected = try loadExpectedJSON(
            loader: loader,
            familyPath: "resolvers/projection",
            caseID: caseID,
            fileName: "projection_summary.json",
            as: ExpectedProjectionFixtureSummary.self
        )

        XCTAssertEqual(projection.completeness.isComplete, expected.isComplete)
        XCTAssertEqual(projection.completeness.missingFamilies.map(\.rawValue), expected.missingFamilies)
        XCTAssertEqual(
            projection.familyStates.filter { $0.availability == .available }.map { $0.family.rawValue },
            expected.availableFamilies
        )
    }

    func testResolutionTraceDeduplicatesParticipantsPreservingFirstSeenOrder() {
        let sourceA = makeSource(identifier: "user-settings", sourcePath: "/tmp/.claude/settings.json")
        let sourceB = makeSource(identifier: "project-settings", scope: .project, sourcePath: "/tmp/project/.claude/settings.json")

        let trace = ResolutionTrace(
            participants: [sourceA, sourceB, sourceA],
            overridden: [sourceB, sourceB],
            notes: ["ordered by precedence"]
        )

        XCTAssertEqual(trace.participants, [sourceA, sourceB])
        XCTAssertEqual(trace.overridden, [sourceB])
        XCTAssertEqual(trace.notes, ["ordered by precedence"])
    }

    func testResolvedSettingsSnapshotSortsEntriesForDeterministicAssertions() {
        let source = makeSource(identifier: "user-settings", sourcePath: "/tmp/.claude/settings.json")

        let zValue = ResolvedValue(
            effectiveValue: JSONValue.bool(true),
            winningSource: source,
            trace: ResolutionTrace(participants: [source]),
            mergeMethod: .replace
        )

        let aValue = ResolvedValue(
            effectiveValue: JSONValue.string("claude"),
            winningSource: source,
            trace: ResolutionTrace(participants: [source]),
            mergeMethod: .replace
        )

        let snapshot = ResolvedSettingsSnapshot(entries: [
            ResolvedSettingsEntry(keyPath: "z.last", value: zValue),
            ResolvedSettingsEntry(keyPath: "a.first", value: aValue)
        ])

        XCTAssertEqual(snapshot.entries.map(\.keyPath), ["a.first", "z.last"])
    }

    func testResolutionIssueFromSyntaxIssuePreservesAttribution() {
        let source = makeSource(identifier: "agent-file", scope: .project, sourcePath: "/tmp/project/.claude/agents/reviewer.md")

        let syntaxIssue = SyntaxIssue(
            code: .invalidYAMLFrontmatter,
            severity: .error,
            message: "Malformed YAML frontmatter at line 2.",
            sourcePath: source.sourcePath ?? "",
            keyPath: "tools",
            range: SourceRange(startLine: 2, startColumn: 1, endLine: 2, endColumn: 12)
        )

        let resolutionIssue = ResolutionIssue(syntaxIssue: syntaxIssue, source: source)

        XCTAssertEqual(resolutionIssue.code, .parserSyntaxIssue)
        XCTAssertEqual(resolutionIssue.severity, .error)
        XCTAssertEqual(resolutionIssue.keyPath, "tools")
        XCTAssertEqual(resolutionIssue.range, syntaxIssue.range)
        XCTAssertEqual(resolutionIssue.source, source)
        XCTAssertEqual(resolutionIssue.underlyingParserCode, SyntaxIssueCode.invalidYAMLFrontmatter.rawValue)
    }

    func testSessionProjectionBuilderBuildsFullProjectionWithDeterministicOrdering() throws {
        let settingsSource = makeSource(identifier: "project-settings", scope: .project, sourcePath: "/tmp/project/.claude/settings.json")
        let instructionSource = makeSource(identifier: "project-claude-md", scope: .project, sourcePath: "/tmp/project/CLAUDE.md")
        let mcpSource = makeSource(identifier: "project-mcp", scope: .project, sourcePath: "/tmp/project/.mcp.json")

        let settingsSnapshot = ResolvedSettingsSnapshot(entries: [
            ResolvedSettingsEntry(
                keyPath: "hooks",
                value: ResolvedValue(
                    effectiveValue: .object([
                        "postToolUse": .array([.string("notify")]),
                        "preToolUse": .array([.string("validate"), .string("lint")])
                    ]),
                    winningSource: settingsSource,
                    trace: ResolutionTrace(participants: [settingsSource]),
                    mergeMethod: .keyedByIdentifier
                )
            ),
            ResolvedSettingsEntry(
                keyPath: "cleanupPeriodDays",
                value: ResolvedValue(
                    effectiveValue: .number(30),
                    winningSource: settingsSource,
                    trace: ResolutionTrace(participants: [settingsSource]),
                    mergeMethod: .replace
                )
            )
        ])
        let instructionsSnapshot = ResolvedInstructionSnapshot(
            composedInstructions: ResolvedValue(
                effectiveValue: "Project instruction body",
                winningSource: instructionSource,
                trace: ResolutionTrace(participants: [instructionSource]),
                mergeMethod: .append
            ),
            orderedBlocks: [
                ResolvedInstructionBlock(
                    blockID: "/tmp/project/CLAUDE.md",
                    content: ResolvedValue(
                        effectiveValue: "Project instruction body",
                        winningSource: instructionSource,
                        trace: ResolutionTrace(participants: [instructionSource]),
                        mergeMethod: .append
                    )
                )
            ]
        )
        let mcpSnapshot = ResolvedMcpSnapshot(
            servers: [
                ResolvedMcpServerEntry(
                    serverID: "filesystem",
                    resolvedConfig: ResolvedValue(
                        effectiveValue: .object(["command": .string("npx")]),
                        winningSource: mcpSource,
                        trace: ResolutionTrace(participants: [mcpSource]),
                        mergeMethod: .selectHighestPrecedence
                    )
                )
            ]
        )

        let agentParser = AgentParser()
        let skillParser = SkillParser()
        let agentSnapshot = AgentResolver().resolve(candidates: [
            makeAgentCandidate(
                tier: .project,
                identifier: "project-agent",
                scope: .project,
                sourcePath: "/tmp/project/.claude/agents/reviewer.md",
                parser: agentParser,
                markdown: """
                ---
                name: Reviewer
                ---
                Review output.
                """
            )
        ])
        let skillSnapshot = SkillResolver().resolve(candidates: [
            makeSkillCandidate(
                tier: .project,
                identifier: "project-skill",
                scope: .project,
                directoryPath: "/tmp/project/.claude/skills/refactor",
                parser: skillParser,
                markdown: """
                ---
                name: Refactor
                ---
                Refactor instructions.
                """
            )
        ])

        let projection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(
                settings: settingsSnapshot,
                instructions: instructionsSnapshot,
                mcp: mcpSnapshot,
                agents: agentSnapshot,
                skills: skillSnapshot
            )
        )

        XCTAssertEqual(projection.familyStates.map { $0.family }, SessionProjectionFamily.allCases)
        XCTAssertEqual(projection.issueSummary.byFamily.map { $0.family }, SessionProjectionFamily.allCases)
        XCTAssertTrue(projection.completeness.isComplete)
        XCTAssertTrue(projection.notes.contains(where: { $0.contains("computed in-memory") }))

        let hooks: ResolvedHookSnapshot = try XCTUnwrap(projection.hooks)
        XCTAssertEqual(hooks.events.map { $0.eventID }, ["postToolUse", "preToolUse"])
        XCTAssertEqual(hooks.events.map(\.eventType), [.postToolUse, .preToolUse])
        XCTAssertEqual(hooks.events.first?.hooks.effectiveValue, [JSONValue.string("notify")])
    }

    func testSessionProjectionBuilderHandlesMissingFamiliesAsExplicitUnavailableState() throws {
        let settingsSource = makeSource(identifier: "user-settings", sourcePath: "/tmp/.claude/settings.json")
        let settingsSnapshot = ResolvedSettingsSnapshot(entries: [
            ResolvedSettingsEntry(
                keyPath: "cleanupPeriodDays",
                value: ResolvedValue(
                    effectiveValue: .number(7),
                    winningSource: settingsSource,
                    trace: ResolutionTrace(participants: [settingsSource]),
                    mergeMethod: .replace
                )
            )
        ])

        let projection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(settings: settingsSnapshot)
        )

        XCTAssertNotNil(projection.settings)
        XCTAssertNil(projection.instructions)
        XCTAssertNil(projection.mcp)
        XCTAssertNil(projection.agents)
        XCTAssertNil(projection.skills)
        XCTAssertNil(projection.hooks)
        XCTAssertFalse(projection.completeness.isComplete)
        XCTAssertTrue(projection.completeness.missingFamilies.contains(.instructions))
        XCTAssertTrue(projection.completeness.missingFamilies.contains(.hooks))
        XCTAssertEqual(
            projection.familyStates.first(where: { $0.family == .settings })?.availability,
            .available
        )
    }

    func testSessionProjectionBuilderAggregatesIssuesAcrossResolverAndValidationInputs() {
        let source = makeSource(identifier: "settings-local", scope: .projectLocal, sourcePath: "/tmp/project/.claude/settings.local.json")
        let settingsIssue = ResolutionIssue(
            code: .typeMismatch,
            severity: .warning,
            message: "hooks must be object",
            source: source,
            keyPath: "hooks"
        )
        let validationIssue = ResolutionIssue(
            code: .conflict,
            severity: .error,
            message: "Validation conflict detected.",
            source: source
        )
        let bridgedValidationIssue = ValidationIssue(resolutionIssue: validationIssue)

        let settingsSnapshot = ResolvedSettingsSnapshot(
            entries: [
                ResolvedSettingsEntry(
                    keyPath: "hooks",
                    value: ResolvedValue(
                        effectiveValue: .string("bad-shape"),
                        winningSource: source,
                        trace: ResolutionTrace(participants: [source]),
                        mergeMethod: .replace,
                        issues: [settingsIssue]
                    )
                )
            ],
            issues: [settingsIssue]
        )

        let projection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(
                settings: settingsSnapshot,
                validationIssues: [bridgedValidationIssue]
            )
        )

        XCTAssertEqual(projection.issueSummary.errorCount, 1)
        XCTAssertGreaterThanOrEqual(projection.issueSummary.warningCount, 1)
        XCTAssertFalse(projection.completeness.isComplete)
        XCTAssertEqual(
            projection.familyStates.first(where: { $0.family == .hooks })?.availability,
            .available
        )
    }

    func testValidationResultMergingProducesDeterministicDeduplicatedOrdering() {
        let fileA = ValidationSourceReference(sourcePath: "/tmp/project/.claude/settings.json")
        let fileB = ValidationSourceReference(sourcePath: "/tmp/project/.claude/settings.local.json")

        let issueA = ValidationIssue(
            code: .schema("requiredFieldMissing"),
            severity: .error,
            category: .schema,
            message: "Missing required field.",
            source: fileA,
            keyPath: "hooks"
        )
        let issueB = ValidationIssue(
            code: .semantic("duplicateIdentifier"),
            severity: .warning,
            category: .semantic,
            message: "Duplicate identifier.",
            source: fileB
        )

        let first = ValidationResult(issues: [issueB, issueA, issueA])
        let second = ValidationResult(issues: [issueB])
        let merged = first.merging(second)

        XCTAssertEqual(merged.issues.map(\.id), [issueA.id, issueB.id])
        XCTAssertEqual(merged.summary.totalIssues, 2)
        XCTAssertEqual(merged.summary.errorCount, 1)
        XCTAssertEqual(merged.summary.warningCount, 1)
        XCTAssertTrue(merged.hasBlockingIssues)
    }

    func testValidationIssueBridgeFromSyntaxIssuePreservesSourceAndParserCode() {
        let syntaxIssue = SyntaxIssue(
            code: .invalidJSON,
            severity: .error,
            message: "Invalid JSON syntax.",
            sourcePath: "/tmp/project/.claude/settings.json",
            keyPath: nil,
            range: SourceRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 4)
        )

        let validationIssue = ValidationIssue(syntaxIssue: syntaxIssue)
        let resolutionIssue = validationIssue.asResolutionIssue()

        XCTAssertEqual(validationIssue.category, .parserSyntax)
        XCTAssertEqual(validationIssue.code.rawValue, "parser.invalidJSON")
        XCTAssertEqual(validationIssue.underlyingParserCode, SyntaxIssueCode.invalidJSON.rawValue)
        XCTAssertEqual(validationIssue.source?.sourcePath, "/tmp/project/.claude/settings.json")
        XCTAssertEqual(resolutionIssue.code, .parserSyntaxIssue)
        XCTAssertEqual(resolutionIssue.underlyingParserCode, SyntaxIssueCode.invalidJSON.rawValue)
        XCTAssertEqual(resolutionIssue.source?.sourcePath, "/tmp/project/.claude/settings.json")
    }

    func testValidationIssueBridgeFromResolutionIssuePreservesRelatedSources() {
        let primary = makeSource(identifier: "project-settings", scope: .project, sourcePath: "/tmp/project/.claude/settings.json")
        let related = makeSource(identifier: "user-settings", scope: .user, sourcePath: "/tmp/.claude/settings.json")

        let resolutionIssue = ResolutionIssue(
            code: .conflict,
            severity: .warning,
            message: "Conflict detected.",
            source: primary,
            keyPath: "hooks",
            relatedSources: [related, related]
        )

        let validationIssue = ValidationIssue(resolutionIssue: resolutionIssue, category: .semantic)
        let roundTrip = validationIssue.asResolutionIssue()

        XCTAssertEqual(validationIssue.code.rawValue, "semantic.conflict")
        XCTAssertEqual(validationIssue.relatedSources.count, 1)
        XCTAssertEqual(validationIssue.relatedSources.first?.identifier, "user-settings")
        XCTAssertEqual(roundTrip.code, .conflict)
        XCTAssertEqual(roundTrip.relatedSources.count, 1)
        XCTAssertEqual(roundTrip.relatedSources.first?.identifier, "user-settings")
    }

    func testSchemaValidatorSettingsDetectsConflicts() {
        let validator = SchemaValidator()
        let document = ParsedSettingsDocument(
            source: SourceFileReference(url: URL(fileURLWithPath: "/tmp/.claude/settings.json")),
            value: SettingsDocumentValue(
                schema: nil,
                apiKeyHelper: nil,
                autoMemoryDirectory: nil,
                cleanupPeriodDays: nil,
                companyAnnouncements: nil,
                env: nil,
                attribution: ParsedAttribution(commit: "Generated with AI", pr: "", unknownFields: nil),
                includeCoAuthoredBy: true,
                includeGitInstructions: nil,
                permissions: ParsedPermissions(
                    allow: ["Read", "Write"],
                    deny: ["Write"],
                    defaultMode: "acceptEdits",
                    rawObject: [:]
                ),
                autoMode: true,
                disableAutoMode: true,
                useAutoModeDuringPlan: nil,
                disableDeepLinkRegistration: nil,
                hooks: ParsedHooks(
                    events: [
                        "PreToolUse": ParsedHookEvent(
                            eventName: "PreToolUse",
                            eventType: .preToolUse,
                            matcher: nil,
                            actions: [
                                ParsedHookAction(
                                    type: "command",
                                    handlerType: .command,
                                    command: nil,
                                    url: nil,
                                    method: nil,
                                    body: nil,
                                    template: nil,
                                    agentId: nil,
                                    inputs: nil,
                                    prompt: nil,
                                    timeout: -1,
                                    statusMessage: nil,
                                    condition: nil,
                                    once: nil,
                                    shell: nil,
                                    isAsync: nil,
                                    headers: nil,
                                    allowedEnvVars: nil,
                                    model: nil,
                                    rawObject: [:]
                                )
                            ],
                            rawValue: .array([])
                        )
                    ],
                    rawObject: [:]
                ),
                disableAllHooks: nil,
                allowManagedHooksOnly: nil,
                allowedHTTPHookURLs: nil,
                httpHookAllowedEnvVars: nil,
                pluginSettings: [:]
            ),
            rawTopLevelObject: [:],
            unsupportedTopLevelKeys: [:]
        )

        let result = validator.validate(settings: document)
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.settings.autoModeConflict" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.settings.permissionsModeWithAllowDeny" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.settings.permissionsAllowDenyOverlap" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.settings.hookActionTypeMismatch" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.settings.hookActionNegativeTimeout" }))
    }

    func testSchemaValidatorClaudeJsonDetectsMcpAndTrustShapeConflicts() {
        let validator = SchemaValidator()
        let document = ParsedClaudeJsonDocument(
            source: SourceFileReference(url: URL(fileURLWithPath: "/tmp/.claude.json")),
            value: ClaudeJsonDocumentValue(
                schema: nil,
                globalPreferences: ClaudeJsonGlobalPreferences(
                    defaultModel: " ",
                    defaultMode: "",
                    telemetryEnabled: true,
                    rawObject: [:]
                ),
                mcpState: ParsedClaudeJsonMcpState(
                    userServers: [
                        "alpha": ParsedClaudeJsonMcpServerRef(
                            config: McpServerConfig(
                                name: "alpha",
                                transportType: .unknown,
                                command: nil,
                                args: ["--stdio"],
                                env: nil,
                                cwd: nil,
                                url: nil,
                                headers: ["Authorization": "token"],
                                pluginId: nil,
                                pluginName: nil,
                                source: .claudeJson,
                                unknownFields: nil
                            ),
                            enabled: true,
                            source: nil,
                            rawObject: [:]
                        )
                    ],
                    localServers: [
                        "alpha": ParsedClaudeJsonMcpServerRef(
                            config: McpServerConfig(
                                name: "alpha",
                                transportType: .stdio,
                                command: "run",
                                args: nil,
                                env: nil,
                                cwd: nil,
                                url: "http://localhost:8123",
                                headers: nil,
                                pluginId: nil,
                                pluginName: nil,
                                source: .claudeJson,
                                unknownFields: nil
                            ),
                            enabled: true,
                            source: nil,
                            rawObject: [:]
                        )
                    ],
                    rawObject: [:]
                ),
                trustState: ParsedTrustState(
                    trustedProjectPaths: ["/tmp/project"],
                    blockedProjectPaths: ["/tmp/project"],
                    rawObject: [:]
                )
            ),
            rawTopLevelObject: [:],
            unsupportedTopLevelKeys: [:],
            settingsFamilyTopLevelKeys: [:]
        )

        let result = validator.validate(claudeJson: document)
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.claudeJson.defaultModeEmpty" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.claudeJson.defaultModelEmpty" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.claudeJson.mcpDuplicateAcrossScopes" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.mcp.argsWithoutCommand" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.mcp.headersWithoutUrl" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.claudeJson.trustPathOverlap" }))
    }

    func testSchemaValidatorClaudeMdDetectsEmptyBodyAndInvalidDotImport() {
        let validator = SchemaValidator()
        let document = ParsedClaudeMdDocument(
            source: SourceFileReference(url: URL(fileURLWithPath: "/tmp/CLAUDE.md")),
            rawBody: " \n\t",
            imports: [
                ParsedImportToken(
                    rawToken: "@.",
                    rawPath: ".",
                    range: SourceRange(startLine: 1, startColumn: 1, endLine: 1, endColumn: 2),
                    status: .valid
                )
            ]
        )

        let result = validator.validate(claudeMd: document)
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.claudeMd.emptyBody" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.claudeMd.importPathInvalid" }))
    }

    func testSchemaValidatorAgentDetectsMissingRequiredFieldsAndDuplicateTools() {
        let validator = SchemaValidator()
        let document = ParsedAgentDocument(
            source: SourceFileReference(url: URL(fileURLWithPath: "/tmp/agent.md")),
            frontmatter: ParsedAgentFrontmatter(
                name: "",
                description: " ",
                tools: [
                    ParsedAgentToolEntry(rawValue: ""),
                    ParsedAgentToolEntry(rawValue: "Read"),
                    ParsedAgentToolEntry(rawValue: "read")
                ],
                unknownFields: [:]
            ),
            rawFrontmatter: [:],
            promptBody: " "
        )

        let result = validator.validate(agent: document)
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.agent.nameMissing" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.agent.descriptionMissing" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.agent.toolEmpty" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.agent.toolDuplicate" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.agent.promptBodyEmpty" }))
    }

    func testSchemaValidatorSkillDetectsMissingMetadataAndDuplicateTags() {
        let validator = SchemaValidator()
        let rootURL = URL(fileURLWithPath: "/tmp/.claude/skills/my-skill")
        let document = ParsedSkillDocument(
            directory: SkillDirectoryMetadata(
                skillRootURL: rootURL,
                skillMarkdownURL: rootURL.appendingPathComponent("SKILL.md"),
                hasSkillMarkdown: true
            ),
            frontmatter: ParsedSkillFrontmatter(
                name: "",
                description: nil,
                version: "1.0.0",
                tags: ["", "ops", "OPS"],
                unknownFields: [:]
            ),
            rawFrontmatter: [:],
            body: "  ",
            supportingReferences: []
        )

        let result = validator.validate(skill: document)
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.skill.bodyEmpty" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.skill.nameMissing" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.skill.descriptionMissing" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.skill.tagEmpty" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.skill.tagDuplicate" }))
    }

    func testSchemaValidatorMcpDocumentDetectsDuplicateServersAndShapeIssues() {
        let validator = SchemaValidator()
        let source = ResolutionSource(
            scope: .project,
            kind: .file,
            identifier: "project-mcp",
            sourcePath: "/tmp/project/.mcp.json",
            availability: .present
        )

        let document = McpDocumentCandidate(
            tier: .project,
            source: source,
            servers: [
                McpDocumentServerEntry(
                    serverID: "alpha",
                    rawConfig: .object([
                        "args": .array([.string("--stdio")]),
                        "headers": .object(["Authorization": .string("token")])
                    ]),
                    parseOrder: 0
                ),
                McpDocumentServerEntry(
                    serverID: "alpha",
                    rawConfig: .string("not-object"),
                    parseOrder: 1
                )
            ]
        )

        let result = validator.validate(mcpDocument: document)
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.mcp.serverDuplicate" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.mcp.serverConfigNotObject" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.mcp.serverTransportShape" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.mcp.argsWithoutCommand" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.mcp.headersWithoutUrl" }))
    }

    func testSchemaValidatorMcpDocumentValidShapeProducesNoIssues() {
        let validator = SchemaValidator()
        let source = ResolutionSource(
            scope: .project,
            kind: .file,
            identifier: "project-mcp-valid",
            sourcePath: "/tmp/project/.mcp.json",
            availability: .present
        )
        let document = McpDocumentCandidate(
            tier: .project,
            source: source,
            servers: [
                McpDocumentServerEntry(
                    serverID: "stdio",
                    rawConfig: .object([
                        "command": .string("npx"),
                        "args": .array([.string("my-mcp"), .string("--stdio")]),
                        "env": .object(["NODE_ENV": .string("production")])
                    ]),
                    parseOrder: 0
                )
            ]
        )

        let result = validator.validate(mcpDocument: document)
        XCTAssertEqual(result.issues, [])
    }

    func testSchemaValidatorIssueOrderingIsDeterministic() {
        let validator = SchemaValidator()
        let source = ResolutionSource(
            scope: .project,
            kind: .file,
            identifier: "project-mcp-ordering",
            sourcePath: "/tmp/project/.mcp.json",
            availability: .present
        )

        let document = McpDocumentCandidate(
            tier: .project,
            source: source,
            servers: [
                McpDocumentServerEntry(
                    serverID: "beta",
                    rawConfig: .object(["args": .array([.number(1)])]),
                    parseOrder: 1
                ),
                McpDocumentServerEntry(
                    serverID: "alpha",
                    rawConfig: .object(["args": .array([.number(2)])]),
                    parseOrder: 0
                )
            ]
        )

        let first = validator.validate(mcpDocument: document)
        let second = validator.validate(mcpDocument: document)

        XCTAssertEqual(first.issues.map(\.id), second.issues.map(\.id))
        XCTAssertEqual(first.issues, second.issues)
    }

    func testSemanticValidatorDetectsDuplicateAgentAndSkillIdentityConflicts() {
        let agentParser = AgentParser()
        let skillParser = SkillParser()

        let agentSnapshot = AgentResolver().resolve(candidates: [
            makeAgentCandidate(
                tier: .user,
                identifier: "user-agent",
                scope: .user,
                sourcePath: "/tmp/.claude/agents/reviewer.md",
                parser: agentParser,
                markdown: """
                ---
                name: Reviewer
                ---
                User variant.
                """
            ),
            makeAgentCandidate(
                tier: .project,
                identifier: "project-agent",
                scope: .project,
                sourcePath: "/tmp/project/.claude/agents/reviewer.md",
                parser: agentParser,
                markdown: """
                ---
                name: reviewer
                ---
                Project variant.
                """
            )
        ])

        let skillSnapshot = SkillResolver().resolve(candidates: [
            makeSkillCandidate(
                tier: .user,
                identifier: "user-skill",
                scope: .user,
                directoryPath: "/tmp/.claude/skills/research",
                parser: skillParser,
                markdown: """
                ---
                name: Research
                ---
                User body.
                """
            ),
            makeSkillCandidate(
                tier: .project,
                identifier: "project-skill",
                scope: .project,
                directoryPath: "/tmp/project/.claude/skills/research",
                parser: skillParser,
                markdown: """
                ---
                name: Research
                ---
                Project body.
                """
            )
        ])

        let semantic = SemanticValidator().validate(
            context: SemanticValidationContext(agents: agentSnapshot, skills: skillSnapshot)
        )

        XCTAssertTrue(semantic.issues.contains(where: { $0.code.rawValue == "semantic.duplicateIdentifier" }))
        XCTAssertTrue(semantic.issues.contains(where: { $0.code.rawValue == "semantic.agent.overriddenByHigherPrecedence" }))
        XCTAssertTrue(semantic.issues.contains(where: { $0.code.rawValue == "semantic.skill.overriddenByHigherPrecedence" }))
        XCTAssertTrue(semantic.issues.contains(where: { $0.relatedSources.isEmpty == false }))
    }

    func testSemanticValidatorPropagatesUnresolvedCycleAndUnreachableInstructionImports() {
        let parser = ClaudeMdParser()
        let resolver = InstructionResolver(maxImportDepth: 1)

        let root = makeInstructionCandidate(
            scope: .user,
            identifier: "root",
            path: "/tmp/project/CLAUDE.md",
            parser: parser,
            markdown: """
            @imports/B.md
            @imports/missing.md
            """
        )
        let imported = makeInstructionCandidate(
            scope: .imported,
            identifier: "import-B",
            path: "/tmp/project/imports/B.md",
            parser: parser,
            markdown: "@../CLAUDE.md"
        )
        let snapshot = resolver.resolve(
            InstructionResolverInput(
                user: root,
                importedDocuments: [imported]
            )
        )

        let semantic = SemanticValidator().validate(
            context: SemanticValidationContext(instructions: snapshot)
        )

        XCTAssertTrue(semantic.issues.contains(where: { $0.code.rawValue == "semantic.unresolvedImport" }))
        XCTAssertTrue(
            semantic.issues.contains(where: {
                $0.code.rawValue == "semantic.cycleDetected" || $0.code.rawValue == "semantic.importDepthExceeded"
            })
        )
        XCTAssertTrue(semantic.issues.contains(where: { $0.code.rawValue == "semantic.instruction.importUnreachable" }))
    }

    func testSemanticValidatorDetectsMcpCrossScopeConflictsAndFallbackAssumptions() {
        let resolver = MCPResolver()
        let serverID = "filesystem"

        let invalidLocal = makeMcpDocument(
            tier: .local,
            scope: .projectLocal,
            identifier: "local-mcp",
            sourcePath: "/tmp/project/.claude/settings.local.json",
            availability: .invalid,
            servers: [
                makeMcpServer(serverID: serverID, parseOrder: 0, config: ["command": .string("local")])
            ]
        )
        let project = makeMcpDocument(
            tier: .project,
            scope: .project,
            identifier: "project-mcp",
            sourcePath: "/tmp/project/.mcp.json",
            servers: [
                makeMcpServer(serverID: serverID, parseOrder: 0, config: ["command": .string("project")])
            ]
        )
        let user = makeMcpDocument(
            tier: .user,
            scope: .user,
            identifier: "user-mcp",
            sourcePath: "/tmp/.claude.json",
            servers: [
                makeMcpServer(serverID: serverID, parseOrder: 0, config: ["command": .string("user")])
            ]
        )
        let snapshot = resolver.resolve(documents: [invalidLocal, project, user])

        let semantic = SemanticValidator().validate(
            context: SemanticValidationContext(mcp: snapshot)
        )

        XCTAssertTrue(semantic.issues.contains(where: { $0.code.rawValue == "semantic.mcp.crossScopeConflict" }))
        XCTAssertTrue(semantic.issues.contains(where: { $0.code.rawValue == "semantic.mcp.higherPrecedenceFallback" }))
    }

    func testSemanticValidatorReportsEnvironmentReferenceSemanticsForMcp() {
        let resolver = MCPResolver()
        let snapshot = resolver.resolve(documents: [
            makeMcpDocument(
                tier: .project,
                scope: .project,
                identifier: "project-mcp",
                sourcePath: "/tmp/project/.mcp.json",
                servers: [
                    makeMcpServer(
                        serverID: "env-server",
                        parseOrder: 0,
                        config: [
                            "command": .string("npx"),
                            "env": .object([
                                "HOME": .string("$HOME"),
                                "BROKEN": .string("${BROKEN")
                            ])
                        ]
                    )
                ]
            )
        ])

        let semantic = SemanticValidator().validate(
            context: SemanticValidationContext(mcp: snapshot)
        )

        XCTAssertTrue(semantic.issues.contains(where: { $0.code.rawValue == "semantic.mcp.environmentReference" }))
        XCTAssertTrue(semantic.issues.contains(where: { $0.code.rawValue == "semantic.mcp.environmentReferenceUnresolved" }))
        XCTAssertTrue(
            semantic.issues.contains(where: {
                $0.code.rawValue == "semantic.mcp.environmentReferenceUnresolved" &&
                    $0.keyPath == "env-server.env.BROKEN"
            })
        )
    }

    func testSemanticValidatorFlagsHooksNeutralizedByManagedHookPolicies() throws {
        let resolver = SettingsResolver()
        let managed = makeCandidate(
            tier: .managed,
            identifier: "managed-policy",
            scope: .managed,
            kind: .managed,
            rawTopLevel: [
                "disableAllHooks": .bool(true),
                "allowManagedHooksOnly": .bool(true)
            ]
        )
        let user = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: [
                "hooks": .object([
                    "PreToolUse": .array([
                        .object(["type": .string("command"), "command": .string("echo pre")])
                    ])
                ])
            ]
        )

        let settingsSelection = resolver.resolvePrecedence(candidates: [user, managed])
        let settingsSnapshot = resolver.buildSnapshot(from: settingsSelection)
        let hooksSnapshot = try XCTUnwrap(
            SessionProjectionBuilder().build(
                from: SessionProjectionBuilder.Input(settings: settingsSnapshot)
            ).hooks
        )

        let semantic = SemanticValidator().validate(
            context: SemanticValidationContext(settings: settingsSnapshot, hooks: hooksSnapshot)
        )

        XCTAssertTrue(semantic.issues.contains(where: { $0.code.rawValue == "semantic.hooks.neutralizedByDisableAllHooks" }))
        XCTAssertFalse(semantic.issues.contains(where: { $0.code.rawValue == "semantic.hooks.lowerScopeSuppressedByManagedPolicy" }))

        let managedOnly = makeCandidate(
            tier: .managed,
            identifier: "managed-hook-policy",
            scope: .managed,
            kind: .managed,
            rawTopLevel: [
                "allowManagedHooksOnly": .bool(true)
            ]
        )
        let managedOnlySelection = resolver.resolvePrecedence(candidates: [user, managedOnly])
        let managedOnlySettings = resolver.buildSnapshot(from: managedOnlySelection)
        let managedOnlyHooks = try XCTUnwrap(
            SessionProjectionBuilder().build(
                from: SessionProjectionBuilder.Input(settings: managedOnlySettings)
            ).hooks
        )

        let managedOnlySemantic = SemanticValidator().validate(
            context: SemanticValidationContext(settings: managedOnlySettings, hooks: managedOnlyHooks)
        )

        XCTAssertTrue(managedOnlySemantic.issues.contains(where: { $0.code.rawValue == "semantic.hooks.lowerScopeSuppressedByManagedPolicy" }))
    }

    func testSemanticValidatorFlagsManagedOnlySettingsMaskedByManagedPrecedence() {
        let resolver = SettingsResolver()
        let managed = makeCandidate(
            tier: .managed,
            identifier: "managed-policy",
            scope: .managed,
            kind: .managed,
            rawTopLevel: [
                "allowedMcpServers": .array([
                    .object(["serverName": .string("managed-filesystem")])
                ]),
                "strictKnownMarketplaces": .array([
                    .object([
                        "id": .string("managed-market"),
                        "source": .object([
                            "type": .string("github"),
                            "repo": .string("anthropic/managed-market")
                        ])
                    ])
                ])
            ]
        )
        let user = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: [
                "allowedMcpServers": .array([
                    .object(["serverName": .string("user-filesystem")])
                ]),
                "strictKnownMarketplaces": .array([
                    .object([
                        "id": .string("user-market"),
                        "source": .object([
                            "type": .string("github"),
                            "repo": .string("anthropic/user-market")
                        ])
                    ])
                ])
            ]
        )

        let selection = resolver.resolvePrecedence(candidates: [user, managed])
        let settingsSnapshot = resolver.buildSnapshot(from: selection)

        let semantic = SemanticValidator().validate(
            context: SemanticValidationContext(settings: settingsSnapshot)
        )

        XCTAssertTrue(semantic.issues.contains(where: {
            $0.code.rawValue == "semantic.mcp.managedPolicyMasksLowerScopeSetting" &&
                $0.keyPath == "allowedMcpServers"
        }))
        XCTAssertTrue(semantic.issues.contains(where: {
            $0.code.rawValue == "semantic.plugins.managedPolicyMasksLowerScope" &&
                $0.keyPath == "strictKnownMarketplaces"
        }))
    }

    func testSemanticValidatorFlagsResolvedPermissionAndSandboxConflicts() {
        let resolver = SettingsResolver()
        let user = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: [
                "permissions": .object([
                    "allow": .array([.string("Bash(git status)")])
                ]),
                "sandbox": .object([
                    "filesystem": .object([
                        "allowWrite": .array([.string("/tmp")]),
                        "allowRead": .array([.string("/repo")])
                    ]),
                    "network": .object([
                        "allowedDomains": .array([.string("example.com")])
                    ])
                ])
            ]
        )
        let local = makeCandidate(
            tier: .projectLocal,
            identifier: "local-settings",
            scope: .projectLocal,
            sourcePath: "/tmp/project/.claude/settings.local.json",
            rawTopLevel: [
                "permissions": .object([
                    "deny": .array([.string("Bash(git status)")])
                ]),
                "sandbox": .object([
                    "enabled": .bool(false),
                    "filesystem": .object([
                        "denyWrite": .array([.string("/tmp")])
                    ])
                ])
            ]
        )

        let selection = resolver.resolvePrecedence(candidates: [user, local])
        let settingsSnapshot = resolver.buildSnapshot(from: selection)

        let semantic = SemanticValidator().validate(
            context: SemanticValidationContext(settings: settingsSnapshot)
        )

        let semanticCodes = semantic.issues.map(\.code.rawValue)
        XCTAssertTrue(semantic.issues.contains(where: { $0.code.rawValue == "semantic.settings.permissionsAllowDenyConflict" }), "\(semanticCodes)")
        XCTAssertTrue(semantic.issues.contains(where: { $0.code.rawValue == "semantic.sandbox.disabledMakesSubsettingsIneffective" }), "\(semanticCodes)")
    }

    func testSemanticValidatorFlagsMcpBlockedByManagedOnlyPolicy() {
        let settingsResolver = SettingsResolver()
        let policySettings = settingsResolver.buildSnapshot(
            from: settingsResolver.resolvePrecedence(candidates: [
                makeCandidate(
                    tier: .managed,
                    identifier: "managed-policy",
                    scope: .managed,
                    kind: .managed,
                    rawTopLevel: [
                        "allowManagedMcpServersOnly": .bool(true)
                    ]
                )
            ])
        )

        let baseMcp = MCPResolver().resolve(documents: [
            makeMcpDocument(
                tier: .project,
                scope: .project,
                identifier: "project-mcp",
                sourcePath: "/tmp/project/.mcp.json",
                servers: [
                    makeMcpServer(serverID: "filesystem", parseOrder: 0, config: ["command": .string("npx")])
                ]
            )
        ])

        let projection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(settings: policySettings, mcp: baseMcp)
        )
        let semantic = SemanticValidator().validate(
            context: SemanticValidationContext(
                settings: policySettings,
                mcp: projection.mcp
            )
        )

        XCTAssertTrue(semantic.issues.contains(where: { $0.code.rawValue == "semantic.mcp.blockedByManagedOnlyPolicy" }))
    }

    func testSemanticValidatorFlagsMcpBlockedByDenyRuleAndManagedOverride() {
        let settingsResolver = SettingsResolver()
        let policySettings = settingsResolver.buildSnapshot(
            from: settingsResolver.resolvePrecedence(candidates: [
                makeCandidate(
                    tier: .managed,
                    identifier: "managed-policy",
                    scope: .managed,
                    kind: .managed,
                    rawTopLevel: [
                        "deniedMcpServers": .array([
                            .object(["serverName": .string("denied-server")])
                        ])
                    ]
                )
            ])
        )

        let baseMcp = MCPResolver().resolve(documents: [
            makeMcpDocument(
                tier: .managed,
                scope: .managed,
                identifier: "managed-mcp",
                sourcePath: "/Library/Application Support/ClaudeCode/managed-mcp.json",
                servers: [
                    makeMcpServer(serverID: "filesystem", parseOrder: 0, config: ["command": .string("managed")])
                ]
            ),
            makeMcpDocument(
                tier: .user,
                scope: .user,
                identifier: "user-mcp",
                sourcePath: "/tmp/.claude.json",
                servers: [
                    makeMcpServer(serverID: "filesystem", parseOrder: 0, config: ["command": .string("user")]),
                    makeMcpServer(serverID: "denied-server", parseOrder: 1, config: ["command": .string("denied")])
                ]
            )
        ])

        let projection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(settings: policySettings, mcp: baseMcp)
        )
        let semantic = SemanticValidator().validate(
            context: SemanticValidationContext(
                settings: policySettings,
                mcp: projection.mcp
            )
        )

        let semanticCodes = semantic.issues.map(\.code.rawValue)
        XCTAssertTrue(semantic.issues.contains(where: { $0.code.rawValue == "semantic.mcp.blockedByDenyRule" }), "\(semanticCodes)")
    }

    func testSemanticAndSchemaIssuesAggregateDeterministicallyForSessionVisibility() {
        let schemaDocument = ParsedSettingsDocument(
            source: SourceFileReference(url: URL(fileURLWithPath: "/tmp/.claude/settings.json")),
            value: SettingsDocumentValue(
                schema: nil,
                apiKeyHelper: nil,
                autoMemoryDirectory: nil,
                cleanupPeriodDays: nil,
                companyAnnouncements: nil,
                env: nil,
                attribution: nil,
                includeCoAuthoredBy: nil,
                includeGitInstructions: nil,
                permissions: nil,
                autoMode: true,
                disableAutoMode: true,
                useAutoModeDuringPlan: nil,
                disableDeepLinkRegistration: nil,
                hooks: nil,
                disableAllHooks: nil,
                allowManagedHooksOnly: nil,
                allowedHTTPHookURLs: nil,
                httpHookAllowedEnvVars: nil,
                pluginSettings: [:]
            ),
            rawTopLevelObject: [:],
            unsupportedTopLevelKeys: [:]
        )

        let parser = AgentParser()
        let agentSnapshot = AgentResolver().resolve(candidates: [
            makeAgentCandidate(
                tier: .user,
                identifier: "user-agent",
                scope: .user,
                sourcePath: "/tmp/.claude/agents/reviewer.md",
                parser: parser,
                markdown: """
                ---
                name: Reviewer
                ---
                User variant.
                """
            ),
            makeAgentCandidate(
                tier: .project,
                identifier: "project-agent",
                scope: .project,
                sourcePath: "/tmp/project/.claude/agents/reviewer.md",
                parser: parser,
                markdown: """
                ---
                name: Reviewer
                ---
                Project variant.
                """
            )
        ])

        let schemaIssues = SchemaValidator().validate(settings: schemaDocument)
        let semanticIssues = SemanticValidator().validate(
            context: SemanticValidationContext(agents: agentSnapshot)
        )

        let combined = ValidationResult.combined([schemaIssues, semanticIssues])
        let projectionA = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(validationIssues: combined.issues)
        )
        let projectionB = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(validationIssues: combined.issues)
        )

        XCTAssertTrue(combined.issues.contains(where: { $0.category == .schema }))
        XCTAssertTrue(combined.issues.contains(where: { $0.category == .semantic }))
        XCTAssertEqual(projectionA.issues.map(\.id), projectionB.issues.map(\.id))
        XCTAssertEqual(projectionA.issueSummary.totalIssues, projectionB.issueSummary.totalIssues)
    }

    func testSessionProjectionBuilderPreservesReadOnlyProjectionWithoutPersistenceAssumptions() {
        let projection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(notes: ["session projection packet D7"])
        )

        XCTAssertTrue(projection.notes.contains("session projection packet D7"))
        XCTAssertTrue(projection.notes.contains(where: { $0.contains("never persisted") }))
        XCTAssertTrue(projection.completeness.missingFamilies.count == SessionProjectionFamily.allCases.count)
    }

    func testClaudeMdParserExtractsImportsAndMalformedTokens() throws {
        let parser = ClaudeMdParser()
        let source = URL(fileURLWithPath: "/tmp/CLAUDE.md")
        let markdown = """
        # Root
        @docs/one.md
        @ docs/two.md
        trailing @
        """

        let result = parser.parse(markdown: markdown, sourceURL: source)
        let value = try XCTUnwrap(result.value)

        XCTAssertEqual(value.imports.count, 3)
        XCTAssertEqual(value.imports[0].status, .valid)
        XCTAssertEqual(value.imports[0].rawPath, "docs/one.md")
        XCTAssertEqual(value.imports[1].status, .malformed)
        XCTAssertEqual(value.imports[2].status, .malformed)
        XCTAssertTrue(result.issues.contains(where: { $0.code == .invalidMarkdownReferenceToken }))
    }

    func testInstructionResolverBuildsDeterministicRootOrderAndImportTraversal() throws {
        let parser = ClaudeMdParser()
        let resolver = InstructionResolver(maxImportDepth: 5)

        let managedPath = "/tmp/managed/CLAUDE.md"
        let userPath = "/tmp/.claude/CLAUDE.md"
        let importedPath = "/tmp/shared/imported.md"
        let projectPath = "/tmp/project/CLAUDE.md"
        let projectLocalPath = "/tmp/project/.claude/CLAUDE.md"

        let managed = makeInstructionCandidate(
            scope: .managed,
            identifier: "managed-root",
            path: managedPath,
            parser: parser,
            markdown: "@../shared/imported.md\nManaged body"
        )
        let user = makeInstructionCandidate(
            scope: .user,
            identifier: "user-root",
            path: userPath,
            parser: parser,
            markdown: "User body"
        )
        let imported = makeInstructionCandidate(
            scope: .imported,
            identifier: "shared-import",
            path: importedPath,
            parser: parser,
            markdown: "Shared body"
        )
        let project = makeInstructionCandidate(
            scope: .project,
            identifier: "project-root",
            path: projectPath,
            parser: parser,
            markdown: "Project body"
        )
        let projectLocal = makeInstructionCandidate(
            scope: .projectLocal,
            identifier: "project-local-root",
            path: projectLocalPath,
            parser: parser,
            markdown: "Project local body"
        )

        let snapshot = resolver.resolve(
            InstructionResolverInput(
                managed: managed,
                user: user,
                project: project,
                projectLocal: projectLocal,
                importedDocuments: [imported],
                startupMemory: [
                    InstructionMemoryCandidate(
                        topicID: "startup-1",
                        title: "Boot",
                        source: ResolutionSource(scope: .autoMemory, kind: .autoMemory, identifier: "memory/startup-1", sourcePath: "/tmp/memory/startup-1.md", availability: .present),
                        content: "Startup memory content",
                        issues: []
                    )
                ],
                onDemandMemory: [
                    InstructionMemoryCandidate(
                        topicID: "topic-1",
                        title: "Topic",
                        source: ResolutionSource(scope: .autoMemory, kind: .autoMemory, identifier: "memory/topic-1", sourcePath: "/tmp/memory/topic-1.md", availability: .present),
                        content: nil,
                        issues: []
                    )
                ]
            )
        )

        XCTAssertEqual(snapshot.rootLoadOrder.map(\.identifier), ["managed-root", "user-root", "project-root", "project-local-root"])
        XCTAssertEqual(snapshot.orderedBlocks.count, 5)
        XCTAssertTrue(snapshot.importEdges.contains(where: { $0.childBlockID == importedPath }))
        XCTAssertEqual(snapshot.startupMemoryTopics.map(\.topicID), ["startup-1"])
        XCTAssertEqual(snapshot.onDemandMemoryTopics.map(\.topicID), ["topic-1"])
        XCTAssertTrue(snapshot.notes.contains("User-authored instructions are resolved separately from auto memory."))
    }

    func testInstructionResolverReportsCycleDepthAndMissingImport() {
        let parser = ClaudeMdParser()
        let resolver = InstructionResolver(maxImportDepth: 1)

        let aPath = "/tmp/cycle/A.md"
        let bPath = "/tmp/cycle/B.md"
        let root = makeInstructionCandidate(
            scope: .user,
            identifier: "root",
            path: aPath,
            parser: parser,
            markdown: """
            @B.md
            @missing.md
            """
        )
        let bDoc = makeInstructionCandidate(
            scope: .imported,
            identifier: "b",
            path: bPath,
            parser: parser,
            markdown: "@A.md"
        )

        let snapshot = resolver.resolve(
            InstructionResolverInput(
                user: root,
                importedDocuments: [bDoc]
            )
        )

        XCTAssertTrue(snapshot.issues.contains(where: { $0.code == .unresolvedImport }))
        XCTAssertTrue(snapshot.issues.contains(where: { $0.code == .cycleDetected || $0.code == .importDepthExceeded }))
    }

    func testMCPResolverAppliesLocalProjectUserManagedPrecedencePerServerID() {
        let resolver = MCPResolver()
        let serverID = "filesystem"

        let managed = makeMcpDocument(
            tier: .managed,
            scope: .managed,
            identifier: "managed-mcp",
            sourcePath: "/tmp/managed/mcp.json",
            servers: [
                makeMcpServer(serverID: serverID, parseOrder: 0, config: ["command": .string("managed")])
            ]
        )
        let user = makeMcpDocument(
            tier: .user,
            scope: .user,
            identifier: "user-mcp",
            sourcePath: "/tmp/.claude.json",
            servers: [
                makeMcpServer(serverID: serverID, parseOrder: 0, config: ["command": .string("user")])
            ]
        )
        let project = makeMcpDocument(
            tier: .project,
            scope: .project,
            identifier: "project-mcp",
            sourcePath: "/tmp/project/.mcp.json",
            servers: [
                makeMcpServer(serverID: serverID, parseOrder: 0, config: ["command": .string("project")])
            ]
        )
        let local = makeMcpDocument(
            tier: .local,
            scope: .projectLocal,
            identifier: "local-mcp",
            sourcePath: "/tmp/.claude.json",
            servers: [
                makeMcpServer(serverID: serverID, parseOrder: 0, config: ["command": .string("local")])
            ]
        )

        let snapshot = resolver.resolve(documents: [managed, user, project, local])
        let entry = tryUnwrapMcpEntry(snapshot: snapshot, serverID: serverID)

        XCTAssertEqual(entry.resolvedConfig.winningSource?.identifier, "local-mcp")
        XCTAssertEqual(
            entry.resolvedConfig.trace.participants.map(\.identifier),
            ["local-mcp", "project-mcp", "user-mcp", "managed-mcp"]
        )
        XCTAssertEqual(entry.resolvedConfig.mergeMethod, .selectHighestPrecedence)
    }

    func testMCPResolverFallsBackWhenHigherPrecedenceCandidateIsInvalid() {
        let resolver = MCPResolver()
        let serverID = "notes"

        let invalidLocal = makeMcpDocument(
            tier: .local,
            scope: .projectLocal,
            identifier: "local-mcp",
            sourcePath: "/tmp/.claude.json",
            availability: .invalid,
            servers: [
                makeMcpServer(serverID: serverID, parseOrder: 0, config: ["command": .string("local")])
            ]
        )
        let project = makeMcpDocument(
            tier: .project,
            scope: .project,
            identifier: "project-mcp",
            sourcePath: "/tmp/project/.mcp.json",
            servers: [
                makeMcpServer(serverID: serverID, parseOrder: 0, config: ["url": .string("http://127.0.0.1:7777")])
            ]
        )

        let snapshot = resolver.resolve(documents: [invalidLocal, project])
        let entry = tryUnwrapMcpEntry(snapshot: snapshot, serverID: serverID)

        XCTAssertEqual(entry.resolvedConfig.winningSource?.identifier, "project-mcp")
        XCTAssertTrue(entry.resolvedConfig.issues.contains(where: { $0.code == .invalidSource }))
        XCTAssertTrue(entry.resolvedConfig.trace.notes.contains(where: { $0.contains("Fallback") }))
    }

    func testMCPResolverHandlesSameSourceDuplicateServerIDUsingLastParseOrder() {
        let resolver = MCPResolver()
        let serverID = "duplicate-server"

        let local = makeMcpDocument(
            tier: .local,
            scope: .projectLocal,
            identifier: "local-mcp",
            sourcePath: "/tmp/.claude.json",
            servers: [
                makeMcpServer(serverID: serverID, parseOrder: 0, config: ["command": .string("first")]),
                makeMcpServer(serverID: serverID, parseOrder: 1, config: ["command": .string("second")])
            ]
        )

        let snapshot = resolver.resolve(documents: [local])
        let entry = tryUnwrapMcpEntry(snapshot: snapshot, serverID: serverID)

        XCTAssertEqual(entry.resolvedConfig.effectiveValue, .object(["command": .string("second")]))
        XCTAssertTrue(entry.resolvedConfig.issues.contains(where: { $0.code == .duplicateIdentifier }))
    }

    func testMCPResolverEmitsEnvironmentReferenceNotesWithoutExpansion() {
        let resolver = MCPResolver()
        let serverID = "env-server"

        let project = makeMcpDocument(
            tier: .project,
            scope: .project,
            identifier: "project-mcp",
            sourcePath: "/tmp/project/.mcp.json",
            servers: [
                makeMcpServer(
                    serverID: serverID,
                    parseOrder: 0,
                    config: [
                        "command": .string("npx"),
                        "args": .array([.string("--token=${API_TOKEN}"), .string("--name=static")]),
                        "env": .object([
                            "HOME": .string("$HOME"),
                            "BROKEN": .string("${BROKEN")
                        ])
                    ]
                )
            ]
        )

        let snapshot = resolver.resolve(documents: [project])
        let entry = tryUnwrapMcpEntry(snapshot: snapshot, serverID: serverID)

        XCTAssertTrue(entry.environmentNotes.contains(where: { $0.fieldPath == "args[0]" && $0.classification == .containsReference }))
        XCTAssertTrue(entry.environmentNotes.contains(where: { $0.fieldPath == "args[1]" && $0.classification == .staticLiteral }))
        XCTAssertTrue(entry.environmentNotes.contains(where: { $0.fieldPath == "env.BROKEN" && $0.classification == .unresolvedReference }))
        XCTAssertEqual(entry.resolvedConfig.effectiveValue, .object([
            "command": .string("npx"),
            "args": .array([.string("--token=${API_TOKEN}"), .string("--name=static")]),
            "env": .object([
                "HOME": .string("$HOME"),
                "BROKEN": .string("${BROKEN")
            ])
        ]))
    }

    func testMCPResolverProducesUnresolvedEntryWhenNoUsableCandidatesExist() {
        let resolver = MCPResolver()
        let serverID = "broken-server"

        let project = makeMcpDocument(
            tier: .project,
            scope: .project,
            identifier: "project-mcp",
            sourcePath: "/tmp/project/.mcp.json",
            servers: [
                McpDocumentServerEntry(
                    serverID: serverID,
                    rawConfig: .string("invalid"),
                    parseOrder: 0
                )
            ]
        )

        let snapshot = resolver.resolve(documents: [project])
        let entry = tryUnwrapMcpEntry(snapshot: snapshot, serverID: serverID)

        XCTAssertNil(entry.resolvedConfig.effectiveValue)
        XCTAssertNil(entry.resolvedConfig.winningSource)
        XCTAssertTrue(entry.resolvedConfig.issues.contains(where: { $0.code == .unresolvedValue }))
        XCTAssertTrue(entry.resolvedConfig.issues.contains(where: { $0.code == .typeMismatch }))
    }

    // MARK: - R3 MCP Policy Enforcement Tests

    func testMCPResolverPolicyAllowManagedMcpServersOnlyBlocksNonManaged() {
        let resolver = MCPResolver()
        let serverID = "filesystem"

        let user = makeMcpDocument(
            tier: .user,
            scope: .user,
            identifier: "user-mcp",
            sourcePath: "/tmp/.claude.json",
            servers: [
                makeMcpServer(serverID: serverID, parseOrder: 0, config: ["command": .string("npx"), "args": .array([.string("@modelcontextprotocol/server-filesystem")])])
            ]
        )
        let managed = makeMcpDocument(
            tier: .managed,
            scope: .managed,
            identifier: "managed-mcp",
            sourcePath: "/tmp/managed/mcp.json",
            servers: [
                makeMcpServer(serverID: "managed-server", parseOrder: 0, config: ["command": .string("managed-cmd")])
            ]
        )

        let policySource = makeSource(identifier: "managed-settings", scope: .managed, sourcePath: "/tmp/managed/settings.json")
        let policy = MCPResolver.PolicyInput(
            allowManagedMcpServersOnly: true,
            policySource: policySource
        )

        let snapshot = resolver.resolveWithPolicy(documents: [user, managed], policy: policy)

        // Non-managed server should be blocked
        let userEntry = tryUnwrapMcpEntry(snapshot: snapshot, serverID: serverID)
        XCTAssertEqual(userEntry.effectiveState, .blocked)
        XCTAssertTrue(userEntry.stateExplanation.contains("only managed"))
        XCTAssertTrue(userEntry.policyEffects.contains(where: { $0.reason == .allowManagedMcpServersOnly }))

        // Managed server should be active with managed state
        let managedEntry = tryUnwrapMcpEntry(snapshot: snapshot, serverID: "managed-server")
        XCTAssertEqual(managedEntry.effectiveState, .managed)
        XCTAssertTrue(managedEntry.stateExplanation.contains("managed configuration"))

        // Snapshot should have global policy effect
        XCTAssertTrue(snapshot.policyEffects.contains(where: { $0.reason == .allowManagedMcpServersOnly }))
    }

    func testMCPResolverPolicyDeniedMcpServersBlocksByName() {
        let resolver = MCPResolver()

        let project = makeMcpDocument(
            tier: .project,
            scope: .project,
            identifier: "project-mcp",
            sourcePath: "/tmp/project/.mcp.json",
            servers: [
                makeMcpServer(serverID: "github", parseOrder: 0, config: ["command": .string("npx"), "args": .array([.string("@github/mcp")])]),
                makeMcpServer(serverID: "safe-server", parseOrder: 1, config: ["command": .string("safe-cmd")])
            ]
        )

        let policySource = makeSource(identifier: "user-settings", sourcePath: "/tmp/.claude/settings.json")
        let policy = MCPResolver.PolicyInput(
            deniedMcpServers: [McpRestrictionRule(serverName: "github", serverCommand: nil, serverUrl: nil, unknownFields: nil)],
            policySource: policySource
        )

        let snapshot = resolver.resolveWithPolicy(documents: [project], policy: policy)

        let blockedEntry = tryUnwrapMcpEntry(snapshot: snapshot, serverID: "github")
        XCTAssertEqual(blockedEntry.effectiveState, .blocked)
        XCTAssertTrue(blockedEntry.policyEffects.contains(where: { $0.reason == .deniedMcpServers }))
        XCTAssertTrue(snapshot.issues.contains(where: { $0.code == .mcpDenyRuleMatch }))

        let safeEntry = tryUnwrapMcpEntry(snapshot: snapshot, serverID: "safe-server")
        XCTAssertEqual(safeEntry.effectiveState, .active)
    }

    func testMCPResolverPolicyDeniedMcpServersByCommand() {
        let resolver = MCPResolver()

        let project = makeMcpDocument(
            tier: .project,
            scope: .project,
            identifier: "project-mcp",
            sourcePath: "/tmp/project/.mcp.json",
            servers: [
                makeMcpServer(serverID: "blocked-by-cmd", parseOrder: 0, config: [
                    "command": .string("npx"),
                    "args": .array([.string("@evil/mcp-server")])
                ]),
                makeMcpServer(serverID: "allowed-server", parseOrder: 1, config: [
                    "command": .string("safe-tool")
                ])
            ]
        )

        let policy = MCPResolver.PolicyInput(
            deniedMcpServers: [McpRestrictionRule(serverName: nil, serverCommand: ["npx", "@evil/mcp-server"], serverUrl: nil, unknownFields: nil)],
            policySource: nil
        )

        let snapshot = resolver.resolveWithPolicy(documents: [project], policy: policy)

        let blockedEntry = tryUnwrapMcpEntry(snapshot: snapshot, serverID: "blocked-by-cmd")
        XCTAssertEqual(blockedEntry.effectiveState, .blocked)

        let allowedEntry = tryUnwrapMcpEntry(snapshot: snapshot, serverID: "allowed-server")
        XCTAssertEqual(allowedEntry.effectiveState, .active)
    }

    func testMCPResolverPolicyDeniedMcpServersByUrl() {
        let resolver = MCPResolver()

        let project = makeMcpDocument(
            tier: .project,
            scope: .project,
            identifier: "project-mcp",
            sourcePath: "/tmp/project/.mcp.json",
            servers: [
                makeMcpServer(serverID: "http-server", parseOrder: 0, config: [
                    "url": .string("https://evil.example.com/mcp")
                ])
            ]
        )

        let policy = MCPResolver.PolicyInput(
            deniedMcpServers: [McpRestrictionRule(serverName: nil, serverCommand: nil, serverUrl: "https://evil.example.com", unknownFields: nil)],
            policySource: nil
        )

        let snapshot = resolver.resolveWithPolicy(documents: [project], policy: policy)

        let blockedEntry = tryUnwrapMcpEntry(snapshot: snapshot, serverID: "http-server")
        XCTAssertEqual(blockedEntry.effectiveState, .blocked)
        XCTAssertTrue(blockedEntry.stateExplanation.contains("deniedMcpServers"))
    }

    func testMCPResolverPolicyDisabledMcpjsonServersDisablesNamedServer() {
        let resolver = MCPResolver()

        let project = makeMcpDocument(
            tier: .project,
            scope: .project,
            identifier: "project-mcp",
            sourcePath: "/tmp/project/.mcp.json",
            servers: [
                makeMcpServer(serverID: "disabled-one", parseOrder: 0, config: ["command": .string("cmd1")]),
                makeMcpServer(serverID: "active-one", parseOrder: 1, config: ["command": .string("cmd2")])
            ]
        )

        let policy = MCPResolver.PolicyInput(
            disabledMcpjsonServers: ["disabled-one"],
            policySource: nil
        )

        let snapshot = resolver.resolveWithPolicy(documents: [project], policy: policy)

        let disabledEntry = tryUnwrapMcpEntry(snapshot: snapshot, serverID: "disabled-one")
        XCTAssertEqual(disabledEntry.effectiveState, .disabled)
        XCTAssertTrue(disabledEntry.policyEffects.contains(where: { $0.reason == .disabledMcpjsonServers }))

        let activeEntry = tryUnwrapMcpEntry(snapshot: snapshot, serverID: "active-one")
        XCTAssertEqual(activeEntry.effectiveState, .active)
    }

    func testMCPResolverPolicyAllowedMcpServersBlocksUnlistedServers() {
        let resolver = MCPResolver()

        let project = makeMcpDocument(
            tier: .project,
            scope: .project,
            identifier: "project-mcp",
            sourcePath: "/tmp/project/.mcp.json",
            servers: [
                makeMcpServer(serverID: "allowed-one", parseOrder: 0, config: ["command": .string("approved")]),
                makeMcpServer(serverID: "not-allowed", parseOrder: 1, config: ["command": .string("unapproved")])
            ]
        )

        let policy = MCPResolver.PolicyInput(
            allowedMcpServers: [McpRestrictionRule(serverName: "allowed-one", serverCommand: nil, serverUrl: nil, unknownFields: nil)],
            policySource: nil
        )

        let snapshot = resolver.resolveWithPolicy(documents: [project], policy: policy)

        let allowedEntry = tryUnwrapMcpEntry(snapshot: snapshot, serverID: "allowed-one")
        XCTAssertEqual(allowedEntry.effectiveState, .active)
        XCTAssertTrue(allowedEntry.policyEffects.contains(where: { $0.reason == .allowedMcpServers }))

        let blockedEntry = tryUnwrapMcpEntry(snapshot: snapshot, serverID: "not-allowed")
        XCTAssertEqual(blockedEntry.effectiveState, .blocked)
        XCTAssertTrue(blockedEntry.stateExplanation.contains("allowedMcpServers"))
    }

    func testMCPResolverPolicyDenyWinsOverAllow() {
        let resolver = MCPResolver()

        let project = makeMcpDocument(
            tier: .project,
            scope: .project,
            identifier: "project-mcp",
            sourcePath: "/tmp/project/.mcp.json",
            servers: [
                makeMcpServer(serverID: "contested", parseOrder: 0, config: ["command": .string("npx"), "args": .array([.string("mcp-tool")])])
            ]
        )

        // Both allow AND deny match the same server — deny should win
        let policy = MCPResolver.PolicyInput(
            allowedMcpServers: [McpRestrictionRule(serverName: "contested", serverCommand: nil, serverUrl: nil, unknownFields: nil)],
            deniedMcpServers: [McpRestrictionRule(serverName: "contested", serverCommand: nil, serverUrl: nil, unknownFields: nil)],
            policySource: nil
        )

        let snapshot = resolver.resolveWithPolicy(documents: [project], policy: policy)
        let entry = tryUnwrapMcpEntry(snapshot: snapshot, serverID: "contested")

        // Deny should take precedence
        XCTAssertEqual(entry.effectiveState, .blocked)
        XCTAssertTrue(entry.policyEffects.contains(where: { $0.reason == .deniedMcpServers }))
    }

    func testMCPResolverPolicyEnableAllProjectMcpServersAnnotatesProjectServers() {
        let resolver = MCPResolver()

        let project = makeMcpDocument(
            tier: .project,
            scope: .project,
            identifier: "project-mcp",
            sourcePath: "/tmp/project/.mcp.json",
            servers: [
                makeMcpServer(serverID: "project-server", parseOrder: 0, config: ["command": .string("cmd")])
            ]
        )
        let user = makeMcpDocument(
            tier: .user,
            scope: .user,
            identifier: "user-mcp",
            sourcePath: "/tmp/.claude.json",
            servers: [
                makeMcpServer(serverID: "user-server", parseOrder: 0, config: ["command": .string("user-cmd")])
            ]
        )

        let policy = MCPResolver.PolicyInput(
            enableAllProjectMcpServers: true,
            policySource: nil
        )

        let snapshot = resolver.resolveWithPolicy(documents: [project, user], policy: policy)

        // Project server should have enableAllProjectMcpServers effect
        let projectEntry = tryUnwrapMcpEntry(snapshot: snapshot, serverID: "project-server")
        XCTAssertEqual(projectEntry.effectiveState, .active)
        XCTAssertTrue(projectEntry.policyEffects.contains(where: { $0.reason == .enableAllProjectMcpServers }))

        // User server should NOT have enableAllProjectMcpServers effect
        let userEntry = tryUnwrapMcpEntry(snapshot: snapshot, serverID: "user-server")
        XCTAssertEqual(userEntry.effectiveState, .active)
        XCTAssertFalse(userEntry.policyEffects.contains(where: { $0.reason == .enableAllProjectMcpServers }))

        // Snapshot should have global policy note
        XCTAssertTrue(snapshot.notes.contains(where: { $0.contains("enableAllProjectMcpServers") }))
    }

    func testMCPResolverPolicyEnabledMcpjsonServersAnnotatesNamedServers() {
        let resolver = MCPResolver()

        let project = makeMcpDocument(
            tier: .project,
            scope: .project,
            identifier: "project-mcp",
            sourcePath: "/tmp/project/.mcp.json",
            servers: [
                makeMcpServer(serverID: "named-server", parseOrder: 0, config: ["command": .string("cmd")]),
                makeMcpServer(serverID: "other-server", parseOrder: 1, config: ["command": .string("other")])
            ]
        )

        let policy = MCPResolver.PolicyInput(
            enabledMcpjsonServers: ["named-server"],
            policySource: nil
        )

        let snapshot = resolver.resolveWithPolicy(documents: [project], policy: policy)

        let namedEntry = tryUnwrapMcpEntry(snapshot: snapshot, serverID: "named-server")
        XCTAssertEqual(namedEntry.effectiveState, .active)
        XCTAssertTrue(namedEntry.policyEffects.contains(where: { $0.reason == .enabledMcpjsonServers }))

        let otherEntry = tryUnwrapMcpEntry(snapshot: snapshot, serverID: "other-server")
        XCTAssertEqual(otherEntry.effectiveState, .active)
        XCTAssertFalse(otherEntry.policyEffects.contains(where: { $0.reason == .enabledMcpjsonServers }))
    }

    func testMCPResolverExtractPolicyInputFromResolvedSettings() {
        let source = makeSource(identifier: "managed-settings", scope: .managed, sourcePath: "/tmp/managed/settings.json")
        let settings = ResolvedSettingsSnapshot(
            entries: [
                ResolvedSettingsEntry(
                    keyPath: "allowManagedMcpServersOnly",
                    value: ResolvedValue(
                        effectiveValue: .bool(true),
                        winningSource: source,
                        trace: ResolutionTrace(participants: [source]),
                        mergeMethod: .selectHighestPrecedence
                    )
                ),
                ResolvedSettingsEntry(
                    keyPath: "disabledMcpjsonServers",
                    value: ResolvedValue(
                        effectiveValue: .array([.string("bad-server")]),
                        winningSource: source,
                        trace: ResolutionTrace(participants: [source]),
                        mergeMethod: .appendUnique
                    )
                ),
                ResolvedSettingsEntry(
                    keyPath: "deniedMcpServers",
                    value: ResolvedValue(
                        effectiveValue: .array([.object(["serverName": .string("evil")])]),
                        winningSource: source,
                        trace: ResolutionTrace(participants: [source]),
                        mergeMethod: .appendUnique
                    )
                )
            ]
        )

        let policy = MCPResolver.extractPolicyInput(from: settings)

        XCTAssertTrue(policy.allowManagedMcpServersOnly)
        XCTAssertFalse(policy.enableAllProjectMcpServers)
        XCTAssertEqual(policy.disabledMcpjsonServers, ["bad-server"])
        XCTAssertEqual(policy.deniedMcpServers.count, 1)
        XCTAssertEqual(policy.deniedMcpServers.first?.serverName, "evil")
        XCTAssertEqual(policy.policySource?.identifier, "managed-settings")
    }

    func testMCPResolverApplyPolicyPostResolutionMatchesResolveWithPolicy() {
        let resolver = MCPResolver()

        let project = makeMcpDocument(
            tier: .project,
            scope: .project,
            identifier: "project-mcp",
            sourcePath: "/tmp/project/.mcp.json",
            servers: [
                makeMcpServer(serverID: "srv", parseOrder: 0, config: ["command": .string("cmd")])
            ]
        )

        let policy = MCPResolver.PolicyInput(
            disabledMcpjsonServers: ["srv"],
            policySource: nil
        )

        let withPolicy = resolver.resolveWithPolicy(documents: [project], policy: policy)
        let base = resolver.resolve(documents: [project])
        let applied = resolver.applyPolicy(to: base, policy: policy)

        // Both paths should produce the same effective state
        XCTAssertEqual(
            withPolicy.servers.first?.effectiveState,
            applied.servers.first?.effectiveState
        )
    }

    func testMCPResolverUnresolvedServerGetsUnresolvedState() {
        let resolver = MCPResolver()
        let serverID = "broken"

        let project = makeMcpDocument(
            tier: .project,
            scope: .project,
            identifier: "project-mcp",
            sourcePath: "/tmp/project/.mcp.json",
            servers: [
                makeMcpServer(serverID: serverID, parseOrder: 0, config: .string("not-an-object"))
            ]
        )

        let policy = MCPResolver.PolicyInput()
        let snapshot = resolver.resolveWithPolicy(documents: [project], policy: policy)
        let entry = tryUnwrapMcpEntry(snapshot: snapshot, serverID: serverID)

        XCTAssertEqual(entry.effectiveState, .unresolved)
        XCTAssertTrue(entry.stateExplanation.contains("No usable"))
    }

    func testSessionProjectionBuilderAppliesMcpPolicyFromSettings() {
        let managedSource = makeSource(identifier: "managed-settings", scope: .managed, sourcePath: "/tmp/managed/settings.json")
        let userSource = makeSource(identifier: "user-mcp", sourcePath: "/tmp/.claude.json")

        let settings = ResolvedSettingsSnapshot(
            entries: [
                ResolvedSettingsEntry(
                    keyPath: "disabledMcpjsonServers",
                    value: ResolvedValue(
                        effectiveValue: .array([.string("disabled-srv")]),
                        winningSource: managedSource,
                        trace: ResolutionTrace(participants: [managedSource]),
                        mergeMethod: .appendUnique
                    )
                )
            ]
        )

        let mcp = ResolvedMcpSnapshot(
            servers: [
                ResolvedMcpServerEntry(
                    serverID: "disabled-srv",
                    resolvedConfig: ResolvedValue(
                        effectiveValue: .object(["command": .string("cmd")]),
                        winningSource: userSource,
                        trace: ResolutionTrace(participants: [userSource]),
                        mergeMethod: .selectHighestPrecedence
                    )
                ),
                ResolvedMcpServerEntry(
                    serverID: "active-srv",
                    resolvedConfig: ResolvedValue(
                        effectiveValue: .object(["command": .string("cmd2")]),
                        winningSource: userSource,
                        trace: ResolutionTrace(participants: [userSource]),
                        mergeMethod: .selectHighestPrecedence
                    )
                )
            ]
        )

        let builder = SessionProjectionBuilder()
        let projection = builder.build(from: SessionProjectionBuilder.Input(settings: settings, mcp: mcp))

        // The projection should have policy-aware MCP
        let disabledSrv = projection.mcp?.servers.first(where: { $0.serverID == "disabled-srv" })
        XCTAssertNotNil(disabledSrv)
        XCTAssertEqual(disabledSrv?.effectiveState, .disabled)

        let activeSrv = projection.mcp?.servers.first(where: { $0.serverID == "active-srv" })
        XCTAssertNotNil(activeSrv)
        XCTAssertEqual(activeSrv?.effectiveState, .active)
    }

    // MARK: - End R3 MCP Policy Tests

    func testAgentResolverResolvesUserOnlyAgentAsEffective() throws {
        let parser = AgentParser()
        let resolver = AgentResolver()
        let candidate = makeAgentCandidate(
            tier: .user,
            identifier: "user-agent",
            scope: .user,
            sourcePath: "/tmp/.claude/agents/reviewer.md",
            parser: parser,
            markdown: """
            ---
            name: Reviewer
            ---
            Review code quality.
            """
        )

        let snapshot = resolver.resolve(candidates: [candidate])
        let entry = try XCTUnwrap(snapshot.agents.first)

        XCTAssertEqual(entry.agentID, "reviewer")
        XCTAssertEqual(entry.visibility.effectiveValue, .effective)
        XCTAssertEqual(entry.isVisible.effectiveValue, true)
        XCTAssertTrue(snapshot.issues.isEmpty)
    }

    func testAgentResolverPrefersProjectScopeOverUserScopeForSameIdentity() {
        let parser = AgentParser()
        let resolver = AgentResolver()
        let user = makeAgentCandidate(
            tier: .user,
            identifier: "user-agent",
            scope: .user,
            sourcePath: "/tmp/.claude/agents/reviewer.md",
            parser: parser,
            markdown: """
            ---
            name: Reviewer
            ---
            User variant.
            """
        )
        let project = makeAgentCandidate(
            tier: .project,
            identifier: "project-agent",
            scope: .project,
            sourcePath: "/tmp/project/.claude/agents/reviewer.md",
            parser: parser,
            markdown: """
            ---
            name: reviewer
            ---
            Project variant.
            """
        )

        let snapshot = resolver.resolve(candidates: [user, project])
        let statesBySource = Dictionary(uniqueKeysWithValues: snapshot.agents.map { ($0.source.identifier, $0.visibility.effectiveValue) })

        XCTAssertEqual(statesBySource["project-agent"], .effective)
        XCTAssertEqual(statesBySource["user-agent"], .overridden)
        XCTAssertTrue(snapshot.issues.contains(where: { $0.code == .duplicateIdentifier && $0.source?.identifier == "user-agent" }))
    }

    func testAgentResolverFlagsSameScopeDuplicateIdentitiesDeterministically() {
        let parser = AgentParser()
        let resolver = AgentResolver()
        let candidateA = makeAgentCandidate(
            tier: .user,
            identifier: "a-user-agent",
            scope: .user,
            sourcePath: "/tmp/.claude/agents/a.md",
            parser: parser,
            markdown: """
            ---
            name: Duplicate Name
            ---
            First definition.
            """
        )
        let candidateB = makeAgentCandidate(
            tier: .user,
            identifier: "z-user-agent",
            scope: .user,
            sourcePath: "/tmp/.claude/agents/z.md",
            parser: parser,
            markdown: """
            ---
            name: duplicate name
            ---
            Second definition.
            """
        )

        let snapshot = resolver.resolve(candidates: [candidateB, candidateA])

        let ordered = snapshot.agents
            .filter { $0.agentID == "duplicate-name" }
            .map { ($0.source.identifier, $0.visibility.effectiveValue) }
        XCTAssertEqual(ordered.count, 2)
        XCTAssertEqual(ordered[0].0, "a-user-agent")
        XCTAssertEqual(ordered[0].1, .effective)
        XCTAssertEqual(ordered[1].0, "z-user-agent")
        XCTAssertEqual(ordered[1].1, .overridden)
        XCTAssertTrue(snapshot.issues.contains(where: { $0.code == .duplicateIdentifier && $0.message.contains("same scope") }))
    }

    func testAgentResolverCarriesMalformedFrontmatterIssuesAsInvalidEntry() {
        let parser = AgentParser()
        let resolver = AgentResolver()
        let malformed = makeAgentCandidate(
            tier: .user,
            identifier: "broken-agent",
            scope: .user,
            sourcePath: "/tmp/.claude/agents/broken.md",
            parser: parser,
            markdown: """
            ---
            name Reviewer
            tools:
              - bash
            ---
            Body
            """
        )

        let snapshot = resolver.resolve(candidates: [malformed])
        let entry = snapshot.agents.first(where: { $0.source.identifier == "broken-agent" })

        XCTAssertEqual(entry?.visibility.effectiveValue, .invalid)
        XCTAssertTrue(entry?.definition.issues.contains(where: { $0.code == .parserSyntaxIssue }) == true)
        XCTAssertTrue(snapshot.issues.contains(where: { $0.code == .parserSyntaxIssue }))
    }

    func testSkillResolverHandlesUserOnlyAndProjectOverride() {
        let parser = SkillParser()
        let resolver = SkillResolver()
        let user = makeSkillCandidate(
            tier: .user,
            identifier: "user-skill",
            scope: .user,
            directoryPath: "/tmp/.claude/skills/research",
            parser: parser,
            markdown: """
            ---
            name: Research
            ---
            Body
            """
        )
        let project = makeSkillCandidate(
            tier: .project,
            identifier: "project-skill",
            scope: .project,
            directoryPath: "/tmp/project/.claude/skills/research",
            parser: parser,
            markdown: """
            ---
            name: Research
            ---
            Body
            """
        )

        let snapshot = resolver.resolve(candidates: [user, project])
        let statesBySource = Dictionary(uniqueKeysWithValues: snapshot.skills.map { ($0.source.identifier, $0.visibility.effectiveValue) })

        XCTAssertEqual(statesBySource["project-skill"], .effective)
        XCTAssertEqual(statesBySource["user-skill"], .overridden)
        XCTAssertTrue(snapshot.issues.contains(where: { $0.code == .duplicateIdentifier && $0.source?.identifier == "user-skill" }))
    }

    func testSkillResolverPreservesMissingSkillMarkdownAsInvalidWithDiagnostics() {
        let parser = SkillParser()
        let resolver = SkillResolver()
        let source = ResolutionSource(
            scope: .user,
            kind: .file,
            identifier: "missing-skill",
            sourcePath: "/tmp/.claude/skills/missing",
            availability: .present
        )
        let parseResult = parser.parse(
            skillDirectoryURL: URL(fileURLWithPath: "/tmp/.claude/skills/missing"),
            skillMarkdownData: nil
        )
        let issues = parseResult.issues.map { ResolutionIssue(syntaxIssue: $0, source: source) }
        let candidate = SkillDocumentCandidate(
            tier: .user,
            source: source,
            document: parseResult.value,
            issues: issues
        )

        let snapshot = resolver.resolve(candidates: [candidate])
        let entry = snapshot.skills.first(where: { $0.source.identifier == "missing-skill" })

        XCTAssertEqual(entry?.visibility.effectiveValue, .invalid)
        XCTAssertTrue(entry?.definition.issues.contains(where: { $0.code == .parserSyntaxIssue }) == true)
        XCTAssertTrue(snapshot.issues.contains(where: { $0.code == .unsupportedShape }))
    }

    func testSkillResolverProducesDeterministicOrderingAcrossEffectiveAndOverridden() {
        let parser = SkillParser()
        let resolver = SkillResolver()

        let userAlpha = makeSkillCandidate(
            tier: .user,
            identifier: "user-alpha",
            scope: .user,
            directoryPath: "/tmp/.claude/skills/alpha",
            parser: parser,
            markdown: """
            ---
            name: Alpha
            ---
            Body
            """
        )
        let projectAlpha = makeSkillCandidate(
            tier: .project,
            identifier: "project-alpha",
            scope: .project,
            directoryPath: "/tmp/project/.claude/skills/alpha",
            parser: parser,
            markdown: """
            ---
            name: Alpha
            ---
            Body
            """
        )
        let userBeta = makeSkillCandidate(
            tier: .user,
            identifier: "user-beta",
            scope: .user,
            directoryPath: "/tmp/.claude/skills/beta",
            parser: parser,
            markdown: """
            ---
            name: Beta
            ---
            Body
            """
        )

        let snapshot = resolver.resolve(candidates: [userAlpha, projectAlpha, userBeta])
        XCTAssertEqual(snapshot.skills.map(\.skillID), ["alpha", "beta", "alpha"])
        XCTAssertEqual(snapshot.skills.map { $0.visibility.effectiveValue }, [.effective, .effective, .overridden])
    }

    func testSessionSettingsViewModelSupportsMissingProjectionState() {
        let projection = SessionProjectionBuilder().build(from: SessionProjectionBuilder.Input())

        let viewModel = SessionSettingsViewModel(projection: projection)

        XCTAssertEqual(viewModel.state, .missing)
        XCTAssertEqual(viewModel.rowCount, 0)
        XCTAssertTrue(viewModel.sections.isEmpty)
        XCTAssertTrue(viewModel.summaryNotes.contains(where: { $0.contains("missing families") }))
    }

    func testSessionSettingsViewModelSupportsEmptySnapshotState() {
        let projection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(settings: ResolvedSettingsSnapshot(entries: []))
        )

        let viewModel = SessionSettingsViewModel(projection: projection)

        XCTAssertEqual(viewModel.state, .empty)
        XCTAssertEqual(viewModel.rowCount, 0)
        XCTAssertEqual(viewModel.sections.count, 0)
    }

    func testSessionSettingsViewModelMapsSingleSourceValueAndProvenance() {
        let source = makeSource(identifier: "user-settings", sourcePath: "/tmp/.claude/settings.json")
        let settings = ResolvedSettingsSnapshot(
            entries: [
                ResolvedSettingsEntry(
                    keyPath: "cleanupPeriodDays",
                    value: ResolvedValue(
                        effectiveValue: .number(30),
                        winningSource: source,
                        trace: ResolutionTrace(participants: [source]),
                        mergeMethod: .replace
                    )
                )
            ]
        )
        let projection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(settings: settings)
        )

        let viewModel = SessionSettingsViewModel(projection: projection)
        let row = tryUnwrapRow(viewModel: viewModel, keyPath: "cleanupPeriodDays")

        XCTAssertEqual(viewModel.state, .populated)
        XCTAssertEqual(viewModel.rowCount, 1)
        XCTAssertEqual(row.valueDisplay, "30")
        XCTAssertEqual(row.mergeMethodLabel, "Replace")
        XCTAssertEqual(row.winningSourceChip?.label, "/tmp/.claude/settings.json")
        XCTAssertEqual(row.participantSourceChips.map(\.label), ["/tmp/.claude/settings.json"])
    }

    func testSessionSettingsViewModelMapsMergeTraceUnresolvedRowsAndDiagnostics() {
        let local = makeSource(
            identifier: "project-local-settings",
            scope: .projectLocal,
            sourcePath: "/tmp/project/.claude/settings.local.json"
        )
        let user = makeSource(
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json"
        )
        let warning = ResolutionIssue(
            code: .typeMismatch,
            severity: .warning,
            message: "Expected object.",
            source: local,
            keyPath: "env"
        )
        let hookWarning = ResolutionIssue(
            code: .unsupportedShape,
            severity: .warning,
            message: "Invalid hook shape.",
            source: local,
            keyPath: "hooks.preToolUse"
        )
        let error = ResolutionIssue(
            code: .invalidSource,
            severity: .error,
            message: "Source is invalid.",
            source: local,
            keyPath: "env"
        )
        let settings = ResolvedSettingsSnapshot(
            entries: [
                ResolvedSettingsEntry(
                    keyPath: "env",
                    value: ResolvedValue(
                        effectiveValue: .object(["FOO": .string("bar")]),
                        winningSource: local,
                        trace: ResolutionTrace(
                            participants: [local, user],
                            overridden: [user],
                            notes: ["Deep merged by precedence."]
                        ),
                        mergeMethod: .deepMergeObject,
                        issues: [warning, error],
                        notes: ["Nested issue notes are preserved."]
                    )
                ),
                ResolvedSettingsEntry(
                    keyPath: "hooks.preToolUse",
                    value: ResolvedValue(
                        effectiveValue: nil,
                        winningSource: nil,
                        trace: ResolutionTrace(
                            participants: [local, user],
                            overridden: [],
                            notes: ["No usable hook shape remained."]
                        ),
                        mergeMethod: .keyedByIdentifier,
                        issues: [hookWarning]
                    )
                )
            ]
        )
        let projection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(settings: settings)
        )

        let viewModel = SessionSettingsViewModel(projection: projection)
        let envRow = tryUnwrapRow(viewModel: viewModel, keyPath: "env")
        let hooksRow = tryUnwrapRow(viewModel: viewModel, keyPath: "hooks.preToolUse")

        XCTAssertEqual(viewModel.state, .populated)
        XCTAssertEqual(viewModel.rowCount, 2)
        XCTAssertEqual(viewModel.errorCount, 1)
        XCTAssertEqual(viewModel.warningCount, 2)

        XCTAssertEqual(envRow.mergeMethodLabel, "Deep Merge")
        XCTAssertEqual(envRow.overriddenSourceChips.map(\.label), ["/tmp/.claude/settings.json"])
        XCTAssertEqual(envRow.issueBadges.first(where: { $0.severity == .error })?.count, 1)
        XCTAssertEqual(envRow.issueBadges.first(where: { $0.severity == .warning })?.count, 1)

        XCTAssertEqual(hooksRow.valueDisplay, "(unresolved)")
        XCTAssertNil(hooksRow.winningSourceChip)
    }

    func testSessionSettingsViewModelSortsSectionsAndRowsDeterministically() {
        let source = makeSource(identifier: "user-settings", sourcePath: "/tmp/.claude/settings.json")
        let settings = ResolvedSettingsSnapshot(
            entries: [
                // Worktree family (sortOrder 9)
                ResolvedSettingsEntry(
                    keyPath: "worktree.sparsePaths",
                    value: ResolvedValue(
                        effectiveValue: .array([.string("src/")]),
                        winningSource: source,
                        trace: ResolutionTrace(participants: [source]),
                        mergeMethod: .appendUnique
                    )
                ),
                // Model family (sortOrder 0) — two keys to test intra-section ordering
                ResolvedSettingsEntry(
                    keyPath: "model",
                    value: ResolvedValue(
                        effectiveValue: .string("claude-sonnet-4-6"),
                        winningSource: source,
                        trace: ResolutionTrace(participants: [source]),
                        mergeMethod: .selectHighestPrecedence
                    )
                ),
                ResolvedSettingsEntry(
                    keyPath: "effortLevel",
                    value: ResolvedValue(
                        effectiveValue: .string("high"),
                        winningSource: source,
                        trace: ResolutionTrace(participants: [source]),
                        mergeMethod: .selectHighestPrecedence
                    )
                )
            ]
        )
        let projection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(settings: settings)
        )

        let viewModel = SessionSettingsViewModel(projection: projection)

        // Model family appears before Worktree family per SettingsFamily.sortOrder
        XCTAssertEqual(viewModel.sections.map(\.key), ["model", "worktree"])
        // Within Model family, rows are sorted alphabetically by keyPath
        XCTAssertEqual(viewModel.sections.first?.rows.map(\.keyPath), ["effortLevel", "model"])
    }

    func testSessionInstructionsViewModelSupportsNoImportSimpleState() {
        let rootSource = makeSource(identifier: "user-instructions", sourcePath: "/tmp/.claude/CLAUDE.md")
        let instructions = ResolvedInstructionSnapshot(
            composedInstructions: ResolvedValue(
                effectiveValue: "Root body",
                winningSource: rootSource,
                trace: ResolutionTrace(participants: [rootSource]),
                mergeMethod: .append
            ),
            orderedBlocks: [
                ResolvedInstructionBlock(
                    blockID: "/tmp/.claude/CLAUDE.md",
                    content: ResolvedValue(
                        effectiveValue: "Root body",
                        winningSource: rootSource,
                        trace: ResolutionTrace(participants: [rootSource]),
                        mergeMethod: .append
                    )
                )
            ],
            rootLoadOrder: [rootSource]
        )
        let projection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(instructions: instructions)
        )

        let viewModel = SessionInstructionsViewModel(projection: projection)

        XCTAssertEqual(viewModel.state, .populated)
        XCTAssertFalse(viewModel.isPartial)
        XCTAssertEqual(viewModel.entries.map(\.blockID), ["/tmp/.claude/CLAUDE.md"])
        XCTAssertEqual(viewModel.rootLoadOrder.map(\.pathLabel), ["/tmp/.claude/CLAUDE.md"])
        XCTAssertEqual(viewModel.importRelations.count, 0)
        XCTAssertEqual(viewModel.startupMemoryCount, 0)
        XCTAssertEqual(viewModel.onDemandMemoryCount, 0)
    }

    func testSessionInstructionsViewModelPreservesDeterministicNestedImportOrdering() {
        let root = makeSource(identifier: "root", sourcePath: "/tmp/project/CLAUDE.md")
        let child = makeSource(identifier: "child", scope: .imported, sourcePath: "/tmp/project/docs/child.md")
        let leaf = makeSource(identifier: "leaf", scope: .imported, sourcePath: "/tmp/project/docs/leaf.md")
        let instructions = ResolvedInstructionSnapshot(
            composedInstructions: ResolvedValue(
                effectiveValue: "Root\n\nChild\n\nLeaf",
                winningSource: root,
                trace: ResolutionTrace(participants: [root, child, leaf]),
                mergeMethod: .append
            ),
            orderedBlocks: [
                ResolvedInstructionBlock(blockID: "/tmp/project/CLAUDE.md", content: ResolvedValue(effectiveValue: "Root", winningSource: root, trace: ResolutionTrace(participants: [root]), mergeMethod: .append)),
                ResolvedInstructionBlock(blockID: "/tmp/project/docs/child.md", content: ResolvedValue(effectiveValue: "Child", winningSource: child, trace: ResolutionTrace(participants: [child]), mergeMethod: .append)),
                ResolvedInstructionBlock(blockID: "/tmp/project/docs/leaf.md", content: ResolvedValue(effectiveValue: "Leaf", winningSource: leaf, trace: ResolutionTrace(participants: [leaf]), mergeMethod: .append))
            ],
            importEdges: [
                ResolvedInstructionImportEdge(parentBlockID: "/tmp/project/CLAUDE.md", childBlockID: "/tmp/project/docs/child.md", rawToken: "@docs/child.md", tokenRange: nil, resolvedPath: "/tmp/project/docs/child.md", depth: 1, isCycle: false),
                ResolvedInstructionImportEdge(parentBlockID: "/tmp/project/docs/child.md", childBlockID: "/tmp/project/docs/leaf.md", rawToken: "@leaf.md", tokenRange: nil, resolvedPath: "/tmp/project/docs/leaf.md", depth: 2, isCycle: false)
            ],
            rootLoadOrder: [root]
        )
        let projection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(instructions: instructions)
        )

        let viewModel = SessionInstructionsViewModel(projection: projection)

        XCTAssertEqual(viewModel.entries.map(\.blockID), [
            "/tmp/project/CLAUDE.md",
            "/tmp/project/docs/child.md",
            "/tmp/project/docs/leaf.md"
        ])
        XCTAssertEqual(viewModel.entries.map(\.depth), [0, 1, 2])
        XCTAssertEqual(viewModel.importRelations.map(\.depth), [1, 2])
    }

    func testSessionInstructionsViewModelShowsCycleAndUnresolvedImportDiagnostics() {
        let root = makeSource(identifier: "root", sourcePath: "/tmp/project/CLAUDE.md")
        let cycleIssue = ResolutionIssue(
            code: .cycleDetected,
            severity: .error,
            message: "Instruction import cycle detected.",
            source: root
        )
        let unresolvedIssue = ResolutionIssue(
            code: .unresolvedImport,
            severity: .warning,
            message: "Instruction import target could not be found: /tmp/project/missing.md",
            source: root
        )
        let instructions = ResolvedInstructionSnapshot(
            composedInstructions: ResolvedValue(
                effectiveValue: "Root",
                winningSource: root,
                trace: ResolutionTrace(participants: [root]),
                mergeMethod: .append
            ),
            orderedBlocks: [
                ResolvedInstructionBlock(
                    blockID: "/tmp/project/CLAUDE.md",
                    content: ResolvedValue(
                        effectiveValue: "Root",
                        winningSource: root,
                        trace: ResolutionTrace(participants: [root]),
                        mergeMethod: .append
                    )
                )
            ],
            importEdges: [
                ResolvedInstructionImportEdge(parentBlockID: "/tmp/project/CLAUDE.md", childBlockID: "/tmp/project/CLAUDE.md", rawToken: "@CLAUDE.md", tokenRange: nil, resolvedPath: "/tmp/project/CLAUDE.md", depth: 1, isCycle: true),
                ResolvedInstructionImportEdge(parentBlockID: "/tmp/project/CLAUDE.md", childBlockID: nil, rawToken: "@missing.md", tokenRange: nil, resolvedPath: "/tmp/project/missing.md", depth: 1, isCycle: false)
            ],
            rootLoadOrder: [root],
            issues: [cycleIssue, unresolvedIssue]
        )
        let projection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(instructions: instructions)
        )

        let viewModel = SessionInstructionsViewModel(projection: projection)

        XCTAssertEqual(viewModel.issueSummary.cycleCount, 1)
        XCTAssertEqual(viewModel.issueSummary.unresolvedImportCount, 1)
        XCTAssertEqual(viewModel.issueSummary.errorCount, 1)
        XCTAssertEqual(viewModel.issueSummary.warningCount, 1)
        XCTAssertTrue(viewModel.importRelations.contains(where: { $0.isCycle }))
        XCTAssertTrue(viewModel.importRelations.contains(where: { $0.isResolved == false }))
        XCTAssertTrue(viewModel.isPartial)
    }

    func testSessionInstructionsViewModelSeparatesStartupAndOnDemandMemoryTopics() {
        let root = makeSource(identifier: "root", sourcePath: "/tmp/project/CLAUDE.md")
        let startupSource = makeSource(identifier: "startup", scope: .autoMemory, sourcePath: "/tmp/memory/startup.md")
        let onDemandSource = makeSource(identifier: "on-demand", scope: .autoMemory, sourcePath: "/tmp/memory/topic.md")
        let instructions = ResolvedInstructionSnapshot(
            composedInstructions: ResolvedValue(
                effectiveValue: "Root",
                winningSource: root,
                trace: ResolutionTrace(participants: [root, startupSource]),
                mergeMethod: .append
            ),
            orderedBlocks: [
                ResolvedInstructionBlock(
                    blockID: "/tmp/project/CLAUDE.md",
                    content: ResolvedValue(
                        effectiveValue: "Root",
                        winningSource: root,
                        trace: ResolutionTrace(participants: [root]),
                        mergeMethod: .append
                    )
                )
            ],
            startupMemoryTopics: [
                ResolvedInstructionMemoryTopic(topicID: "startup", title: "Startup Topic", source: startupSource, availability: .present)
            ],
            onDemandMemoryTopics: [
                ResolvedInstructionMemoryTopic(topicID: "topic", title: "On-demand Topic", source: onDemandSource, availability: .present)
            ],
            rootLoadOrder: [root]
        )
        let projection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(instructions: instructions)
        )

        let viewModel = SessionInstructionsViewModel(projection: projection)

        XCTAssertEqual(viewModel.startupMemoryCount, 1)
        XCTAssertEqual(viewModel.onDemandMemoryCount, 1)
        XCTAssertEqual(viewModel.memorySections.count, 2)
        XCTAssertEqual(viewModel.memorySections[0].title, "Startup Loaded")
        XCTAssertEqual(viewModel.memorySections[1].title, "On-Demand Topics")
        XCTAssertEqual(viewModel.memorySections[0].rows.map(\.topicID), ["startup"])
        XCTAssertEqual(viewModel.memorySections[1].rows.map(\.topicID), ["topic"])
    }

    func testSessionInstructionsViewModelSupportsEmptyAndPartialStates() {
        let emptyInstructions = ResolvedInstructionSnapshot(
            composedInstructions: ResolvedValue(
                effectiveValue: nil,
                winningSource: nil,
                trace: ResolutionTrace(participants: []),
                mergeMethod: .append
            )
        )
        let emptyProjection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(instructions: emptyInstructions)
        )
        let emptyViewModel = SessionInstructionsViewModel(projection: emptyProjection)

        XCTAssertEqual(emptyViewModel.state, .empty)
        XCTAssertFalse(emptyViewModel.isPartial)

        let root = makeSource(identifier: "root", sourcePath: "/tmp/project/CLAUDE.md")
        let invalidIssue = ResolutionIssue(
            code: .invalidSource,
            severity: .error,
            message: "Instruction source has no parsed document content.",
            source: root
        )
        let partialInstructions = ResolvedInstructionSnapshot(
            composedInstructions: ResolvedValue(
                effectiveValue: "Root",
                winningSource: root,
                trace: ResolutionTrace(participants: [root]),
                mergeMethod: .append,
                issues: [invalidIssue]
            ),
            orderedBlocks: [
                ResolvedInstructionBlock(
                    blockID: "/tmp/project/CLAUDE.md",
                    content: ResolvedValue(
                        effectiveValue: "Root",
                        winningSource: root,
                        trace: ResolutionTrace(participants: [root]),
                        mergeMethod: .append
                    )
                )
            ],
            rootLoadOrder: [root],
            issues: [invalidIssue]
        )
        let partialProjection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(instructions: partialInstructions)
        )
        let partialViewModel = SessionInstructionsViewModel(projection: partialProjection)

        XCTAssertEqual(partialViewModel.state, .populated)
        XCTAssertTrue(partialViewModel.isPartial)
        XCTAssertEqual(partialViewModel.issueSummary.errorCount, 1)
    }

    func testSessionHooksViewModelSupportsMissingState() {
        let projection = SessionProjectionBuilder().build(from: SessionProjectionBuilder.Input())

        let viewModel = SessionHooksViewModel(projection: projection)

        XCTAssertEqual(viewModel.state, .missing)
        XCTAssertEqual(viewModel.groupCount, 0)
        XCTAssertEqual(viewModel.rowCount, 0)
        XCTAssertTrue(viewModel.groups.isEmpty)
        XCTAssertTrue(viewModel.summaryNotes.contains(where: { $0.contains("missing families") }))
    }

    func testSessionHooksViewModelBuildsDeterministicGroupsAndRowsWithMatcherContext() {
        let source = makeSource(identifier: "project-local", scope: .projectLocal, sourcePath: "/tmp/project/.claude/settings.local.json")
        let settings = ResolvedSettingsSnapshot(
            entries: [
                ResolvedSettingsEntry(
                    keyPath: "hooks",
                    value: ResolvedValue(
                        effectiveValue: .object([
                            "postToolUse": .array([
                                .object(["type": .string("http"), "url": .string("https://hooks.example/internal")])
                            ]),
                            "preToolUse": .object([
                                "matcher": .string("Bash"),
                                "hooks": .array([
                                    .object(["type": .string("command"), "command": .string("echo ok"), "timeout": .number(12)])
                                ])
                            ])
                        ]),
                        winningSource: source,
                        trace: ResolutionTrace(participants: [source]),
                        mergeMethod: .keyedByIdentifier
                    )
                )
            ]
        )
        let projection = SessionProjectionBuilder().build(from: SessionProjectionBuilder.Input(settings: settings))

        let viewModel = SessionHooksViewModel(projection: projection)

        XCTAssertEqual(viewModel.state, .populated)
        XCTAssertEqual(viewModel.groupCount, 2)
        XCTAssertEqual(viewModel.rowCount, 2)
        XCTAssertEqual(viewModel.catalogSections.map(\.title), ["Tool And Turn Flow"])
        XCTAssertEqual(viewModel.groups.map(\.eventID), ["postToolUse", "preToolUse"])
        XCTAssertEqual(viewModel.groups.map(\.eventTitle), ["PostToolUse", "PreToolUse"])
        XCTAssertEqual(viewModel.groups[0].matcherLabel, "(none)")
        XCTAssertEqual(viewModel.groups[0].matcherDetail, "Matcher: none")
        XCTAssertEqual(viewModel.groups[1].matcherLabel, "Bash")
        XCTAssertEqual(viewModel.groups[1].matcherDetail, "Matcher: Bash")
        XCTAssertEqual(viewModel.groups[1].rows.first?.handlerTitle, "Command handler")
        XCTAssertEqual(viewModel.groups[1].rows.first?.primaryDetail, "Command: echo ok")
        XCTAssertEqual(viewModel.groups[1].rows.first?.detailLines, ["Timeout: 12s"])
    }

    func testSessionHooksViewModelShowsHookEventCapabilityBadges() {
        let source = makeSource(identifier: "project-local", scope: .projectLocal, sourcePath: "/tmp/project/.claude/settings.local.json")
        let settings = ResolvedSettingsSnapshot(
            entries: [
                ResolvedSettingsEntry(
                    keyPath: "hooks",
                    value: ResolvedValue(
                        effectiveValue: .object([
                            "UserPromptSubmit": .array([
                                .object(["type": .string("command"), "command": .string("echo gate")])
                            ])
                        ]),
                        winningSource: source,
                        trace: ResolutionTrace(participants: [source]),
                        mergeMethod: .keyedByIdentifier
                    )
                )
            ]
        )
        let projection = SessionProjectionBuilder().build(from: SessionProjectionBuilder.Input(settings: settings))

        let viewModel = SessionHooksViewModel(projection: projection)
        let group = tryUnwrapHookGroup(viewModel: viewModel, eventID: "UserPromptSubmit")

        XCTAssertEqual(group.capabilityBadges.map(\.title), ["Blocking", "Context injection"])
        XCTAssertEqual(group.capabilityNote, "Prompt erasure: a successful block result can remove the user's prompt from model context.")
    }

    func testSessionHooksViewModelRendersRestrictionBadgesFromEffectiveSettings() {
        let source = makeSource(identifier: "project-local", scope: .projectLocal, sourcePath: "/tmp/project/.claude/settings.local.json")
        let settings = ResolvedSettingsSnapshot(
            entries: [
                ResolvedSettingsEntry(
                    keyPath: "disableAllHooks",
                    value: ResolvedValue(
                        effectiveValue: .bool(true),
                        winningSource: source,
                        trace: ResolutionTrace(participants: [source]),
                        mergeMethod: .replace
                    )
                ),
                ResolvedSettingsEntry(
                    keyPath: "allowManagedHooksOnly",
                    value: ResolvedValue(
                        effectiveValue: .bool(true),
                        winningSource: source,
                        trace: ResolutionTrace(participants: [source]),
                        mergeMethod: .replace
                    )
                ),
                ResolvedSettingsEntry(
                    keyPath: "allowedHttpHookUrls",
                    value: ResolvedValue(
                        effectiveValue: .array([.string("https://hooks.example/*"), .string("https://hooks.internal/*")]),
                        winningSource: source,
                        trace: ResolutionTrace(participants: [source]),
                        mergeMethod: .appendUnique
                    )
                ),
                ResolvedSettingsEntry(
                    keyPath: "hooks",
                    value: ResolvedValue(
                        effectiveValue: .object(["preToolUse": .array([])]),
                        winningSource: source,
                        trace: ResolutionTrace(participants: [source]),
                        mergeMethod: .keyedByIdentifier
                    )
                )
            ]
        )
        let projection = SessionProjectionBuilder().build(from: SessionProjectionBuilder.Input(settings: settings))

        let viewModel = SessionHooksViewModel(projection: projection)

        XCTAssertEqual(viewModel.policyBanners.map(\.title), ["All hooks disabled", "Managed hooks only"])
        XCTAssertEqual(viewModel.restrictionBadges.count, 1)
        XCTAssertEqual(viewModel.restrictionBadges.map(\.title), ["HTTP URL Allowlist"])
        XCTAssertTrue(viewModel.restrictionBadges.contains(where: { $0.detail.contains("2 allowed URL patterns") }))
    }

    func testSessionHooksViewModelSurfacesHandlerSpecificDetailsAndIndicators() throws {
        let source = makeSource(identifier: "user-settings", scope: .user, sourcePath: "/tmp/.claude/settings.json")
        let settings = ResolvedSettingsSnapshot(
            entries: [
                ResolvedSettingsEntry(
                    keyPath: "hooks",
                    value: ResolvedValue(
                        effectiveValue: .object([
                            "PreToolUse": .array([
                                .object([
                                    "type": .string("command"),
                                    "command": .string("lint.sh"),
                                    "if": .string("tool == 'Bash'"),
                                    "async": .bool(true),
                                    "shell": .string("bash"),
                                    "statusMessage": .string("Linting"),
                                    "timeout": .number(30)
                                ]),
                                .object([
                                    "type": .string("http"),
                                    "url": .string("https://hooks.example.com/check"),
                                    "headers": .object(["Authorization": .string("Bearer $TOKEN")]),
                                    "allowedEnvVars": .array([.string("TOKEN")])
                                ])
                            ])
                        ]),
                        winningSource: source,
                        trace: ResolutionTrace(participants: [source]),
                        mergeMethod: .keyedByIdentifier
                    )
                )
            ]
        )

        let projection = SessionProjectionBuilder().build(from: SessionProjectionBuilder.Input(settings: settings))
        let viewModel = SessionHooksViewModel(projection: projection)
        let group = tryUnwrapHookGroup(viewModel: viewModel, eventID: "PreToolUse")
        let commandRow = try XCTUnwrap(group.rows.first)
        let httpRow = try XCTUnwrap(group.rows.last)

        XCTAssertEqual(commandRow.handlerTitle, "Command handler")
        XCTAssertEqual(commandRow.primaryDetail, "Command: lint.sh")
        XCTAssertTrue(commandRow.detailLines.contains("Condition: tool == 'Bash'"))
        XCTAssertTrue(commandRow.detailLines.contains("Shell: bash"))
        XCTAssertTrue(commandRow.detailLines.contains("Status message: Linting"))
        XCTAssertEqual(commandRow.indicatorBadges.map(\.title), ["Conditional", "Async"])

        XCTAssertEqual(httpRow.handlerTitle, "HTTP handler")
        XCTAssertEqual(httpRow.primaryDetail, "URL: https://hooks.example.com/check")
        XCTAssertTrue(httpRow.detailLines.contains("Headers: Authorization"))
        XCTAssertTrue(httpRow.detailLines.contains("Allowed env vars: TOKEN"))
    }

    func testSessionHooksViewModelMapsInvalidHookDiagnosticsAndPartialState() {
        let source = makeSource(identifier: "project-local", scope: .projectLocal, sourcePath: "/tmp/project/.claude/settings.local.json")
        let invalidIssue = ResolutionIssue(
            code: .unsupportedShape,
            severity: .warning,
            message: "Hook event object must include a 'hooks' array.",
            source: source,
            keyPath: "hooks.preToolUse"
        )
        let settings = ResolvedSettingsSnapshot(
            entries: [
                ResolvedSettingsEntry(
                    keyPath: "hooks",
                    value: ResolvedValue(
                        effectiveValue: .object(["preToolUse": .object(["matcher": .string("Bash")])]),
                        winningSource: source,
                        trace: ResolutionTrace(participants: [source]),
                        mergeMethod: .keyedByIdentifier,
                        issues: [invalidIssue]
                    )
                )
            ],
            issues: [invalidIssue]
        )
        let projection = SessionProjectionBuilder().build(from: SessionProjectionBuilder.Input(settings: settings))

        let viewModel = SessionHooksViewModel(projection: projection)

        XCTAssertEqual(viewModel.state, .populated)
        XCTAssertEqual(viewModel.warningCount, 1)
        XCTAssertEqual(viewModel.errorCount, 0)
        XCTAssertEqual(viewModel.issues.count, 1)
        XCTAssertEqual(viewModel.issues.first?.keyPath, "hooks.preToolUse")
        XCTAssertEqual(viewModel.stateLabel, "Populated")
    }

    func testSessionHooksViewModelSupportsMissingWinningSourceInPartialProvenanceState() {
        let source = makeSource(identifier: "user-settings", scope: .user, sourcePath: "/tmp/.claude/settings.json")
        let settings = ResolvedSettingsSnapshot(
            entries: [
                ResolvedSettingsEntry(
                    keyPath: "hooks",
                    value: ResolvedValue(
                        effectiveValue: .object([
                            "preToolUse": .array([
                                .object(["type": .string("command"), "command": .string("echo partial")])
                            ])
                        ]),
                        winningSource: nil,
                        trace: ResolutionTrace(participants: [source]),
                        mergeMethod: .keyedByIdentifier
                    )
                )
            ]
        )
        let projection = SessionProjectionBuilder().build(from: SessionProjectionBuilder.Input(settings: settings))

        let viewModel = SessionHooksViewModel(projection: projection)
        let firstRow = viewModel.groups.first?.rows.first

        XCTAssertEqual(viewModel.state, .populated)
        XCTAssertNil(firstRow?.winningSourceChip)
        XCTAssertTrue(viewModel.summaryNotes.contains(where: { $0.contains("partial provenance") }))
    }

    func testSessionMCPViewModelSupportsMissingState() {
        let projection = SessionProjectionBuilder().build(from: SessionProjectionBuilder.Input())

        let viewModel = SessionMCPViewModel(projection: projection)

        XCTAssertEqual(viewModel.state, .missing)
        XCTAssertTrue(viewModel.serverRows.isEmpty)
        XCTAssertEqual(viewModel.conflictCount, 0)
        XCTAssertEqual(viewModel.environmentNoteCount, 0)
        XCTAssertTrue(viewModel.summaryNotes.contains(where: { $0.contains("missing families") }))
    }

    func testSessionMCPViewModelSupportsEmptySnapshotState() {
        let projection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(mcp: ResolvedMcpSnapshot(servers: []))
        )

        let viewModel = SessionMCPViewModel(projection: projection)

        XCTAssertEqual(viewModel.state, .empty)
        XCTAssertEqual(viewModel.serverRows.count, 0)
        XCTAssertEqual(viewModel.overriddenServers.count, 0)
    }

    func testSessionMCPViewModelSortsRowsDeterministicallyAndMapsSingleSourceProvenance() {
        let source = makeSource(identifier: "project-mcp", scope: .project, sourcePath: "/tmp/project/.mcp.json")
        let snapshot = ResolvedMcpSnapshot(
            servers: [
                ResolvedMcpServerEntry(
                    serverID: "zeta",
                    resolvedConfig: ResolvedValue(
                        effectiveValue: .object(["command": .string("zeta-cmd")]),
                        winningSource: source,
                        trace: ResolutionTrace(participants: [source]),
                        mergeMethod: .selectHighestPrecedence
                    )
                ),
                ResolvedMcpServerEntry(
                    serverID: "alpha",
                    resolvedConfig: ResolvedValue(
                        effectiveValue: .object(["command": .string("alpha-cmd")]),
                        winningSource: source,
                        trace: ResolutionTrace(participants: [source]),
                        mergeMethod: .selectHighestPrecedence
                    )
                )
            ]
        )
        let projection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(mcp: snapshot)
        )

        let viewModel = SessionMCPViewModel(projection: projection)

        XCTAssertEqual(viewModel.state, .populated)
        XCTAssertEqual(viewModel.serverRows.map(\.serverID), ["alpha", "zeta"])
        XCTAssertEqual(viewModel.serverRows.first?.winningSourceChip?.label, "/tmp/project/.mcp.json")
        XCTAssertEqual(viewModel.serverRows.first?.mergeMethodLabel, "Select Highest")
        XCTAssertEqual(viewModel.serverRows.first?.participantSourceChips.map(\.label), ["/tmp/project/.mcp.json"])
    }

    func testSessionMCPViewModelShowsOverriddenDefinitionDetails() {
        let local = makeSource(identifier: "local-mcp", scope: .projectLocal, sourcePath: "/tmp/project/.mcp.local.json")
        let user = makeSource(identifier: "user-mcp", scope: .user, sourcePath: "/tmp/.mcp.json")
        let snapshot = ResolvedMcpSnapshot(
            servers: [
                ResolvedMcpServerEntry(
                    serverID: "filesystem",
                    resolvedConfig: ResolvedValue(
                        effectiveValue: .object(["command": .string("npx")]),
                        winningSource: local,
                        trace: ResolutionTrace(
                            participants: [local, user],
                            overridden: [user],
                            notes: ["Local MCP definition overrides user definition by precedence."]
                        ),
                        mergeMethod: .selectHighestPrecedence
                    )
                )
            ]
        )
        let projection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(mcp: snapshot)
        )

        let viewModel = SessionMCPViewModel(projection: projection)

        XCTAssertEqual(viewModel.overriddenServers.count, 1)
        XCTAssertEqual(viewModel.overriddenServers.first?.serverID, "filesystem")
        XCTAssertEqual(viewModel.overriddenServers.first?.overriddenSourceLabels, ["/tmp/.mcp.json"])
        XCTAssertTrue(viewModel.overriddenServers.first?.reason.contains("overrides") == true)
    }

    func testSessionMCPViewModelExposesConflictInvalidAndEnvironmentDiagnostics() {
        let source = makeSource(identifier: "project-mcp", scope: .project, sourcePath: "/tmp/project/.mcp.json")
        let duplicateIssue = ResolutionIssue(
            code: .duplicateIdentifier,
            severity: .warning,
            message: "Duplicate MCP server id 'filesystem' found within source.",
            source: source,
            keyPath: "mcpServers.filesystem"
        )
        let conflictIssue = ResolutionIssue(
            code: .conflict,
            severity: .error,
            message: "Conflicting MCP transport definitions for 'filesystem'.",
            source: source,
            keyPath: "mcpServers.filesystem"
        )
        let invalidIssue = ResolutionIssue(
            code: .typeMismatch,
            severity: .error,
            message: "MCP server must define either command or url transport.",
            source: source,
            keyPath: "mcpServers.filesystem"
        )
        let snapshot = ResolvedMcpSnapshot(
            servers: [
                ResolvedMcpServerEntry(
                    serverID: "filesystem",
                    resolvedConfig: ResolvedValue(
                        effectiveValue: .object([
                            "command": .string("npx"),
                            "env": .object(["API_KEY": .string("${API_KEY}")])
                        ]),
                        winningSource: source,
                        trace: ResolutionTrace(participants: [source]),
                        mergeMethod: .selectHighestPrecedence,
                        issues: [invalidIssue]
                    ),
                    environmentNotes: [
                        McpEnvironmentNote(
                            fieldPath: "env.API_KEY",
                            classification: .containsReference,
                            message: "MCP field 'env.API_KEY' contains an environment reference pattern."
                        )
                    ]
                )
            ],
            issues: [duplicateIssue, conflictIssue]
        )
        let projection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(mcp: snapshot)
        )

        let viewModel = SessionMCPViewModel(projection: projection)

        XCTAssertEqual(viewModel.conflictCount, 2)
        XCTAssertEqual(viewModel.invalidDefinitionCount, 1)
        XCTAssertEqual(viewModel.environmentNoteCount, 1)
        XCTAssertEqual(viewModel.errorCount, 2)
        XCTAssertEqual(viewModel.warningCount, 1)
        XCTAssertTrue(viewModel.issueBadges.contains(where: { $0.severity == .error && $0.count == 2 }))
        XCTAssertTrue(viewModel.issueBadges.contains(where: { $0.severity == .warning && $0.count == 1 }))
        XCTAssertTrue(viewModel.diagnostics.contains(where: { $0.message.contains("environment reference pattern") }))
    }

    func testSessionMCPViewModelSupportsPartialStateWhenWinningSourceIsMissing() {
        let participant = makeSource(identifier: "user-mcp", scope: .user, sourcePath: "/tmp/.mcp.json")
        let snapshot = ResolvedMcpSnapshot(
            servers: [
                ResolvedMcpServerEntry(
                    serverID: "unresolved",
                    resolvedConfig: ResolvedValue(
                        effectiveValue: nil,
                        winningSource: nil,
                        trace: ResolutionTrace(participants: [participant]),
                        mergeMethod: .selectHighestPrecedence
                    )
                )
            ]
        )
        let projection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(mcp: snapshot)
        )

        let viewModel = SessionMCPViewModel(projection: projection)

        XCTAssertEqual(viewModel.state, .populated)
        XCTAssertTrue(viewModel.isPartial)
        XCTAssertEqual(viewModel.stateLabel, "Partial")
        XCTAssertTrue(viewModel.summaryNotes.contains(where: { $0.contains("partial provenance") }))
    }

    func testSessionMCPViewModelSurfacesPolicyBannersAndEffectiveStateBreakdown() {
        let managedSource = makeSource(identifier: "managed-mcp", scope: .managed, sourcePath: "/tmp/managed-mcp.json")
        let userSource = makeSource(identifier: "user-mcp", scope: .user, sourcePath: "/tmp/.mcp.json")
        let policySource = makeSource(identifier: "managed-settings", scope: .managed, sourcePath: "/tmp/managed-settings.json")
        let settings = ResolvedSettingsSnapshot(
            entries: [
                ResolvedSettingsEntry(
                    keyPath: "allowManagedMcpServersOnly",
                    value: ResolvedValue(
                        effectiveValue: .bool(true),
                        winningSource: policySource,
                        trace: ResolutionTrace(participants: [policySource]),
                        mergeMethod: .selectHighestPrecedence
                    )
                ),
                ResolvedSettingsEntry(
                    keyPath: "deniedMcpServers",
                    value: ResolvedValue(
                        effectiveValue: .array([.object(["serverName": .string("denied-srv")])]),
                        winningSource: policySource,
                        trace: ResolutionTrace(participants: [policySource]),
                        mergeMethod: .appendUnique
                    )
                )
            ]
        )
        let snapshot = ResolvedMcpSnapshot(
            servers: [
                ResolvedMcpServerEntry(
                    serverID: "managed-srv",
                    resolvedConfig: ResolvedValue(
                        effectiveValue: .object(["command": .string("managed-cmd")]),
                        winningSource: managedSource,
                        trace: ResolutionTrace(participants: [managedSource]),
                        mergeMethod: .selectHighestPrecedence
                    )
                ),
                ResolvedMcpServerEntry(
                    serverID: "blocked-srv",
                    resolvedConfig: ResolvedValue(
                        effectiveValue: .object(["command": .string("user-cmd")]),
                        winningSource: userSource,
                        trace: ResolutionTrace(participants: [userSource]),
                        mergeMethod: .selectHighestPrecedence
                    )
                )
            ]
        )

        let projection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(settings: settings, mcp: snapshot)
        )

        let viewModel = SessionMCPViewModel(projection: projection)

        XCTAssertEqual(viewModel.managedCount, 1)
        XCTAssertEqual(viewModel.blockedCount, 1)
        XCTAssertEqual(viewModel.activeCount, 0)
        XCTAssertEqual(viewModel.stateBreakdownSummary, "1 managed, 1 blocked")
        XCTAssertEqual(viewModel.policyBanners.map(\.title), ["Managed MCP only", "MCP deny rules active"])
    }

    func testSessionMCPViewModelBuildsTransportAndPolicyDetailsFromNormalizedServerConfig() throws {
        let source = makeSource(identifier: "project-mcp", scope: .project, sourcePath: "/tmp/project/.mcp.json")
        let settingsSource = makeSource(identifier: "project-settings", scope: .project, sourcePath: "/tmp/project/.claude/settings.json")
        let settings = ResolvedSettingsSnapshot(
            entries: [
                ResolvedSettingsEntry(
                    keyPath: "enableAllProjectMcpServers",
                    value: ResolvedValue(
                        effectiveValue: .bool(true),
                        winningSource: settingsSource,
                        trace: ResolutionTrace(participants: [settingsSource]),
                        mergeMethod: .selectHighestPrecedence
                    )
                )
            ]
        )
        let snapshot = ResolvedMcpSnapshot(
            servers: [
                ResolvedMcpServerEntry(
                    serverID: "filesystem",
                    resolvedConfig: ResolvedValue(
                        effectiveValue: .object([
                            "command": .string("npx"),
                            "args": .array([.string("-y"), .string("@modelcontextprotocol/server-filesystem")]),
                            "cwd": .string("/tmp/project"),
                            "env": .object(["HOME": .string("/Users/test")])
                        ]),
                        winningSource: source,
                        trace: ResolutionTrace(participants: [source]),
                        mergeMethod: .selectHighestPrecedence
                    )
                )
            ]
        )

        let projection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(settings: settings, mcp: snapshot)
        )

        let viewModel = SessionMCPViewModel(projection: projection)
        let row = try XCTUnwrap(viewModel.serverRows.first)

        XCTAssertEqual(row.effectiveStateLabel, "Active")
        XCTAssertEqual(row.transportLabel, "stdio")
        XCTAssertEqual(row.transportPrimaryDetail, "npx -y @modelcontextprotocol/server-filesystem")
        XCTAssertTrue(row.transportDetailLines.contains("Working directory: /tmp/project"))
        XCTAssertTrue(row.transportDetailLines.contains("Environment: 1 variable"))
        XCTAssertEqual(row.policyEffectBadges.map(\.title), ["Project Auto-Enable"])
        XCTAssertTrue(row.policyEffectDetails.contains("Server 'filesystem' is auto-enabled by enableAllProjectMcpServers."))
    }

    func testSessionAgentsSkillsViewModelSupportsMissingState() {
        let projection = SessionProjectionBuilder().build(from: SessionProjectionBuilder.Input())

        let viewModel = SessionAgentsSkillsViewModel(projection: projection)

        XCTAssertEqual(viewModel.state, .missing)
        XCTAssertTrue(viewModel.agentRows.isEmpty)
        XCTAssertTrue(viewModel.skillRows.isEmpty)
        XCTAssertTrue(viewModel.summaryNotes.contains(where: { $0.contains("missing families") }))
    }

    func testSessionAgentsSkillsViewModelSortsRowsDeterministicallyInEffectiveState() {
        let userAgentSource = makeSource(identifier: "user-agent-zeta", scope: .user, sourcePath: "/tmp/.claude/agents/zeta.md")
        let projectAgentSource = makeSource(identifier: "project-agent-alpha", scope: .project, sourcePath: "/tmp/project/.claude/agents/alpha.md")
        let userSkillSource = makeSource(identifier: "user-skill-zeta", scope: .user, sourcePath: "/tmp/.claude/skills/zeta/SKILL.md")
        let projectSkillSource = makeSource(identifier: "project-skill-alpha", scope: .project, sourcePath: "/tmp/project/.claude/skills/alpha/SKILL.md")

        let agentSnapshot = ResolvedAgentSnapshot(
            agents: [
                makeResolvedAgentEntry(agentID: "zeta", source: userAgentSource, visibility: .effective),
                makeResolvedAgentEntry(agentID: "alpha", source: projectAgentSource, visibility: .effective)
            ]
        )
        let skillSnapshot = ResolvedSkillSnapshot(
            skills: [
                makeResolvedSkillEntry(skillID: "zeta", source: userSkillSource, visibility: .effective),
                makeResolvedSkillEntry(skillID: "alpha", source: projectSkillSource, visibility: .effective)
            ]
        )
        let projection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(agents: agentSnapshot, skills: skillSnapshot)
        )

        let viewModel = SessionAgentsSkillsViewModel(projection: projection)

        XCTAssertEqual(viewModel.state, .populated)
        XCTAssertFalse(viewModel.isPartial)
        XCTAssertEqual(viewModel.agentRows.map(\.agentID), ["alpha", "zeta"])
        XCTAssertEqual(viewModel.skillRows.map(\.skillID), ["alpha", "zeta"])
        XCTAssertEqual(viewModel.overriddenCount, 0)
    }

    func testSessionAgentsSkillsViewModelShowsOverriddenEntriesAndDuplicateDiagnostics() {
        let projectAgentSource = makeSource(identifier: "project-agent-reviewer", scope: .project, sourcePath: "/tmp/project/.claude/agents/reviewer.md")
        let userAgentSource = makeSource(identifier: "user-agent-reviewer", scope: .user, sourcePath: "/tmp/.claude/agents/reviewer.md")
        let projectSkillSource = makeSource(identifier: "project-skill-release", scope: .project, sourcePath: "/tmp/project/.claude/skills/release/SKILL.md")
        let userSkillSource = makeSource(identifier: "user-skill-release", scope: .user, sourcePath: "/tmp/.claude/skills/release/SKILL.md")

        let duplicateAgentIssue = ResolutionIssue(
            code: .duplicateIdentifier,
            severity: .warning,
            message: "Agent identity 'reviewer' was overridden by a higher-precedence definition.",
            source: userAgentSource,
            keyPath: "reviewer",
            relatedSources: [projectAgentSource, userAgentSource]
        )
        let duplicateSkillIssue = ResolutionIssue(
            code: .duplicateIdentifier,
            severity: .warning,
            message: "Skill identity 'release' was overridden by a higher-precedence definition.",
            source: userSkillSource,
            keyPath: "release",
            relatedSources: [projectSkillSource, userSkillSource]
        )

        let agents = ResolvedAgentSnapshot(
            agents: [
                makeResolvedAgentEntry(
                    agentID: "reviewer",
                    source: projectAgentSource,
                    visibility: .effective,
                    participants: [projectAgentSource, userAgentSource],
                    overridden: [userAgentSource],
                    winner: projectAgentSource
                ),
                makeResolvedAgentEntry(
                    agentID: "reviewer",
                    source: userAgentSource,
                    visibility: .overridden,
                    participants: [projectAgentSource, userAgentSource],
                    overridden: [userAgentSource],
                    winner: projectAgentSource,
                    issues: [duplicateAgentIssue]
                )
            ],
            issues: [duplicateAgentIssue]
        )
        let skills = ResolvedSkillSnapshot(
            skills: [
                makeResolvedSkillEntry(
                    skillID: "release",
                    source: projectSkillSource,
                    visibility: .effective,
                    participants: [projectSkillSource, userSkillSource],
                    overridden: [userSkillSource],
                    winner: projectSkillSource
                ),
                makeResolvedSkillEntry(
                    skillID: "release",
                    source: userSkillSource,
                    visibility: .overridden,
                    participants: [projectSkillSource, userSkillSource],
                    overridden: [userSkillSource],
                    winner: projectSkillSource,
                    issues: [duplicateSkillIssue]
                )
            ],
            issues: [duplicateSkillIssue]
        )
        let projection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(agents: agents, skills: skills)
        )

        let viewModel = SessionAgentsSkillsViewModel(projection: projection)

        XCTAssertEqual(viewModel.overriddenCount, 2)
        XCTAssertEqual(viewModel.overrides.count, 2)
        XCTAssertEqual(viewModel.warningCount, 2)
        XCTAssertTrue(viewModel.diagnostics.contains(where: { $0.message.contains("Agent identity 'reviewer'") }))
        XCTAssertTrue(viewModel.diagnostics.contains(where: { $0.message.contains("Skill identity 'release'") }))
    }

    func testSessionAgentsSkillsViewModelSurfacesInvalidDefinitionDiagnostics() {
        let invalidAgentSource = makeSource(identifier: "invalid-agent", scope: .project, sourcePath: "/tmp/project/.claude/agents/invalid.md")
        let invalidSkillSource = makeSource(identifier: "invalid-skill", scope: .project, sourcePath: "/tmp/project/.claude/skills/invalid/SKILL.md")
        let invalidAgentIssue = ResolutionIssue(
            code: .invalidSource,
            severity: .error,
            message: "Agent source is present but did not produce a parsed document.",
            source: invalidAgentSource,
            keyPath: "invalid-agent"
        )
        let invalidSkillIssue = ResolutionIssue(
            code: .unsupportedShape,
            severity: .error,
            message: "Skill directory is missing SKILL.md and remains discovered but unavailable for effective visibility.",
            source: invalidSkillSource,
            keyPath: "invalid-skill"
        )

        let agents = ResolvedAgentSnapshot(
            agents: [
                makeResolvedAgentEntry(
                    agentID: "invalid-agent",
                    source: invalidAgentSource,
                    visibility: .invalid,
                    issues: [invalidAgentIssue],
                    includeDefinitionDocument: false
                )
            ],
            issues: [invalidAgentIssue]
        )
        let skills = ResolvedSkillSnapshot(
            skills: [
                makeResolvedSkillEntry(
                    skillID: "invalid-skill",
                    source: invalidSkillSource,
                    visibility: .invalid,
                    issues: [invalidSkillIssue],
                    includeDefinitionDocument: false
                )
            ],
            issues: [invalidSkillIssue]
        )
        let projection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(agents: agents, skills: skills)
        )

        let viewModel = SessionAgentsSkillsViewModel(projection: projection)

        XCTAssertEqual(viewModel.state, .populated)
        XCTAssertTrue(viewModel.isPartial)
        XCTAssertEqual(viewModel.invalidCount, 2)
        XCTAssertEqual(viewModel.errorCount, 2)
        XCTAssertTrue(viewModel.diagnostics.contains(where: { $0.message.contains("did not produce a parsed document") }))
        XCTAssertTrue(viewModel.diagnostics.contains(where: { $0.message.contains("missing SKILL.md") }))
    }

    func testSessionAgentsSkillsViewModelSupportsEmptyAndPartialFamilyStates() {
        let emptyProjection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(
                agents: ResolvedAgentSnapshot(agents: []),
                skills: ResolvedSkillSnapshot(skills: [])
            )
        )
        let emptyViewModel = SessionAgentsSkillsViewModel(projection: emptyProjection)
        XCTAssertEqual(emptyViewModel.state, .empty)

        let agentSource = makeSource(identifier: "project-agent-only", scope: .project, sourcePath: "/tmp/project/.claude/agents/only.md")
        let unavailableAgentSource = ResolutionSource(
            scope: .user,
            kind: .file,
            identifier: "user-agent-unavailable",
            sourcePath: "/tmp/.claude/agents/unavailable.md",
            availability: .missing
        )
        let unavailableIssue = ResolutionIssue(
            code: .missingSource,
            severity: .warning,
            message: "Agent source is missing and was skipped.",
            source: unavailableAgentSource,
            keyPath: "unavailable"
        )
        let partialProjection = SessionProjectionBuilder().build(
            from: SessionProjectionBuilder.Input(
                agents: ResolvedAgentSnapshot(
                    agents: [
                        makeResolvedAgentEntry(agentID: "only", source: agentSource, visibility: .effective),
                        makeResolvedAgentEntry(
                            agentID: "unavailable",
                            source: unavailableAgentSource,
                            visibility: .unavailable,
                            issues: [unavailableIssue],
                            includeDefinitionDocument: false
                        )
                    ],
                    issues: [unavailableIssue]
                ),
                skills: nil
            )
        )
        let partialViewModel = SessionAgentsSkillsViewModel(projection: partialProjection)
        XCTAssertEqual(partialViewModel.state, .populated)
        XCTAssertTrue(partialViewModel.isPartial)
        XCTAssertEqual(partialViewModel.unavailableCount, 1)
        XCTAssertTrue(partialViewModel.summaryNotes.contains(where: { $0.contains("Only one of agents/skills families") }))
    }

    // MARK: - R1 Expanded Settings Families Tests

    func testSettingsResolverUsesRegistryMergeHintForScalarKeys() {
        let resolver = SettingsResolver()
        let keys: [String: JSONValue] = [
            "model": .string("claude-sonnet-4-6"),
            "effortLevel": .string("high"),
            "defaultShell": .string("/bin/zsh"),
            "language": .string("en"),
            "alwaysThinkingEnabled": .bool(true),
            "fastMode": .bool(false),
            "fastModePerSessionOptIn": .bool(true),
            "outputStyle": .string("concise"),
            "voiceEnabled": .bool(true),
            "prefersReducedMotion": .bool(false),
            "spinnerTipsEnabled": .bool(true),
            "respectGitignore": .bool(true),
            "autoMemoryEnabled": .bool(true),
            "disableAllHooks": .bool(false),
            "disableUpdateChecks": .bool(true),
            "plansDirectory": .string("/tmp/plans"),
            "autoUpdatesChannel": .string("stable"),
            "showClearContextOnPlanAccept": .bool(false),
            "feedbackSurveyRate": .number(0.1),
            "agent": .string("reviewer")
        ]

        let user = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: keys
        )

        var overrideTopLevel: [String: JSONValue] = [:]
        for (key, _) in keys {
            overrideTopLevel[key] = .string("override-\(key)")
        }
        let local = makeCandidate(
            tier: .projectLocal,
            identifier: "project-local-settings",
            scope: .projectLocal,
            sourcePath: "/tmp/project/.claude/settings.local.json",
            rawTopLevel: overrideTopLevel
        )

        let selection = resolver.resolvePrecedence(candidates: [user, local])
        let snapshot = resolver.buildSnapshot(from: selection)

        for key in keys.keys {
            let entry = snapshot.entries.first(where: { $0.keyPath == key })
            XCTAssertNotNil(entry, "Missing entry for key '\(key)'")
            XCTAssertEqual(entry?.value.mergeMethod, .replace, "Key '\(key)' should use replace merge method")
            XCTAssertEqual(entry?.value.winningSource?.identifier, "project-local-settings", "Key '\(key)' should be won by local")
        }
    }

    func testSettingsResolverUsesRegistryMergeHintForDeepMergeObjectKeys() {
        let resolver = SettingsResolver()
        let user = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: [
                "sandbox": .object([
                    "enabled": .bool(true),
                    "failIfUnavailable": .bool(false)
                ]),
                "worktree": .object([
                    "sparsePaths": .array([.string("/src")])
                ]),
                "statusLine": .object([
                    "command": .string("echo status"),
                    "padding": .number(2)
                ]),
                "fileSuggestion": .object([
                    "type": .string("default")
                ]),
                "spinnerVerbs": .object([
                    "mode": .string("custom"),
                    "verbs": .array([.string("thinking")])
                ]),
                "spinnerTipsOverride": .object([
                    "excludeDefault": .bool(true),
                    "tips": .array([.string("user tip")])
                ])
            ]
        )
        let local = makeCandidate(
            tier: .projectLocal,
            identifier: "project-local-settings",
            scope: .projectLocal,
            sourcePath: "/tmp/project/.claude/settings.local.json",
            rawTopLevel: [
                "sandbox": .object([
                    "enabled": .bool(false),
                    "autoAllowBashIfSandboxed": .bool(true)
                ]),
                "worktree": .object([
                    "symlinkDirectories": .array([.string("/lib")])
                ]),
                "statusLine": .object([
                    "command": .string("echo local-status")
                ]),
                "fileSuggestion": .object([
                    "command": .string("fzf")
                ]),
                "spinnerVerbs": .object([
                    "verbs": .array([.string("processing")])
                ]),
                "spinnerTipsOverride": .object([
                    "tips": .array([.string("local tip")])
                ])
            ]
        )

        let selection = resolver.resolvePrecedence(candidates: [user, local])
        let snapshot = resolver.buildSnapshot(from: selection)

        let sandboxEntry = tryUnwrapEntry(snapshot: snapshot, keyPath: "sandbox")
        XCTAssertEqual(sandboxEntry.value.mergeMethod, .deepMergeObject)
        guard case let .object(sandboxMerged) = sandboxEntry.value.effectiveValue else {
            XCTFail("sandbox should be object")
            return
        }
        XCTAssertEqual(sandboxMerged["enabled"], .bool(false))
        XCTAssertEqual(sandboxMerged["failIfUnavailable"], .bool(false))
        XCTAssertEqual(sandboxMerged["autoAllowBashIfSandboxed"], .bool(true))

        let worktreeEntry = tryUnwrapEntry(snapshot: snapshot, keyPath: "worktree")
        XCTAssertEqual(worktreeEntry.value.mergeMethod, .deepMergeObject)

        let statusLineEntry = tryUnwrapEntry(snapshot: snapshot, keyPath: "statusLine")
        XCTAssertEqual(statusLineEntry.value.mergeMethod, .deepMergeObject)
        guard case let .object(statusMerged) = statusLineEntry.value.effectiveValue else {
            XCTFail("statusLine should be object")
            return
        }
        XCTAssertEqual(statusMerged["command"], .string("echo local-status"))
        XCTAssertEqual(statusMerged["padding"], .number(2))
    }

    func testSettingsResolverUsesRegistryMergeHintForAppendUniqueArrayKeys() {
        let resolver = SettingsResolver()
        let user = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: [
                "companyAnnouncements": .array([.string("user-announcement")]),
                "claudeMdExcludes": .array([.string("*.tmp")]),
                "sandbox.excludedCommands": .array([.string("rm")]),
                "sandbox.filesystem.allowWrite": .array([.string("/tmp")]),
                "sandbox.network.allowedDomains": .array([.string("example.com")]),
                "worktree.sparsePaths": .array([.string("/src")]),
                "worktree.symlinkDirectories": .array([.string("/lib")])
            ]
        )
        let local = makeCandidate(
            tier: .projectLocal,
            identifier: "project-local-settings",
            scope: .projectLocal,
            sourcePath: "/tmp/project/.claude/settings.local.json",
            rawTopLevel: [
                "companyAnnouncements": .array([.string("local-announcement"), .string("user-announcement")]),
                "claudeMdExcludes": .array([.string("*.log"), .string("*.tmp")]),
                "sandbox.excludedCommands": .array([.string("rm"), .string("chmod")]),
                "sandbox.filesystem.allowWrite": .array([.string("/var")]),
                "sandbox.network.allowedDomains": .array([.string("example.com"), .string("anthropic.com")]),
                "worktree.sparsePaths": .array([.string("/src"), .string("/docs")]),
                "worktree.symlinkDirectories": .array([.string("/lib"), .string("/bin")])
            ]
        )

        let selection = resolver.resolvePrecedence(candidates: [user, local])
        let snapshot = resolver.buildSnapshot(from: selection)

        let announcements = tryUnwrapEntry(snapshot: snapshot, keyPath: "companyAnnouncements")
        XCTAssertEqual(announcements.value.mergeMethod, .appendUnique)

        let excludes = tryUnwrapEntry(snapshot: snapshot, keyPath: "claudeMdExcludes")
        XCTAssertEqual(excludes.value.mergeMethod, .appendUnique)
        XCTAssertEqual(
            excludes.value.effectiveValue,
            .array([.string("*.log"), .string("*.tmp")])
        )
    }

    func testSettingsResolverManagedPolicyMakesLowerScopeValuesIneffective() {
        let resolver = SettingsResolver()
        let managed = makeCandidate(
            tier: .managed,
            identifier: "managed-policy",
            scope: .managed,
            kind: .managed,
            rawTopLevel: [
                "model": .string("claude-opus-4-6"),
                "disableAllHooks": .bool(true)
            ]
        )
        let user = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: [
                "model": .string("claude-sonnet-4-6"),
                "disableAllHooks": .bool(false)
            ]
        )

        let selection = resolver.resolvePrecedence(candidates: [user, managed])
        let snapshot = resolver.buildSnapshot(from: selection)

        let modelEntry = tryUnwrapEntry(snapshot: snapshot, keyPath: "model")
        XCTAssertEqual(modelEntry.value.effectiveValue, .string("claude-opus-4-6"))
        XCTAssertEqual(modelEntry.value.winningSource?.identifier, "managed-policy")
        XCTAssertTrue(
            modelEntry.value.trace.notes.contains(where: { $0.contains("Managed policy is active") && $0.contains("ineffective") }),
            "Expected provenance note about managed policy suppressing lower scope"
        )
        XCTAssertTrue(
            modelEntry.value.trace.overridden.contains(where: { $0.identifier == "user-settings" })
        )

        XCTAssertTrue(
            snapshot.notes.contains(where: { $0.contains("Managed policy is active") })
        )
    }

    func testSettingsResolverManagedOnlyKeyInNonManagedScopeEmitsWarning() {
        let resolver = SettingsResolver()
        let user = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: [
                "allowManagedPermissionRulesOnly": .bool(true),
                "channelsEnabled": .bool(true)
            ]
        )

        let selection = resolver.resolvePrecedence(candidates: [user])
        let snapshot = resolver.buildSnapshot(from: selection)

        XCTAssertTrue(
            snapshot.issues.contains(where: {
                $0.code == .conflict && $0.message.contains("managed-only") && $0.keyPath == "allowManagedPermissionRulesOnly"
            }),
            "Expected warning for managed-only key in non-managed scope"
        )
        XCTAssertTrue(
            snapshot.issues.contains(where: {
                $0.code == .conflict && $0.message.contains("managed-only") && $0.keyPath == "channelsEnabled"
            }),
            "Expected warning for channelsEnabled in non-managed scope"
        )
    }

    func testSettingsResolverManagedOnlyKeyFromManagedScopeDoesNotWarn() {
        let resolver = SettingsResolver()
        let managed = makeCandidate(
            tier: .managed,
            identifier: "managed-policy",
            scope: .managed,
            kind: .managed,
            rawTopLevel: [
                "allowManagedPermissionRulesOnly": .bool(true),
                "channelsEnabled": .bool(true)
            ]
        )

        let selection = resolver.resolvePrecedence(candidates: [managed])
        let snapshot = resolver.buildSnapshot(from: selection)

        XCTAssertFalse(
            snapshot.issues.contains(where: {
                $0.code == .conflict && $0.message.contains("managed-only")
            }),
            "Should not warn when managed-only keys come from managed scope"
        )
    }

    func testSettingsResolverPluginAndMarketplaceKeysUseMergeHintsFromRegistry() {
        let resolver = SettingsResolver()
        let user = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: [
                "enabledPlugins": .object(["plugin-a": .bool(true)]),
                "extraKnownMarketplaces": .object(["mp-a": .object(["id": .string("a")])])
            ]
        )
        let local = makeCandidate(
            tier: .projectLocal,
            identifier: "project-local-settings",
            scope: .projectLocal,
            sourcePath: "/tmp/project/.claude/settings.local.json",
            rawTopLevel: [
                "enabledPlugins": .object(["plugin-b": .bool(false)]),
                "extraKnownMarketplaces": .object(["mp-b": .object(["id": .string("b")])])
            ]
        )

        let selection = resolver.resolvePrecedence(candidates: [user, local])
        let snapshot = resolver.buildSnapshot(from: selection)

        let pluginsEntry = tryUnwrapEntry(snapshot: snapshot, keyPath: "enabledPlugins")
        XCTAssertEqual(pluginsEntry.value.mergeMethod, .deepMergeObject)
        guard case let .object(merged) = pluginsEntry.value.effectiveValue else {
            XCTFail("enabledPlugins should merge as object")
            return
        }
        XCTAssertEqual(merged["plugin-a"], .bool(true))
        XCTAssertEqual(merged["plugin-b"], .bool(false))

        let marketplaces = tryUnwrapEntry(snapshot: snapshot, keyPath: "extraKnownMarketplaces")
        XCTAssertEqual(marketplaces.value.mergeMethod, .deepMergeObject)
    }

    func testSettingsResolverMcpControlKeysResolveCorrectly() {
        let resolver = SettingsResolver()
        let user = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: [
                "enabledMcpjsonServers": .array([.string("server-a")]),
                "disabledMcpjsonServers": .array([.string("server-b")]),
                "enableAllProjectMcpServers": .bool(false),
                "deniedMcpServers": .array([.object(["serverName": .string("bad-server")])])
            ]
        )
        let local = makeCandidate(
            tier: .projectLocal,
            identifier: "project-local-settings",
            scope: .projectLocal,
            sourcePath: "/tmp/project/.claude/settings.local.json",
            rawTopLevel: [
                "enabledMcpjsonServers": .array([.string("server-a"), .string("server-c")]),
                "disabledMcpjsonServers": .array([.string("server-d")]),
                "enableAllProjectMcpServers": .bool(true),
                "deniedMcpServers": .array([.object(["serverName": .string("worse-server")])])
            ]
        )

        let selection = resolver.resolvePrecedence(candidates: [user, local])
        let snapshot = resolver.buildSnapshot(from: selection)

        let enabled = tryUnwrapEntry(snapshot: snapshot, keyPath: "enabledMcpjsonServers")
        XCTAssertEqual(enabled.value.mergeMethod, .appendUnique)
        XCTAssertEqual(
            enabled.value.effectiveValue,
            .array([.string("server-a"), .string("server-c")])
        )

        let enableAll = tryUnwrapEntry(snapshot: snapshot, keyPath: "enableAllProjectMcpServers")
        XCTAssertEqual(enableAll.value.mergeMethod, .replace)
        XCTAssertEqual(enableAll.value.winningSource?.identifier, "project-local-settings")

        let denied = tryUnwrapEntry(snapshot: snapshot, keyPath: "deniedMcpServers")
        XCTAssertEqual(denied.value.mergeMethod, .appendUnique)
    }

    func testSettingsResolverUnknownKeyFallsToPassthrough() {
        let resolver = SettingsResolver()
        let user = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: ["someUnknownFutureKey": .string("value")]
        )

        let selection = resolver.resolvePrecedence(candidates: [user])
        let snapshot = resolver.buildSnapshot(from: selection)

        let entry = tryUnwrapEntry(snapshot: snapshot, keyPath: "someUnknownFutureKey")
        XCTAssertEqual(entry.value.mergeMethod, .passthrough)
    }

    func testSettingsResolverAllRegistryKeysHaveExplicitMergeMethod() {
        let resolver = SettingsResolver()
        let registry = SettingsKeyRegistry.shared
        var rawTopLevel: [String: JSONValue] = [:]
        for definition in registry.allDefinitions {
            if definition.keyPath.contains(".") { continue }
            switch definition.type {
            case .string:
                rawTopLevel[definition.keyPath] = .string("test")
            case .bool:
                rawTopLevel[definition.keyPath] = .bool(true)
            case .integer, .number:
                rawTopLevel[definition.keyPath] = .number(1)
            case .stringArray:
                rawTopLevel[definition.keyPath] = .array([.string("test")])
            case .object, .dictionary:
                rawTopLevel[definition.keyPath] = .object(["key": .string("value")])
            case .anyArray:
                rawTopLevel[definition.keyPath] = .array([.string("test")])
            case .array:
                rawTopLevel[definition.keyPath] = .array([.object(["id": .string("test")])])
            case .oneOf, .anyValue:
                rawTopLevel[definition.keyPath] = .string("test")
            }
        }

        let candidate = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: rawTopLevel
        )
        let selection = resolver.resolvePrecedence(candidates: [candidate])
        let snapshot = resolver.buildSnapshot(from: selection)

        for entry in snapshot.entries {
            XCTAssertNotEqual(
                entry.value.mergeMethod, .passthrough,
                "Registry key '\(entry.keyPath)' should have an explicit merge method, not passthrough. " +
                "This means the registry defines a mergeHint but the resolver did not map it."
            )
        }
    }

    // MARK: - R2: HookResolver Tests

    func testHookResolverProducesTypedHandlersForAllFourHandlerTypes() {
        let resolver = SettingsResolver()
        let source = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: [
                "hooks": .object([
                    "PreToolUse": .array([
                        .object(["type": .string("command"), "command": .string("echo pre")]),
                        .object(["type": .string("http"), "url": .string("https://hooks.example.com/pre")]),
                        .object(["type": .string("prompt"), "prompt": .string("check this tool call")]),
                        .object(["type": .string("agent"), "prompt": .string("review code changes"), "model": .string("claude-sonnet-4-6")])
                    ])
                ])
            ]
        )

        let selection = resolver.resolvePrecedence(candidates: [source])
        let snapshot = resolver.buildSnapshot(from: selection)

        let projection = SessionProjectionBuilder().build(from: SessionProjectionBuilder.Input(settings: snapshot))
        let hooks = projection.hooks!

        let event = hooks.events.first(where: { $0.eventID == "PreToolUse" })!
        XCTAssertEqual(event.resolvedHandlers.count, 4)
        XCTAssertEqual(event.resolvedHandlers[0].handlerType, .command)
        XCTAssertEqual(event.resolvedHandlers[0].command, "echo pre")
        XCTAssertEqual(event.resolvedHandlers[1].handlerType, .http)
        XCTAssertEqual(event.resolvedHandlers[1].url, "https://hooks.example.com/pre")
        XCTAssertEqual(event.resolvedHandlers[2].handlerType, .prompt)
        XCTAssertEqual(event.resolvedHandlers[2].prompt, "check this tool call")
        XCTAssertEqual(event.resolvedHandlers[3].handlerType, .agent)
        XCTAssertEqual(event.resolvedHandlers[3].prompt, "review code changes")
        XCTAssertEqual(event.resolvedHandlers[3].model, "claude-sonnet-4-6")
    }

    func testHookResolverAppliesDisableAllHooksPolicy() {
        let resolver = SettingsResolver()
        let managed = makeCandidate(
            tier: .managed,
            identifier: "managed-policy",
            scope: .managed,
            kind: .managed,
            rawTopLevel: [
                "disableAllHooks": .bool(true)
            ]
        )
        let user = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: [
                "hooks": .object([
                    "PreToolUse": .array([
                        .object(["type": .string("command"), "command": .string("echo pre")])
                    ])
                ])
            ]
        )

        let selection = resolver.resolvePrecedence(candidates: [user, managed])
        let snapshot = resolver.buildSnapshot(from: selection)

        let projection = SessionProjectionBuilder().build(from: SessionProjectionBuilder.Input(settings: snapshot))
        let hooks: ResolvedHookSnapshot = projection.hooks!

        // All hooks should be suppressed
        XCTAssertTrue(hooks.policyEffects.contains(where: { $0.reason == .disableAllHooks }))
        XCTAssertTrue(hooks.notes.contains(where: { $0.contains("disableAllHooks") }))

        // Events are still present but marked as suppressed
        let event = hooks.events.first(where: { $0.eventID == "PreToolUse" })!
        XCTAssertNotNil(event.suppression)
        XCTAssertEqual(event.suppression?.reason, .disableAllHooks)

        // Policy source should be attributed
        XCTAssertEqual(hooks.policyEffects.first?.policySource?.identifier, "managed-policy")
    }

    func testHookResolverAppliesAllowManagedHooksOnlyPolicy() {
        let resolver = SettingsResolver()
        let managed = makeCandidate(
            tier: .managed,
            identifier: "managed-policy",
            scope: .managed,
            kind: .managed,
            rawTopLevel: [
                "allowManagedHooksOnly": .bool(true)
            ]
        )
        let user = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: [
                "hooks": .object([
                    "PostToolUse": .array([
                        .object(["type": .string("http"), "url": .string("https://hooks.example.com/post")])
                    ])
                ])
            ]
        )

        let selection = resolver.resolvePrecedence(candidates: [user, managed])
        let snapshot = resolver.buildSnapshot(from: selection)

        let projection = SessionProjectionBuilder().build(from: SessionProjectionBuilder.Input(settings: snapshot))
        let hooks: ResolvedHookSnapshot = projection.hooks!

        XCTAssertTrue(hooks.policyEffects.contains(where: { $0.reason == .allowManagedHooksOnly }))

        let event = hooks.events.first(where: { $0.eventID == "PostToolUse" })!
        XCTAssertNotNil(event.suppression)
        XCTAssertEqual(event.suppression?.reason, .allowManagedHooksOnly)
        XCTAssertTrue(
            hooks.issues.contains(where: {
                $0.code == .hookPolicySuppressed && $0.keyPath == "hooks.PostToolUse"
            })
        )
    }

    func testHookResolverDoesNotSuppressManagedHooksWhenAllowManagedHooksOnly() {
        let resolver = SettingsResolver()
        let managed = makeCandidate(
            tier: .managed,
            identifier: "managed-policy",
            scope: .managed,
            kind: .managed,
            rawTopLevel: [
                "allowManagedHooksOnly": .bool(true),
                "hooks": .object([
                    "SessionStart": .array([
                        .object(["type": .string("command"), "command": .string("echo start")])
                    ])
                ])
            ]
        )

        let selection = resolver.resolvePrecedence(candidates: [managed])
        let snapshot = resolver.buildSnapshot(from: selection)

        let projection = SessionProjectionBuilder().build(from: SessionProjectionBuilder.Input(settings: snapshot))
        let hooks: ResolvedHookSnapshot = projection.hooks!

        let event = hooks.events.first(where: { $0.eventID == "SessionStart" })!
        // Managed hooks should NOT be suppressed
        XCTAssertNil(event.suppression)
        XCTAssertEqual(event.resolvedHandlers.count, 1)
        XCTAssertEqual(event.resolvedHandlers.first?.handlerType, .command)
    }

    func testHookResolverDisableAllHooksSuppressesEvenManagedHooks() {
        let resolver = SettingsResolver()
        let managed = makeCandidate(
            tier: .managed,
            identifier: "managed-policy",
            scope: .managed,
            kind: .managed,
            rawTopLevel: [
                "disableAllHooks": .bool(true),
                "hooks": .object([
                    "SessionStart": .array([
                        .object(["type": .string("command"), "command": .string("echo start")])
                    ])
                ])
            ]
        )

        let selection = resolver.resolvePrecedence(candidates: [managed])
        let snapshot = resolver.buildSnapshot(from: selection)

        let projection = SessionProjectionBuilder().build(from: SessionProjectionBuilder.Input(settings: snapshot))
        let hooks: ResolvedHookSnapshot = projection.hooks!

        let event = hooks.events.first(where: { $0.eventID == "SessionStart" })!
        // disableAllHooks suppresses even managed hooks
        XCTAssertNotNil(event.suppression)
        XCTAssertEqual(event.suppression?.reason, .disableAllHooks)
    }

    func testHookResolverCurrentEventCatalogResolution() {
        let resolver = SettingsResolver()
        let knownEvents = [
            "SessionStart", "SessionEnd", "UserPromptSubmit", "PreToolUse", "PostToolUse",
            "PostToolUseFailure", "PermissionRequest", "Notification", "Stop", "StopFailure",
            "SubagentStart", "SubagentStop", "PreCompact", "PostCompact", "InstructionsLoaded",
            "ConfigChange", "WorktreeCreate", "WorktreeRemove", "Elicitation", "ElicitationResult",
            "CwdChanged", "FileChanged", "TaskCreated", "TaskCompleted", "TeammateIdle", "Setup"
        ]

        var hooksObject: [String: JSONValue] = [:]
        for event in knownEvents {
            hooksObject[event] = .array([
                .object(["type": .string("command"), "command": .string("echo \(event)")])
            ])
        }

        let candidate = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: ["hooks": .object(hooksObject)]
        )

        let selection = resolver.resolvePrecedence(candidates: [candidate])
        let snapshot = resolver.buildSnapshot(from: selection)

        let projection = SessionProjectionBuilder().build(from: SessionProjectionBuilder.Input(settings: snapshot))
        let hooks: ResolvedHookSnapshot = projection.hooks!

        XCTAssertEqual(hooks.events.count, knownEvents.count)
        for eventID in knownEvents {
            let event = hooks.events.first(where: { $0.eventID == eventID })
            XCTAssertNotNil(event, "Missing resolved event for \(eventID)")
            XCTAssertTrue(event?.eventType.isKnown ?? false, "\(eventID) should be a known event type")
            XCTAssertEqual(event?.resolvedHandlers.count, 1, "Each event should have one resolved handler")
            XCTAssertNil(event?.suppression, "\(eventID) should not be suppressed")
        }
    }

    func testHookResolverHandlerPropertiesAreParsed() {
        let resolver = SettingsResolver()
        let candidate = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: [
                "hooks": .object([
                    "PreToolUse": .array([
                        .object([
                            "type": .string("command"),
                            "command": .string("lint.sh"),
                            "timeout": .number(30),
                            "statusMessage": .string("Running lint..."),
                            "if": .string("tool == 'Bash'"),
                            "once": .bool(true),
                            "shell": .string("bash"),
                            "async": .bool(false)
                        ]),
                        .object([
                            "type": .string("http"),
                            "url": .string("https://hooks.example.com/log"),
                            "headers": .object(["Authorization": .string("Bearer $TOKEN")]),
                            "allowedEnvVars": .array([.string("TOKEN")])
                        ])
                    ])
                ])
            ]
        )

        let selection = resolver.resolvePrecedence(candidates: [candidate])
        let snapshot = resolver.buildSnapshot(from: selection)

        let projection = SessionProjectionBuilder().build(from: SessionProjectionBuilder.Input(settings: snapshot))
        let hooks: ResolvedHookSnapshot = projection.hooks!
        let event = hooks.events.first(where: { $0.eventID == "PreToolUse" })!

        let commandHandler = event.resolvedHandlers[0]
        XCTAssertEqual(commandHandler.handlerType, .command)
        XCTAssertEqual(commandHandler.command, "lint.sh")
        XCTAssertEqual(commandHandler.timeout, 30)
        XCTAssertEqual(commandHandler.statusMessage, "Running lint...")
        XCTAssertEqual(commandHandler.condition, "tool == 'Bash'")
        XCTAssertEqual(commandHandler.once, true)
        XCTAssertEqual(commandHandler.shell, "bash")
        XCTAssertEqual(commandHandler.isAsync, false)

        let httpHandler = event.resolvedHandlers[1]
        XCTAssertEqual(httpHandler.handlerType, .http)
        XCTAssertEqual(httpHandler.url, "https://hooks.example.com/log")
        XCTAssertEqual(httpHandler.headers, ["Authorization": "Bearer $TOKEN"])
        XCTAssertEqual(httpHandler.allowedEnvVars, ["TOKEN"])
    }

    func testHookResolverPolicyEffectsHaveProvenanceAttribution() {
        let resolver = SettingsResolver()
        let managed = makeCandidate(
            tier: .managed,
            identifier: "enterprise-policy",
            scope: .managed,
            kind: .managed,
            rawTopLevel: [
                "disableAllHooks": .bool(true),
                "allowManagedHooksOnly": .bool(true)
            ]
        )
        let user = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: [
                "hooks": .object([
                    "Stop": .array([.object(["type": .string("command"), "command": .string("echo stop")])])
                ])
            ]
        )

        let selection = resolver.resolvePrecedence(candidates: [user, managed])
        let snapshot = resolver.buildSnapshot(from: selection)

        let projection = SessionProjectionBuilder().build(from: SessionProjectionBuilder.Input(settings: snapshot))
        let hooks: ResolvedHookSnapshot = projection.hooks!

        // Both policies should be present
        XCTAssertEqual(hooks.policyEffects.count, 2)

        let disableEffect = hooks.policyEffects.first(where: { $0.reason == .disableAllHooks })!
        XCTAssertEqual(disableEffect.policySource?.identifier, "enterprise-policy")
        XCTAssertEqual(disableEffect.policySource?.scope, .managed)
        XCTAssertTrue(disableEffect.message.contains("disableAllHooks"))

        let managedOnlyEffect = hooks.policyEffects.first(where: { $0.reason == .allowManagedHooksOnly })!
        XCTAssertEqual(managedOnlyEffect.policySource?.identifier, "enterprise-policy")
        XCTAssertTrue(managedOnlyEffect.message.contains("allowManagedHooksOnly"))
    }

    func testHookResolverReturnsSnapshotForPolicyOnlyWithoutHooksKey() {
        let resolver = SettingsResolver()
        let managed = makeCandidate(
            tier: .managed,
            identifier: "managed-policy",
            scope: .managed,
            kind: .managed,
            rawTopLevel: [
                "disableAllHooks": .bool(true)
            ]
        )

        let selection = resolver.resolvePrecedence(candidates: [managed])
        let snapshot = resolver.buildSnapshot(from: selection)

        let projection = SessionProjectionBuilder().build(from: SessionProjectionBuilder.Input(settings: snapshot))

        // Should still produce a hook snapshot with policy effects but no events
        let hooks = projection.hooks!
        XCTAssertTrue(hooks.events.isEmpty)
        XCTAssertTrue(hooks.policyEffects.contains(where: { $0.reason == .disableAllHooks }))
        XCTAssertTrue(hooks.notes.contains(where: { $0.contains("disableAllHooks") }))
    }

    func testHookResolverObjectWithNestedHooksArrayFormat() {
        let resolver = SettingsResolver()
        let candidate = makeCandidate(
            tier: .user,
            identifier: "user-settings",
            scope: .user,
            sourcePath: "/tmp/.claude/settings.json",
            rawTopLevel: [
                "hooks": .object([
                    "PreToolUse": .object([
                        "matcher": .string("Bash"),
                        "hooks": .array([
                            .object(["type": .string("command"), "command": .string("sandbox-check")])
                        ])
                    ])
                ])
            ]
        )

        let selection = resolver.resolvePrecedence(candidates: [candidate])
        let snapshot = resolver.buildSnapshot(from: selection)

        let projection = SessionProjectionBuilder().build(from: SessionProjectionBuilder.Input(settings: snapshot))
        let hooks: ResolvedHookSnapshot = projection.hooks!

        let event = hooks.events.first(where: { $0.eventID == "PreToolUse" })!
        XCTAssertEqual(event.resolvedHandlers.count, 1)
        XCTAssertEqual(event.resolvedHandlers.first?.handlerType, .command)
        XCTAssertEqual(event.resolvedHandlers.first?.command, "sandbox-check")
    }

    private func makeSource(
        identifier: String,
        scope: ResolutionScope = .user,
        sourcePath: String?
    ) -> ResolutionSource {
        ResolutionSource(
            scope: scope,
            kind: .file,
            identifier: identifier,
            sourcePath: sourcePath,
            availability: .present
        )
    }

    private func makeCandidate(
        tier: SettingsSourceTier,
        identifier: String,
        scope: ResolutionScope,
        kind: ResolutionSourceKind = .file,
        sourcePath: String? = nil,
        rawTopLevel: [String: JSONValue]
    ) -> SettingsSourceCandidate {
        let source = ResolutionSource(
            scope: scope,
            kind: kind,
            identifier: identifier,
            sourcePath: sourcePath,
            availability: .present
        )

        return SettingsSourceCandidate(
            tier: tier,
            source: source,
            document: makeSettingsDocument(sourcePath: sourcePath ?? "/tmp/\(identifier).json", rawTopLevel: rawTopLevel),
            issues: []
        )
    }

    private func makeResolvedAgentEntry(
        agentID: String,
        source: ResolutionSource,
        visibility: VisibilityState,
        participants: [ResolutionSource]? = nil,
        overridden: [ResolutionSource] = [],
        winner: ResolutionSource? = nil,
        issues: [ResolutionIssue] = [],
        includeDefinitionDocument: Bool = true
    ) -> ResolvedAgentEntry {
        let traceParticipants = participants ?? [source]
        let document = includeDefinitionDocument
            ? ParsedAgentDocument(
                source: SourceFileReference(url: URL(fileURLWithPath: source.sourcePath ?? "/tmp/\(agentID).md")),
                frontmatter: ParsedAgentFrontmatter(
                    name: agentID.capitalized,
                    description: "Agent \(agentID) description.",
                    tools: [ParsedAgentToolEntry(rawValue: "Read")],
                    unknownFields: [:]
                ),
                rawFrontmatter: nil,
                promptBody: "Prompt body."
            )
            : nil

        return ResolvedAgentEntry(
            agentID: agentID,
            source: source,
            definition: ResolvedValue(
                effectiveValue: document,
                winningSource: includeDefinitionDocument ? source : nil,
                trace: ResolutionTrace(participants: traceParticipants, overridden: overridden),
                mergeMethod: .selectHighestPrecedence,
                issues: issues
            ),
            visibility: ResolvedValue(
                effectiveValue: visibility,
                winningSource: winner,
                trace: ResolutionTrace(participants: traceParticipants, overridden: overridden),
                mergeMethod: .selectHighestPrecedence,
                issues: issues
            ),
            isVisible: ResolvedValue(
                effectiveValue: visibility == .effective,
                winningSource: winner,
                trace: ResolutionTrace(participants: traceParticipants, overridden: overridden),
                mergeMethod: .selectHighestPrecedence,
                issues: issues
            )
        )
    }

    private func makeResolvedSkillEntry(
        skillID: String,
        source: ResolutionSource,
        visibility: VisibilityState,
        participants: [ResolutionSource]? = nil,
        overridden: [ResolutionSource] = [],
        winner: ResolutionSource? = nil,
        issues: [ResolutionIssue] = [],
        includeDefinitionDocument: Bool = true
    ) -> ResolvedSkillEntry {
        let traceParticipants = participants ?? [source]
        let document = includeDefinitionDocument
            ? ParsedSkillDocument(
                directory: SkillDirectoryMetadata(
                    skillRootURL: URL(fileURLWithPath: "/tmp/skills/\(skillID)"),
                    skillMarkdownURL: URL(fileURLWithPath: source.sourcePath ?? "/tmp/skills/\(skillID)/SKILL.md"),
                    hasSkillMarkdown: true
                ),
                frontmatter: ParsedSkillFrontmatter(
                    name: skillID.capitalized,
                    description: "Skill \(skillID) description.",
                    version: "1.0.0",
                    tags: ["tag"],
                    unknownFields: [:]
                ),
                rawFrontmatter: nil,
                body: "Skill body.",
                supportingReferences: []
            )
            : nil

        return ResolvedSkillEntry(
            skillID: skillID,
            source: source,
            definition: ResolvedValue(
                effectiveValue: document,
                winningSource: includeDefinitionDocument ? source : nil,
                trace: ResolutionTrace(participants: traceParticipants, overridden: overridden),
                mergeMethod: .selectHighestPrecedence,
                issues: issues
            ),
            visibility: ResolvedValue(
                effectiveValue: visibility,
                winningSource: winner,
                trace: ResolutionTrace(participants: traceParticipants, overridden: overridden),
                mergeMethod: .selectHighestPrecedence,
                issues: issues
            ),
            isVisible: ResolvedValue(
                effectiveValue: visibility == .effective,
                winningSource: winner,
                trace: ResolutionTrace(participants: traceParticipants, overridden: overridden),
                mergeMethod: .selectHighestPrecedence,
                issues: issues
            )
        )
    }

    private func makeSettingsDocument(sourcePath: String, rawTopLevel: [String: JSONValue]) -> ParsedSettingsDocument {
        ParsedSettingsDocument(
            source: SourceFileReference(url: URL(fileURLWithPath: sourcePath)),
            value: SettingsDocumentValue(
                schema: nil,
                apiKeyHelper: nil,
                autoMemoryDirectory: nil,
                cleanupPeriodDays: nil,
                companyAnnouncements: nil,
                env: nil,
                attribution: nil,
                includeCoAuthoredBy: nil,
                includeGitInstructions: nil,
                permissions: nil,
                autoMode: nil,
                disableAutoMode: nil,
                useAutoModeDuringPlan: nil,
                disableDeepLinkRegistration: nil,
                hooks: nil,
                disableAllHooks: nil,
                allowManagedHooksOnly: nil,
                allowedHTTPHookURLs: nil,
                httpHookAllowedEnvVars: nil,
                pluginSettings: [:]
            ),
            rawTopLevelObject: rawTopLevel,
            unsupportedTopLevelKeys: [:]
        )
    }

    private func tryUnwrapEntry(snapshot: ResolvedSettingsSnapshot, keyPath: String) -> ResolvedSettingsEntry {
        guard let entry = snapshot.entries.first(where: { $0.keyPath == keyPath }) else {
            XCTFail("Missing settings entry for keyPath '\(keyPath)'")
            fatalError("Missing entry")
        }
        return entry
    }

    private func tryUnwrapRow(viewModel: SessionSettingsViewModel, keyPath: String) -> ResolvedSettingRowModel {
        guard let row = viewModel.sections.flatMap(\.rows).first(where: { $0.keyPath == keyPath }) else {
            XCTFail("Missing session settings row for keyPath '\(keyPath)'")
            fatalError("Missing row")
        }
        return row
    }

    private func tryUnwrapHookGroup(viewModel: SessionHooksViewModel, eventID: String) -> HookGroupModel {
        guard let group = viewModel.groups.first(where: { $0.eventID == eventID }) else {
            XCTFail("Missing session hooks group for eventID '\(eventID)'")
            fatalError("Missing hook group")
        }
        return group
    }

    private func makeInstructionCandidate(
        scope: ResolutionScope,
        identifier: String,
        path: String,
        parser: ClaudeMdParser,
        markdown: String,
        availability: ResolutionAvailability = .present
    ) -> InstructionDocumentCandidate {
        let source = ResolutionSource(
            scope: scope,
            kind: scope == .imported ? .imported : .file,
            identifier: identifier,
            sourcePath: path,
            availability: availability
        )
        let parsed = parser.parse(markdown: markdown, sourceURL: URL(fileURLWithPath: path))
        let resolutionIssues = parsed.issues.map { ResolutionIssue(syntaxIssue: $0, source: source) }
        return InstructionDocumentCandidate(
            source: source,
            document: parsed.value,
            issues: resolutionIssues
        )
    }

    private func makeMcpDocument(
        tier: McpSourceTier,
        scope: ResolutionScope,
        identifier: String,
        sourcePath: String,
        availability: ResolutionAvailability = .present,
        servers: [McpDocumentServerEntry]
    ) -> McpDocumentCandidate {
        let source = ResolutionSource(
            scope: scope,
            kind: scope == .managed ? .managed : .file,
            identifier: identifier,
            sourcePath: sourcePath,
            availability: availability
        )
        return McpDocumentCandidate(
            tier: tier,
            source: source,
            servers: servers
        )
    }

    private func makeMcpServer(
        serverID: String,
        parseOrder: Int,
        config: [String: JSONValue]
    ) -> McpDocumentServerEntry {
        McpDocumentServerEntry(
            serverID: serverID,
            rawConfig: .object(config),
            parseOrder: parseOrder
        )
    }

    private func makeMcpServer(
        serverID: String,
        parseOrder: Int,
        config rawConfig: JSONValue
    ) -> McpDocumentServerEntry {
        McpDocumentServerEntry(
            serverID: serverID,
            rawConfig: rawConfig,
            parseOrder: parseOrder
        )
    }

    private func tryUnwrapMcpEntry(snapshot: ResolvedMcpSnapshot, serverID: String) -> ResolvedMcpServerEntry {
        guard let entry = snapshot.servers.first(where: { $0.serverID == serverID }) else {
            XCTFail("Missing MCP entry for server id '\(serverID)'")
            fatalError("Missing MCP entry")
        }
        return entry
    }

    private func makeAgentCandidate(
        tier: AgentSourceTier,
        identifier: String,
        scope: ResolutionScope,
        sourcePath: String,
        parser: AgentParser,
        markdown: String,
        availability: ResolutionAvailability = .present
    ) -> AgentDocumentCandidate {
        let source = ResolutionSource(
            scope: scope,
            kind: .file,
            identifier: identifier,
            sourcePath: sourcePath,
            availability: availability
        )
        let parsed = parser.parse(markdownString: markdown, sourceURL: URL(fileURLWithPath: sourcePath))
        let issues = parsed.issues.map { ResolutionIssue(syntaxIssue: $0, source: source) }
        return AgentDocumentCandidate(
            tier: tier,
            source: source,
            document: parsed.value,
            issues: issues
        )
    }

    private func makeSkillCandidate(
        tier: SkillSourceTier,
        identifier: String,
        scope: ResolutionScope,
        directoryPath: String,
        parser: SkillParser,
        markdown: String,
        availability: ResolutionAvailability = .present
    ) -> SkillDocumentCandidate {
        let source = ResolutionSource(
            scope: scope,
            kind: .file,
            identifier: identifier,
            sourcePath: directoryPath,
            availability: availability
        )
        let parsed = parser.parse(
            skillDirectoryURL: URL(fileURLWithPath: directoryPath),
            markdownString: markdown
        )
        let issues = parsed.issues.map { ResolutionIssue(syntaxIssue: $0, source: source) }
        return SkillDocumentCandidate(
            tier: tier,
            source: source,
            document: parsed.value,
            issues: issues
        )
    }

    private func fixtureInputPath(
        loader: FixtureLoader,
        familyPath: String,
        caseID: FixtureCaseID,
        fileName: String
    ) throws -> String {
        try loader.descriptor(familyPath: familyPath, caseID: caseID)
            .inputFileURL(named: fileName)
            .path
    }

    private func loadExpectedJSON<T: Decodable>(
        loader: FixtureLoader,
        familyPath: String,
        caseID: FixtureCaseID,
        fileName: String,
        as type: T.Type
    ) throws -> T {
        let raw = try loader.loadString(
            familyPath: familyPath,
            caseID: caseID,
            section: "expected",
            fileName: fileName
        )
        return try JSONDecoder().decode(type, from: Data(raw.utf8))
    }

    private func makeMcpFixtureDocument(
        loader: FixtureLoader,
        caseID: FixtureCaseID,
        fileName: String,
        tier: McpSourceTier,
        scope: ResolutionScope,
        identifier: String
    ) throws -> McpDocumentCandidate {
        let content = try loader.loadString(
            familyPath: "resolvers/mcp",
            caseID: caseID,
            section: "input",
            fileName: fileName
        )
        let data = Data(content.utf8)
        let any = try JSONSerialization.jsonObject(with: data, options: [])
        guard let object = any as? [String: Any] else {
            XCTFail("Expected top-level object in MCP fixture \(fileName)")
            return makeMcpDocument(
                tier: tier,
                scope: scope,
                identifier: identifier,
                sourcePath: "/tmp/\(fileName)",
                servers: []
            )
        }

        let servers = object.keys.sorted().enumerated().map { index, key in
            McpDocumentServerEntry(
                serverID: key,
                rawConfig: JSONValue.from(any: object[key] as Any),
                parseOrder: index
            )
        }

        return makeMcpDocument(
            tier: tier,
            scope: scope,
            identifier: identifier,
            sourcePath: "/tmp/\(fileName)",
            servers: servers
        )
    }

    // MARK: - E4 Schema Validation: Expanded Coverage Tests

    func testSchemaValidatorSettingsDetectsEnumValues() {
        let validator = SchemaValidator()
        let document = ParsedSettingsDocument(
            source: SourceFileReference(url: URL(fileURLWithPath: "/tmp/.claude/settings.json")),
            value: SettingsDocumentValue(
                schema: nil,
                apiKeyHelper: nil,
                autoMemoryDirectory: nil,
                cleanupPeriodDays: nil,
                companyAnnouncements: nil,
                effortLevel: "extreme",
                env: nil,
                attribution: nil,
                includeCoAuthoredBy: nil,
                includeGitInstructions: nil,
                permissions: ParsedPermissions(
                    allow: nil,
                    deny: nil,
                    defaultMode: "superAuto",
                    rawObject: [:]
                ),
                autoMode: nil,
                disableAutoMode: nil,
                useAutoModeDuringPlan: nil,
                disableDeepLinkRegistration: nil,
                hooks: nil,
                disableAllHooks: nil,
                allowManagedHooksOnly: nil,
                allowedHTTPHookURLs: nil,
                httpHookAllowedEnvVars: nil,
                pluginSettings: [:]
            ),
            rawTopLevelObject: [:],
            unsupportedTopLevelKeys: [:]
        )

        let result = validator.validate(settings: document)
        let enumCodes = result.issues.filter { $0.code.rawValue == "schema.settings.unknownEnumValue" }
        XCTAssertEqual(enumCodes.count, 2, "Should produce info issues for unknown effortLevel and permissions.defaultMode")
        XCTAssertTrue(enumCodes.allSatisfy { $0.severity == .info }, "Unknown enum values should be info severity for forward compatibility")
        XCTAssertTrue(enumCodes.contains(where: { $0.keyPath == "effortLevel" }))
        XCTAssertTrue(enumCodes.contains(where: { $0.keyPath == "permissions.defaultMode" }))
    }

    func testSchemaValidatorSettingsValidEnumValuesProduceNoIssues() {
        let validator = SchemaValidator()
        let document = ParsedSettingsDocument(
            source: SourceFileReference(url: URL(fileURLWithPath: "/tmp/.claude/settings.json")),
            value: SettingsDocumentValue(
                schema: nil,
                apiKeyHelper: nil,
                autoMemoryDirectory: nil,
                cleanupPeriodDays: nil,
                companyAnnouncements: nil,
                effortLevel: "high",
                env: nil,
                attribution: nil,
                includeCoAuthoredBy: nil,
                includeGitInstructions: nil,
                permissions: ParsedPermissions(
                    allow: nil,
                    deny: nil,
                    defaultMode: "auto",
                    rawObject: [:]
                ),
                autoMode: nil,
                disableAutoMode: nil,
                useAutoModeDuringPlan: nil,
                disableDeepLinkRegistration: nil,
                hooks: nil,
                disableAllHooks: nil,
                allowManagedHooksOnly: nil,
                allowedHTTPHookURLs: nil,
                httpHookAllowedEnvVars: nil,
                pluginSettings: [:]
            ),
            rawTopLevelObject: [:],
            unsupportedTopLevelKeys: [:]
        )

        let result = validator.validate(settings: document)
        XCTAssertTrue(result.issues.isEmpty, "Valid enum values should produce no issues, got: \(result.issues.map { $0.code.rawValue })")
    }

    func testSchemaValidatorSettingsDetectsNumberRanges() {
        let validator = SchemaValidator()
        let document = ParsedSettingsDocument(
            source: SourceFileReference(url: URL(fileURLWithPath: "/tmp/.claude/settings.json")),
            value: SettingsDocumentValue(
                schema: nil,
                apiKeyHelper: nil,
                autoMemoryDirectory: nil,
                cleanupPeriodDays: -5,
                companyAnnouncements: nil,
                feedbackSurveyRate: 2.5,
                env: nil,
                attribution: nil,
                includeCoAuthoredBy: nil,
                includeGitInstructions: nil,
                permissions: nil,
                autoMode: nil,
                disableAutoMode: nil,
                useAutoModeDuringPlan: nil,
                disableDeepLinkRegistration: nil,
                hooks: nil,
                disableAllHooks: nil,
                allowManagedHooksOnly: nil,
                allowedHTTPHookURLs: nil,
                httpHookAllowedEnvVars: nil,
                sandbox: ParsedSandboxConfig(
                    enabled: true,
                    failIfUnavailable: nil,
                    autoAllowBashIfSandboxed: nil,
                    excludedCommands: nil,
                    allowUnsandboxedCommands: nil,
                    enableWeakerNestedSandbox: nil,
                    enableWeakerNetworkIsolation: nil,
                    filesystem: nil,
                    network: ParsedSandboxNetwork(
                        allowUnixSockets: nil,
                        allowAllUnixSockets: nil,
                        allowLocalBinding: nil,
                        allowedDomains: nil,
                        allowManagedDomainsOnly: nil,
                        httpProxyPort: 99999,
                        socksProxyPort: 0,
                        unknownFields: nil
                    ),
                    unknownFields: nil
                ),
                pluginSettings: [:]
            ),
            rawTopLevelObject: [:],
            unsupportedTopLevelKeys: [:]
        )

        let result = validator.validate(settings: document)
        let rangeCodes = result.issues.filter { $0.code.rawValue == "schema.settings.numberOutOfRange" }
        XCTAssertEqual(rangeCodes.count, 4, "Should detect out-of-range for feedbackSurveyRate, cleanupPeriodDays, httpProxyPort, socksProxyPort")
        XCTAssertTrue(rangeCodes.contains(where: { $0.keyPath == "feedbackSurveyRate" }))
        XCTAssertTrue(rangeCodes.contains(where: { $0.keyPath == "cleanupPeriodDays" }))
        XCTAssertTrue(rangeCodes.contains(where: { $0.keyPath == "sandbox.network.httpProxyPort" }))
        XCTAssertTrue(rangeCodes.contains(where: { $0.keyPath == "sandbox.network.socksProxyPort" }))
    }

    func testSchemaValidatorSettingsDetectsSandboxFilesystemOverlaps() {
        let validator = SchemaValidator()
        let document = ParsedSettingsDocument(
            source: SourceFileReference(url: URL(fileURLWithPath: "/tmp/.claude/settings.json")),
            value: SettingsDocumentValue(
                schema: nil,
                apiKeyHelper: nil,
                autoMemoryDirectory: nil,
                cleanupPeriodDays: nil,
                companyAnnouncements: nil,
                env: nil,
                attribution: nil,
                includeCoAuthoredBy: nil,
                includeGitInstructions: nil,
                permissions: nil,
                autoMode: nil,
                disableAutoMode: nil,
                useAutoModeDuringPlan: nil,
                disableDeepLinkRegistration: nil,
                hooks: nil,
                disableAllHooks: nil,
                allowManagedHooksOnly: nil,
                allowedHTTPHookURLs: nil,
                httpHookAllowedEnvVars: nil,
                sandbox: ParsedSandboxConfig(
                    enabled: true,
                    failIfUnavailable: nil,
                    autoAllowBashIfSandboxed: nil,
                    excludedCommands: nil,
                    allowUnsandboxedCommands: nil,
                    enableWeakerNestedSandbox: nil,
                    enableWeakerNetworkIsolation: nil,
                    filesystem: ParsedSandboxFilesystem(
                        allowWrite: ["/tmp", "/var"],
                        denyWrite: ["/var"],
                        denyRead: ["/etc"],
                        allowRead: ["/etc"],
                        allowManagedReadPathsOnly: nil,
                        unknownFields: nil
                    ),
                    network: nil,
                    unknownFields: nil
                ),
                pluginSettings: [:]
            ),
            rawTopLevelObject: [:],
            unsupportedTopLevelKeys: [:]
        )

        let result = validator.validate(settings: document)
        let overlapCodes = result.issues.filter { $0.code.rawValue == "schema.settings.sandboxFilesystemOverlap" }
        XCTAssertEqual(overlapCodes.count, 2, "Should detect write and read overlaps")
    }

    func testSchemaValidatorSettingsDetectsMcpRestrictionRuleShapes() {
        let validator = SchemaValidator()
        let document = ParsedSettingsDocument(
            source: SourceFileReference(url: URL(fileURLWithPath: "/tmp/.claude/settings.json")),
            value: SettingsDocumentValue(
                schema: nil,
                apiKeyHelper: nil,
                autoMemoryDirectory: nil,
                cleanupPeriodDays: nil,
                companyAnnouncements: nil,
                env: nil,
                attribution: nil,
                includeCoAuthoredBy: nil,
                includeGitInstructions: nil,
                permissions: nil,
                autoMode: nil,
                disableAutoMode: nil,
                useAutoModeDuringPlan: nil,
                disableDeepLinkRegistration: nil,
                hooks: nil,
                disableAllHooks: nil,
                allowManagedHooksOnly: nil,
                allowedHTTPHookURLs: nil,
                httpHookAllowedEnvVars: nil,
                allowedMcpServers: [
                    McpRestrictionRule(serverName: nil, serverCommand: nil, serverUrl: nil, unknownFields: nil),
                    McpRestrictionRule(serverName: "github", serverCommand: ["npx"], serverUrl: nil, unknownFields: nil),
                    McpRestrictionRule(serverName: nil, serverCommand: [], serverUrl: nil, unknownFields: nil)
                ],
                deniedMcpServers: [
                    McpRestrictionRule(serverName: "valid", serverCommand: nil, serverUrl: nil, unknownFields: nil)
                ],
                pluginSettings: [:]
            ),
            rawTopLevelObject: [:],
            unsupportedTopLevelKeys: [:]
        )

        let result = validator.validate(settings: document)
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.settings.mcpRestrictionRuleMissingDiscriminator" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.settings.mcpRestrictionRuleAmbiguous" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.settings.mcpRestrictionRuleEmptyCommand" }))
        // Valid rule in deniedMcpServers should produce no issues for that entry
        let deniedIssues = result.issues.filter { $0.keyPath?.hasPrefix("deniedMcpServers") == true }
        XCTAssertTrue(deniedIssues.isEmpty, "Valid restriction rule should produce no issues")
    }

    func testSchemaValidatorSettingsDetectsMarketplaceSourceShapes() {
        let validator = SchemaValidator()
        let document = ParsedSettingsDocument(
            source: SourceFileReference(url: URL(fileURLWithPath: "/tmp/.claude/settings.json")),
            value: SettingsDocumentValue(
                schema: nil,
                apiKeyHelper: nil,
                autoMemoryDirectory: nil,
                cleanupPeriodDays: nil,
                companyAnnouncements: nil,
                env: nil,
                attribution: nil,
                includeCoAuthoredBy: nil,
                includeGitInstructions: nil,
                permissions: nil,
                autoMode: nil,
                disableAutoMode: nil,
                useAutoModeDuringPlan: nil,
                disableDeepLinkRegistration: nil,
                hooks: nil,
                disableAllHooks: nil,
                allowManagedHooksOnly: nil,
                allowedHTTPHookURLs: nil,
                httpHookAllowedEnvVars: nil,
                strictKnownMarketplaces: [
                    ParsedPluginMarketplace(id: "mp1", source: nil, unknownFields: nil),
                    ParsedPluginMarketplace(
                        id: "mp2",
                        source: .github(ParsedGitHubMarketplaceSource(repo: nil, ref: nil, subpath: nil, unknownFields: nil)),
                        unknownFields: nil
                    )
                ],
                blockedMarketplaces: [
                    ParsedPluginMarketplace(
                        id: "mp3",
                        source: .npm(ParsedNpmMarketplaceSource(package: nil, version: nil, registry: nil, unknownFields: nil)),
                        unknownFields: nil
                    )
                ],
                pluginSettings: [:]
            ),
            rawTopLevelObject: [:],
            unsupportedTopLevelKeys: [:]
        )

        let result = validator.validate(settings: document)
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.settings.marketplaceMissingSource" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.settings.marketplaceSourceMissingField" && $0.keyPath?.contains("repo") == true }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.settings.marketplaceSourceMissingField" && $0.keyPath?.contains("package") == true }))
    }

    func testSchemaValidatorSettingsDetectsHookPropertyCompatibility() {
        let validator = SchemaValidator()
        let document = ParsedSettingsDocument(
            source: SourceFileReference(url: URL(fileURLWithPath: "/tmp/.claude/settings.json")),
            value: SettingsDocumentValue(
                schema: nil,
                apiKeyHelper: nil,
                autoMemoryDirectory: nil,
                cleanupPeriodDays: nil,
                companyAnnouncements: nil,
                env: nil,
                attribution: nil,
                includeCoAuthoredBy: nil,
                includeGitInstructions: nil,
                permissions: nil,
                autoMode: nil,
                disableAutoMode: nil,
                useAutoModeDuringPlan: nil,
                disableDeepLinkRegistration: nil,
                hooks: ParsedHooks(
                    events: [
                        "Stop": ParsedHookEvent(
                            eventName: "Stop",
                            eventType: .stop,
                            matcher: nil,
                            actions: [
                                // prompt type missing template value
                                ParsedHookAction(
                                    type: "prompt",
                                    handlerType: .prompt,
                                    command: nil,
                                    url: nil,
                                    method: nil,
                                    body: nil,
                                    template: nil,
                                    agentId: nil,
                                    inputs: nil,
                                    prompt: nil,
                                    timeout: nil,
                                    statusMessage: nil,
                                    condition: nil,
                                    once: nil,
                                    shell: nil,
                                    isAsync: nil,
                                    headers: nil,
                                    allowedEnvVars: nil,
                                    model: nil,
                                    rawObject: [:]
                                ),
                                // http type with shell property (incompatible)
                                ParsedHookAction(
                                    type: "http",
                                    handlerType: .http,
                                    command: nil,
                                    url: "https://example.com/hook",
                                    method: nil,
                                    body: nil,
                                    template: nil,
                                    agentId: nil,
                                    inputs: nil,
                                    prompt: nil,
                                    timeout: nil,
                                    statusMessage: nil,
                                    condition: nil,
                                    once: nil,
                                    shell: "bash",
                                    isAsync: true,
                                    headers: nil,
                                    allowedEnvVars: nil,
                                    model: "claude-3",
                                    rawObject: [:]
                                ),
                                // command type with unknown shell enum
                                ParsedHookAction(
                                    type: "command",
                                    handlerType: .command,
                                    command: "echo hello",
                                    url: nil,
                                    method: nil,
                                    body: nil,
                                    template: nil,
                                    agentId: nil,
                                    inputs: nil,
                                    prompt: nil,
                                    timeout: 5000,
                                    statusMessage: nil,
                                    condition: nil,
                                    once: nil,
                                    shell: "zsh",
                                    isAsync: nil,
                                    headers: nil,
                                    allowedEnvVars: nil,
                                    model: nil,
                                    rawObject: [:]
                                )
                            ],
                            rawValue: .array([])
                        )
                    ],
                    rawObject: [:]
                ),
                disableAllHooks: nil,
                allowManagedHooksOnly: nil,
                allowedHTTPHookURLs: nil,
                httpHookAllowedEnvVars: nil,
                pluginSettings: [:]
            ),
            rawTopLevelObject: [:],
            unsupportedTopLevelKeys: [:]
        )

        let result = validator.validate(settings: document)
        // prompt type missing prompt
        XCTAssertTrue(result.issues.contains(where: {
            $0.code.rawValue == "schema.settings.hookActionTypeMismatch" && $0.message.contains("prompt")
        }))
        // shell on http handler
        XCTAssertTrue(result.issues.contains(where: {
            $0.code.rawValue == "schema.settings.hookPropertyIncompatible" && $0.keyPath?.contains("shell") == true
        }))
        // async on http handler
        XCTAssertTrue(result.issues.contains(where: {
            $0.code.rawValue == "schema.settings.hookPropertyIncompatible" && $0.keyPath?.contains("async") == true
        }))
        // model on http handler
        XCTAssertTrue(result.issues.contains(where: {
            $0.code.rawValue == "schema.settings.hookPropertyIncompatible" && $0.keyPath?.contains("model") == true
        }))
        // unknown shell enum
        XCTAssertTrue(result.issues.contains(where: {
            $0.code.rawValue == "schema.settings.unknownEnumValue" && $0.keyPath?.contains("shell") == true
        }))
        // timeout warning for exceeding max
        XCTAssertTrue(result.issues.contains(where: {
            $0.code.rawValue == "schema.settings.numberOutOfRange" && $0.keyPath?.contains("timeout") == true
        }))
    }

    func testSchemaValidatorSettingsValidDocumentProducesNoFalsePositives() {
        let validator = SchemaValidator()
        let document = ParsedSettingsDocument(
            source: SourceFileReference(url: URL(fileURLWithPath: "/tmp/.claude/settings.json")),
            value: SettingsDocumentValue(
                schema: nil,
                apiKeyHelper: "/usr/local/bin/api-helper",
                autoMemoryDirectory: nil,
                cleanupPeriodDays: 30,
                companyAnnouncements: nil,
                effortLevel: "medium",
                feedbackSurveyRate: 0.5,
                env: nil,
                attribution: ParsedAttribution(commit: "Co-authored", pr: nil, unknownFields: nil),
                includeCoAuthoredBy: true,
                includeGitInstructions: nil,
                permissions: ParsedPermissions(
                    allow: ["Read"],
                    deny: ["Bash"],
                    defaultMode: nil,
                    rawObject: [:]
                ),
                autoMode: true,
                disableAutoMode: nil,
                useAutoModeDuringPlan: nil,
                disableDeepLinkRegistration: nil,
                hooks: ParsedHooks(
                    events: [
                        "PreToolUse": ParsedHookEvent(
                            eventName: "PreToolUse",
                            eventType: .preToolUse,
                            matcher: nil,
                            actions: [
                                ParsedHookAction(
                                    type: "command",
                                    handlerType: .command,
                                    command: "echo lint",
                                    url: nil,
                                    method: nil,
                                    body: nil,
                                    template: nil,
                                    agentId: nil,
                                    inputs: nil,
                                    prompt: nil,
                                    timeout: 30,
                                    statusMessage: nil,
                                    condition: nil,
                                    once: nil,
                                    shell: "bash",
                                    isAsync: nil,
                                    headers: nil,
                                    allowedEnvVars: nil,
                                    model: nil,
                                    rawObject: [:]
                                )
                            ],
                            rawValue: .array([])
                        )
                    ],
                    rawObject: [:]
                ),
                disableAllHooks: nil,
                allowManagedHooksOnly: nil,
                allowedHTTPHookURLs: nil,
                httpHookAllowedEnvVars: nil,
                allowedMcpServers: [
                    McpRestrictionRule(serverName: "github", serverCommand: nil, serverUrl: nil, unknownFields: nil)
                ],
                sandbox: ParsedSandboxConfig(
                    enabled: true,
                    failIfUnavailable: nil,
                    autoAllowBashIfSandboxed: nil,
                    excludedCommands: nil,
                    allowUnsandboxedCommands: nil,
                    enableWeakerNestedSandbox: nil,
                    enableWeakerNetworkIsolation: nil,
                    filesystem: ParsedSandboxFilesystem(
                        allowWrite: ["/tmp"],
                        denyWrite: ["/var"],
                        denyRead: nil,
                        allowRead: nil,
                        allowManagedReadPathsOnly: nil,
                        unknownFields: nil
                    ),
                    network: ParsedSandboxNetwork(
                        allowUnixSockets: nil,
                        allowAllUnixSockets: nil,
                        allowLocalBinding: nil,
                        allowedDomains: ["example.com"],
                        allowManagedDomainsOnly: nil,
                        httpProxyPort: 8080,
                        socksProxyPort: 1080,
                        unknownFields: nil
                    ),
                    unknownFields: nil
                ),
                pluginSettings: [:]
            ),
            rawTopLevelObject: [:],
            unsupportedTopLevelKeys: [:]
        )

        let result = validator.validate(settings: document)
        XCTAssertTrue(result.issues.isEmpty, "Valid settings document should produce no issues, got: \(result.issues.map { "\($0.code.rawValue) at \($0.keyPath ?? "root")" })")
    }
}

private struct ExpectedInstructionFixtureSummary: Decodable {
    let orderedBlockCount: Int
    let orderedBlockSuffixes: [String]
    let rootLoadOrder: [String]
    let issueCodes: [String]
    let composedContains: [String]
}

private struct ExpectedMcpFixtureSummary: Decodable {
    let serverID: String
    let winningSource: String
    let participantSources: [String]
    let issueCodes: [String]
    let environmentClassifications: [String]
}

private struct ExpectedAgentSkillFixtureSummary: Decodable {
    let agentStatesBySource: [String: String]
    let skillStatesBySource: [String: String]
    let requiredAgentIssueCodes: [String]
    let requiredSkillIssueCodes: [String]
}

private struct ExpectedProjectionFixtureSummary: Decodable {
    let isComplete: Bool
    let missingFamilies: [String]
    let availableFamilies: [String]
}

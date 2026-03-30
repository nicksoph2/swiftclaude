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
                "preToolUse": .array([
                    .object(["type": .string("command"), "command": .string("echo shared")]),
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
                attribution: ParsedAttribution(
                    includeCoAuthoredBy: false,
                    rawObject: ["includeCoAuthoredBy": .bool(false)]
                ),
                includeCoAuthoredBy: true,
                includeGitInstructions: nil,
                permissions: ParsedPermissions(
                    allow: ["Read", "Write"],
                    deny: ["Write"],
                    mode: "acceptEdits",
                    rawObject: [:]
                ),
                autoMode: true,
                disableAutoMode: true,
                useAutoModeDuringPlan: nil,
                disableDeepLinkRegistration: nil,
                hooks: ParsedHooks(
                    events: [
                        "PreToolUse": ParsedHookEvent(
                            matcher: nil,
                            actions: [
                                ParsedHookAction(
                                    type: "command",
                                    command: nil,
                                    url: nil,
                                    timeoutMs: -1,
                                    rawObject: [:]
                                )
                            ],
                            rawValue: .array([])
                        )
                    ],
                    rawObject: [:]
                ),
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
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.settings.attributionConflict" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.settings.permissionsModeWithAllowDeny" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.settings.permissionsAllowDenyOverlap" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.settings.hookActionTransportShape" }))
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
                            command: nil,
                            args: ["--stdio"],
                            env: nil,
                            url: nil,
                            headers: ["Authorization": "token"],
                            enabled: true,
                            source: nil,
                            rawObject: [:]
                        )
                    ],
                    localServers: [
                        "alpha": ParsedClaudeJsonMcpServerRef(
                            command: "run",
                            args: nil,
                            env: nil,
                            url: "http://localhost:8123",
                            headers: nil,
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
        XCTAssertTrue(result.issues.contains(where: { $0.code.rawValue == "schema.mcp.serverTransportShape" }))
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
                ResolvedSettingsEntry(
                    keyPath: "zeta.flag",
                    value: ResolvedValue(
                        effectiveValue: .bool(true),
                        winningSource: source,
                        trace: ResolutionTrace(participants: [source]),
                        mergeMethod: .replace
                    )
                ),
                ResolvedSettingsEntry(
                    keyPath: "alpha.b",
                    value: ResolvedValue(
                        effectiveValue: .number(2),
                        winningSource: source,
                        trace: ResolutionTrace(participants: [source]),
                        mergeMethod: .replace
                    )
                ),
                ResolvedSettingsEntry(
                    keyPath: "alpha.a",
                    value: ResolvedValue(
                        effectiveValue: .number(1),
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

        XCTAssertEqual(viewModel.sections.map(\.key), ["alpha", "zeta"])
        XCTAssertEqual(viewModel.sections.first?.rows.map(\.keyPath), ["alpha.a", "alpha.b"])
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
                                    .object(["type": .string("command"), "command": .string("echo ok"), "timeoutMs": .number(1200)])
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
        XCTAssertEqual(viewModel.groups.map(\.eventID), ["postToolUse", "preToolUse"])
        XCTAssertEqual(viewModel.groups[0].matcherLabel, "(none)")
        XCTAssertEqual(viewModel.groups[1].matcherLabel, "Bash")
        XCTAssertEqual(viewModel.groups[1].rows.first?.actionSummary, "command | command: echo ok | timeout=1200ms")
    }

    func testSessionHooksViewModelRendersRestrictionBadgesFromEffectiveSettings() {
        let source = makeSource(identifier: "project-local", scope: .projectLocal, sourcePath: "/tmp/project/.claude/settings.local.json")
        let settings = ResolvedSettingsSnapshot(
            entries: [
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

        XCTAssertEqual(viewModel.restrictionBadges.count, 2)
        XCTAssertEqual(viewModel.restrictionBadges.map(\.title), ["Managed Hooks Only", "HTTP URL Allowlist"])
        XCTAssertTrue(viewModel.restrictionBadges.contains(where: { $0.detail.contains("2 allowed URL patterns") }))
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
}

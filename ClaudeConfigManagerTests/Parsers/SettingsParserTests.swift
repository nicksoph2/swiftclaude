import XCTest
@testable import ClaudeConfigManager

final class SettingsParserTests: XCTestCase {
    private let parser = SettingsParser()
    private let sourceURL = URL(fileURLWithPath: "/tmp/settings.json", isDirectory: false)

    func testParseValidUserSettingsFixture() throws {
        let result = parser.parse(jsonString: SettingsParserFixtures.validUserSettings, sourceURL: sourceURL)

        XCTAssertFalse(result.hasErrors)
        let document = try XCTUnwrap(result.value)
        XCTAssertEqual(document.value.schema, "https://example.com/schema")
        XCTAssertEqual(document.value.apiKeyHelper, "security find-generic-password")
        XCTAssertEqual(document.value.cleanupPeriodDays, 30)
        XCTAssertEqual(document.value.companyAnnouncements ?? [], ["Welcome to Acme Corp!", "Remember to file your expenses."])
        XCTAssertEqual(document.value.env?.values["FOO"], "bar")
        XCTAssertEqual(document.value.includeGitInstructions, true)
        XCTAssertEqual(document.value.disableAllHooks, false)
        XCTAssertEqual(document.value.allowManagedHooksOnly, false)
        XCTAssertEqual(document.value.allowedHTTPHookURLs ?? [], ["https://hooks.example.com/a", "https://hooks.example.com/b"])
        XCTAssertEqual(document.value.httpHookAllowedEnvVars ?? [], ["PATH", "HOME"])
        XCTAssertEqual(document.unsupportedTopLevelKeys.count, 0)
    }

    func testParseValidProjectSettingsFixture() throws {
        let result = parser.parse(jsonString: SettingsParserFixtures.validProjectSettings, sourceURL: sourceURL)

        XCTAssertFalse(result.hasErrors)
        let document = try XCTUnwrap(result.value)
        XCTAssertEqual(document.value.autoMode, true)
        XCTAssertEqual(document.value.disableAutoMode, false)
        XCTAssertEqual(document.value.useAutoModeDuringPlan, true)
        XCTAssertEqual(document.value.permissions?.allow ?? [], ["Bash(git status)", "Read(./**)"])
        XCTAssertEqual(document.value.permissions?.deny ?? [], ["Bash(rm -rf /)"])
        XCTAssertEqual(document.value.permissions?.defaultMode, "default")
    }

    func testParseValidModelSettingsFixture() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "valid_model_settings",
            section: "input",
            fileName: "settings.json"
        )
        let expected = try loader.loadExpectedIssueSet(
            familyPath: "parsers/settings",
            caseID: "valid_model_settings",
            fileName: "parser_issues.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(expected.codes, [])
        XCTAssertEqual(document.value.model, "claude-sonnet-4-6")
        XCTAssertEqual(document.value.availableModels ?? [], ["sonnet", "haiku"])
        XCTAssertEqual(
            document.value.modelOverrides,
            ["claude-opus-4-6": "arn:aws:bedrock:us-east-1:123456789:inference-profile/opus"]
        )
        XCTAssertEqual(document.value.effortLevel, "medium")
        XCTAssertEqual(document.value.alwaysThinkingEnabled, true)
        XCTAssertEqual(document.value.fastMode, false)
        XCTAssertEqual(document.value.fastModePerSessionOptIn, true)
        XCTAssertEqual(try XCTUnwrap(document.value.feedbackSurveyRate), 0.05, accuracy: 0.000_001)
        XCTAssertEqual(document.value.agent, "code-reviewer")
        XCTAssertEqual(document.value.rawValue(for: "agent"), .string("code-reviewer"))
    }

    func testParseInvalidModelSettingsFixtureReportsWarningsAndPreservesAutoModeBehavior() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "invalid_model_settings",
            section: "input",
            fileName: "settings.json"
        )
        let expected = try loader.loadExpectedIssueSet(
            familyPath: "parsers/settings",
            caseID: "invalid_model_settings",
            fileName: "parser_issues.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)
        let codes = Set(result.issues.map(\.code.rawValue))

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(codes, Set(expected.codes))
        XCTAssertNil(document.value.effortLevel)
        XCTAssertNil(document.value.feedbackSurveyRate)
        XCTAssertEqual(document.value.modelOverrides, [:])
        XCTAssertEqual(document.value.rawValue(for: "effortLevel"), .string("turbo"))
        XCTAssertEqual(document.value.rawValue(for: "feedbackSurveyRate"), .number(1.5))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .preservedUnknownValue &&
            $0.severity == .warning &&
            $0.keyPath == "effortLevel"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .preservedUnknownValue &&
            $0.severity == .warning &&
            $0.keyPath == "feedbackSurveyRate"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .typeMismatch &&
            $0.severity == .warning &&
            $0.keyPath == "modelOverrides.claude-opus-4-6"
        }))

        let autoModeResult = parser.parse(jsonString: SettingsParserFixtures.validProjectSettings, sourceURL: sourceURL)
        let autoModeDocument = try XCTUnwrap(autoModeResult.value)
        XCTAssertEqual(autoModeDocument.value.autoMode, true)
        XCTAssertEqual(autoModeDocument.value.disableAutoMode, false)
        XCTAssertEqual(autoModeDocument.value.useAutoModeDuringPlan, true)
    }

    func testFeedbackSurveyRateRangeValidationAcceptsBoundaryValues() {
        for value in ["0", "0.5", "1.0"] {
            let result = parser.parse(
                jsonString: """
                {
                  "feedbackSurveyRate": \(value)
                }
                """,
                sourceURL: sourceURL
            )

            XCTAssertEqual(result.value?.value.feedbackSurveyRate, Double(value))
            XCTAssertFalse(result.issues.contains(where: { $0.keyPath == "feedbackSurveyRate" }))
        }
    }

    func testFeedbackSurveyRateRangeValidationRejectsOutOfBoundsValues() {
        for value in ["1.5", "-0.1"] {
            let result = parser.parse(
                jsonString: """
                {
                  "feedbackSurveyRate": \(value)
                }
                """,
                sourceURL: sourceURL
            )

            XCTAssertNil(result.value?.value.feedbackSurveyRate)
            XCTAssertTrue(result.issues.contains(where: {
                $0.code == .preservedUnknownValue &&
                $0.severity == .warning &&
                $0.keyPath == "feedbackSurveyRate"
            }))
        }
    }

    func testParseValidLocalProjectOverridesFixture() throws {
        let result = parser.parse(jsonString: SettingsParserFixtures.validLocalProjectOverrides, sourceURL: sourceURL)

        XCTAssertFalse(result.hasErrors)
        let document = try XCTUnwrap(result.value)
        XCTAssertEqual(document.value.disableDeepLinkRegistration, "disable")
        XCTAssertEqual(document.value.autoMemoryDirectory, ".claude/memory")
        XCTAssertEqual(document.value.includeCoAuthoredBy, false)
    }

    func testParseValidWorktreeAndOperationalSettingsFixture() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "valid_worktree_and_ops",
            section: "input",
            fileName: "settings.json"
        )
        let expected = try loader.loadExpectedIssueSet(
            familyPath: "parsers/settings",
            caseID: "valid_worktree_and_ops",
            fileName: "parser_issues.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(Set(result.issues.map(\.code.rawValue)), Set(expected.codes))
        XCTAssertEqual(document.value.worktree?.sparsePaths ?? [], ["packages/my-app", "shared/utils"])
        XCTAssertEqual(document.value.worktree?.symlinkDirectories ?? [], ["node_modules", ".cache"])
        XCTAssertEqual(document.value.cleanupPeriodDays, 20)
        XCTAssertEqual(document.value.companyAnnouncements ?? [], ["Welcome to Acme Corp!"])
        XCTAssertEqual(document.value.plansDirectory, "./plans")
        XCTAssertEqual(document.value.autoUpdatesChannel, "stable")
        XCTAssertEqual(document.value.disableDeepLinkRegistration, "disable")
        XCTAssertEqual(document.value.useAutoModeDuringPlan, false)
        XCTAssertEqual(document.value.showClearContextOnPlanAccept, true)
        XCTAssertEqual(document.value.rawValue(for: "worktree.symlinkDirectories"), .array([.string("node_modules"), .string(".cache")]))
    }

    func testParseCleanupPeriodZeroFixturePreservesValidZeroValue() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "valid_cleanup_zero",
            section: "input",
            fileName: "settings.json"
        )
        let expected = try loader.loadExpectedIssueSet(
            familyPath: "parsers/settings",
            caseID: "valid_cleanup_zero",
            fileName: "parser_issues.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(Set(result.issues.map(\.code.rawValue)), Set(expected.codes))
        XCTAssertEqual(document.value.cleanupPeriodDays, 0)
        XCTAssertEqual(document.value.rawValue(for: "cleanupPeriodDays"), .number(0))
    }

    func testParseInvalidWorktreeAndOperationalSettingsFixtureWarnsAndPreservesRawValues() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "invalid_worktree_ops",
            section: "input",
            fileName: "settings.json"
        )
        let expected = try loader.loadExpectedIssueSet(
            familyPath: "parsers/settings",
            caseID: "invalid_worktree_ops",
            fileName: "parser_issues.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)
        let codes = Set(result.issues.map(\.code.rawValue))

        XCTAssertTrue(result.hasErrors)
        XCTAssertEqual(codes, Set(expected.codes))
        XCTAssertNil(document.value.worktree)
        XCTAssertNil(document.value.cleanupPeriodDays)
        XCTAssertNil(document.value.autoUpdatesChannel)
        XCTAssertNil(document.value.disableDeepLinkRegistration)
        XCTAssertEqual(document.value.rawValue(for: "worktree"), .string("not-an-object"))
        XCTAssertEqual(document.value.rawValue(for: "cleanupPeriodDays"), .number(-5))
        XCTAssertEqual(document.value.rawValue(for: "autoUpdatesChannel"), .string("nightly"))
        XCTAssertEqual(document.value.rawValue(for: "disableDeepLinkRegistration"), .bool(true))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .typeMismatch &&
            $0.severity == .error &&
            $0.keyPath == "worktree"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .preservedUnknownValue &&
            $0.severity == .warning &&
            $0.keyPath == "cleanupPeriodDays"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .preservedUnknownValue &&
            $0.severity == .warning &&
            $0.keyPath == "autoUpdatesChannel"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .typeMismatch &&
            $0.severity == .warning &&
            $0.keyPath == "disableDeepLinkRegistration"
        }))
    }

    func testWorktreePreservesUnknownFieldsAndAllowsPartialObject() throws {
        let result = parser.parse(
            jsonString: """
            {
              "worktree": {
                "symlinkDirectories": ["node_modules"],
                "cachePolicy": "reuse"
              }
            }
            """,
            sourceURL: sourceURL
        )

        let document = try XCTUnwrap(result.value)

        XCTAssertFalse(result.hasErrors)
        XCTAssertNil(document.value.worktree?.sparsePaths)
        XCTAssertEqual(document.value.worktree?.symlinkDirectories ?? [], ["node_modules"])
        XCTAssertEqual(document.value.worktree?.unknownFields, ["cachePolicy": .string("reuse")])
    }

    func testParseValidUISettingsFixture() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "valid_ui_settings",
            section: "input",
            fileName: "settings.json"
        )
        let expected = try loader.loadExpectedIssueSet(
            familyPath: "parsers/settings",
            caseID: "valid_ui_settings",
            fileName: "parser_issues.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(Set(result.issues.map(\.code.rawValue)), Set(expected.codes))
        XCTAssertEqual(document.value.language, "japanese")
        XCTAssertEqual(document.value.respectGitignore, false)
        XCTAssertEqual(document.value.outputStyle, "Explanatory")
        XCTAssertEqual(document.value.defaultShell, "bash")
        XCTAssertEqual(document.value.voiceEnabled, true)
        XCTAssertEqual(document.value.prefersReducedMotion, true)
        XCTAssertEqual(document.value.spinnerTipsEnabled, false)
        XCTAssertEqual(document.value.statusLine?.type, "command")
        XCTAssertEqual(document.value.statusLine?.command, "~/.claude/statusline.sh")
        XCTAssertEqual(document.value.statusLine?.padding, 1)
        XCTAssertEqual(document.value.fileSuggestion?.type, "command")
        XCTAssertEqual(document.value.fileSuggestion?.command, "~/.claude/file-suggestion.sh")
        XCTAssertEqual(document.value.spinnerVerbs?.mode, "append")
        XCTAssertEqual(document.value.spinnerVerbs?.verbs ?? [], ["Pondering", "Crafting"])
        XCTAssertEqual(document.value.spinnerTipsOverride?.excludeDefault, true)
        XCTAssertEqual(document.value.spinnerTipsOverride?.tips ?? [], ["Use our internal tool X"])
        XCTAssertEqual(document.value.attribution?.commit, "Generated with AI\n\nCo-Authored-By: AI <ai@example.com>")
        XCTAssertEqual(document.value.attribution?.pr, "")
        XCTAssertEqual(document.value.rawValue(for: "statusLine.padding"), .number(1))
        XCTAssertEqual(document.value.rawValue(for: "spinnerVerbs.verbs"), .array([.string("Pondering"), .string("Crafting")]))
    }

    func testParseInvalidUISettingsFixtureWarnsAndPreservesRawValues() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "invalid_ui_settings",
            section: "input",
            fileName: "settings.json"
        )
        let expected = try loader.loadExpectedIssueSet(
            familyPath: "parsers/settings",
            caseID: "invalid_ui_settings",
            fileName: "parser_issues.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)
        let codes = Set(result.issues.map(\.code.rawValue))

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(codes, Set(expected.codes))
        XCTAssertNil(document.value.defaultShell)
        XCTAssertNil(document.value.statusLine)
        XCTAssertNil(document.value.spinnerVerbs?.mode)
        XCTAssertNil(document.value.attribution)
        XCTAssertEqual(document.value.rawValue(for: "defaultShell"), .string("zsh"))
        XCTAssertEqual(document.value.rawValue(for: "statusLine"), .string("not-an-object"))
        XCTAssertEqual(document.value.rawValue(for: "spinnerVerbs.mode"), .string("unknown"))
        XCTAssertEqual(document.value.rawValue(for: "attribution"), .number(42))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .preservedUnknownValue &&
            $0.severity == .warning &&
            $0.keyPath == "defaultShell"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .typeMismatch &&
            $0.severity == .warning &&
            $0.keyPath == "statusLine"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .preservedUnknownValue &&
            $0.severity == .warning &&
            $0.keyPath == "spinnerVerbs.mode"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .invalidAttributionShape &&
            $0.severity == .warning &&
            $0.keyPath == "attribution"
        }))
    }

    func testStructuredUISettingsPreserveUnknownFields() {
        let result = parser.parse(
            jsonString: """
            {
              "statusLine": {
                "type": "command",
                "command": "~/.claude/statusline.sh",
                "padding": 2,
                "theme": "compact"
              },
              "fileSuggestion": {
                "type": "command",
                "command": "~/.claude/file-suggestion.sh",
                "debounce": 250
              },
              "spinnerVerbs": {
                "mode": "replace",
                "verbs": ["Thinking"],
                "source": "team"
              },
              "spinnerTipsOverride": {
                "excludeDefault": true,
                "tips": ["Use X"],
                "audience": "internal"
              },
              "attribution": {
                "commit": "Generated with AI",
                "pr": "",
                "footer": "custom"
              }
            }
            """,
            sourceURL: sourceURL
        )

        let document = result.value?.value

        XCTAssertEqual(document?.statusLine?.unknownFields, ["theme": .string("compact")])
        XCTAssertEqual(document?.fileSuggestion?.unknownFields, ["debounce": .number(250)])
        XCTAssertEqual(document?.spinnerVerbs?.unknownFields, ["source": .string("team")])
        XCTAssertEqual(document?.spinnerTipsOverride?.unknownFields, ["audience": .string("internal")])
        XCTAssertEqual(document?.attribution?.unknownFields, ["footer": .string("custom")])
    }

    func testShowTurnDurationAndTerminalProgressBarEnabledRemainClaudeJsonOnly() throws {
        let result = parser.parse(
            jsonString: """
            {
              "showTurnDuration": true,
              "terminalProgressBarEnabled": false
            }
            """,
            sourceURL: sourceURL
        )

        let document = try XCTUnwrap(result.value)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(document.value.rawValue(for: "showTurnDuration"), .bool(true))
        XCTAssertEqual(document.value.rawValue(for: "terminalProgressBarEnabled"), .bool(false))
        XCTAssertEqual(document.unsupportedTopLevelKeys["showTurnDuration"], .bool(true))
        XCTAssertEqual(document.unsupportedTopLevelKeys["terminalProgressBarEnabled"], .bool(false))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .claudeJsonOnlyKeyInSettings && $0.keyPath == "showTurnDuration"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .claudeJsonOnlyKeyInSettings && $0.keyPath == "terminalProgressBarEnabled"
        }))
    }

    func testParseValidAuthenticationAndHelperSettingsFixture() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "valid_authentication_keys",
            section: "input",
            fileName: "settings.json"
        )
        let expected = try loader.loadExpectedIssueSet(
            familyPath: "parsers/settings",
            caseID: "valid_authentication_keys",
            fileName: "parser_issues.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(Set(result.issues.map(\.code.rawValue)), Set(expected.codes))
        XCTAssertEqual(document.value.apiKeyHelper, "security find-generic-password -s claude-api")
        XCTAssertEqual(document.value.forceLoginMethod, "console")
        XCTAssertEqual(document.value.forceLoginOrgUUID, "123E4567-E89B-12D3-A456-426614174000")
        XCTAssertEqual(document.value.otelHeadersHelper, "/usr/local/bin/otel-headers-helper")
        XCTAssertEqual(document.value.awsAuthRefresh, "/usr/local/bin/aws-auth-refresh")
        XCTAssertEqual(document.value.awsCredentialExport, "/usr/local/bin/aws-credential-export")
        XCTAssertEqual(document.value.rawValue(for: "forceLoginOrgUUID"), .string("123E4567-E89B-12D3-A456-426614174000"))
    }

    func testParseInvalidAuthenticationOrgUUIDFixtureWarnsAndPreservesRawValue() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "invalid_authentication_uuid",
            section: "input",
            fileName: "settings.json"
        )
        let expected = try loader.loadExpectedIssueSet(
            familyPath: "parsers/settings",
            caseID: "invalid_authentication_uuid",
            fileName: "parser_issues.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)
        let codes = Set(result.issues.map(\.code.rawValue))

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(codes, Set(expected.codes))
        XCTAssertNil(document.value.forceLoginOrgUUID)
        XCTAssertEqual(document.value.forceLoginMethod, "sso")
        XCTAssertEqual(document.value.rawValue(for: "forceLoginOrgUUID"), .string("not-a-uuid"))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .preservedUnknownValue &&
            $0.severity == .warning &&
            $0.keyPath == "forceLoginOrgUUID"
        }))
    }

    func testParseValidHooksStructureFixture() throws {
        let result = parser.parse(jsonString: SettingsParserFixtures.validHooksStructure, sourceURL: sourceURL)

        XCTAssertFalse(result.hasErrors)
        let document = try XCTUnwrap(result.value)

        let preToolUse = try XCTUnwrap(document.value.hooks?.events["preToolUse"])
        XCTAssertEqual(preToolUse.eventName, "preToolUse")
        XCTAssertEqual(preToolUse.eventType, .preToolUse)
        XCTAssertEqual(preToolUse.actions.count, 4)
        XCTAssertEqual(preToolUse.actions.first?.type, "command")
        XCTAssertEqual(preToolUse.actions.first?.handlerType, .command)
        XCTAssertEqual(preToolUse.actions.first?.command, "echo preparing")
        XCTAssertEqual(preToolUse.actions.first?.timeout, 5)
        XCTAssertEqual(preToolUse.actions.first?.statusMessage, "Preparing tool call")
        XCTAssertEqual(preToolUse.actions.first?.condition, "Bash(echo preparing)")
        XCTAssertEqual(preToolUse.actions.first?.isAsync, false)
        XCTAssertEqual(preToolUse.actions.first?.shell, "bash")
        XCTAssertEqual(preToolUse.actions[2].handlerType, .prompt)
        XCTAssertEqual(preToolUse.actions[2].prompt, "Review the pending tool call: $ARGUMENTS")
        XCTAssertEqual(preToolUse.actions[2].model, "claude-haiku-4-5-20251001")
        XCTAssertEqual(preToolUse.actions[3].handlerType, .agent)
        XCTAssertEqual(preToolUse.actions[3].prompt, "Validate the request before tool execution: $ARGUMENTS")
        XCTAssertEqual(preToolUse.actions[3].once, true)

        let postToolUse = try XCTUnwrap(document.value.hooks?.events["postToolUse"])
        XCTAssertEqual(postToolUse.eventType, .postToolUse)
        XCTAssertEqual(postToolUse.matcher, "Bash")
        XCTAssertEqual(postToolUse.actions.count, 1)
        XCTAssertEqual(postToolUse.actions.first?.url, "https://hooks.example.com/post")
        XCTAssertEqual(postToolUse.actions.first?.statusMessage, "Sending tool result")
        XCTAssertEqual(postToolUse.actions.first?.headers?["Authorization"], "Bearer $HOOK_TOKEN")
        XCTAssertEqual(postToolUse.actions.first?.allowedEnvVars ?? [], ["HOOK_TOKEN"])
    }

    func testParseCurrentHookEventCatalogFixtureRecognizesKnownEventsAndWarnsOnUnknown() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "current_hook_event_catalog",
            section: "input",
            fileName: "settings.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(document.value.hooks?.events["PreToolUse"]?.eventType, .preToolUse)
        XCTAssertEqual(document.value.hooks?.events["UserPromptSubmit"]?.eventType, .userPromptSubmit)
        XCTAssertEqual(document.value.hooks?.events["TeammateIdle"]?.eventType, .teammateIdle)
        XCTAssertEqual(document.value.hooks?.events["Setup"]?.eventType, .setup)
        XCTAssertEqual(document.value.hooks?.events["FutureHook"]?.eventType, .unknown("FutureHook"))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .preservedUnknownHookEvent &&
            $0.severity == .warning &&
            $0.keyPath == "hooks.FutureHook"
        }))
    }

    func testParseInvalidJSONProducesSyntaxIssue() {
        let result = parser.parse(jsonString: SettingsParserFixtures.invalidJSON, sourceURL: sourceURL)

        XCTAssertNil(result.value)
        XCTAssertTrue(result.hasErrors)
        XCTAssertTrue(result.issues.contains(where: { $0.code == .invalidJSON }))
    }

    func testParseInvalidHooksShapeProducesSyntaxIssue() throws {
        let result = parser.parse(jsonString: SettingsParserFixtures.invalidHooksShape, sourceURL: sourceURL)

        let document = try XCTUnwrap(result.value)
        XCTAssertTrue(result.hasErrors)
        XCTAssertTrue(result.issues.contains(where: { $0.code == .invalidHookShape }))
        XCTAssertEqual(document.value.hooks?.events.count, 0)
    }

    func testParseMixedHookHandlerFixtureSupportsAllCurrentHandlerTypes() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "mixed_hook_handler_types",
            section: "input",
            fileName: "settings.json"
        )
        let expected = try loader.loadExpectedIssueSet(
            familyPath: "parsers/settings",
            caseID: "mixed_hook_handler_types",
            fileName: "parser_issues.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)
        let codes = Set(result.issues.map(\.code.rawValue))
        let event = try XCTUnwrap(document.value.hooks?.events["PreToolUse"])

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(expected.codes, [])
        XCTAssertEqual(event.actions.map(\.handlerType), [.command, .http, .prompt, .agent])
        XCTAssertEqual(event.actions[0].statusMessage, "Running command hook")
        XCTAssertEqual(event.actions[1].timeout, 12)
        XCTAssertEqual(event.actions[2].prompt, "Inspect the hook payload: $ARGUMENTS")
        XCTAssertEqual(event.actions[3].prompt, "Delegate this hook check: $ARGUMENTS")
        XCTAssertEqual(codes, Set(expected.codes))
    }

    func testParseValidHookAllTypesFixtureCapturesExtendedHookProperties() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "valid_hook_all_types",
            section: "input",
            fileName: "settings.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(document.value.disableAllHooks, false)

        let preToolUse = try XCTUnwrap(document.value.hooks?.events["PreToolUse"])
        XCTAssertEqual(preToolUse.matcher, "Bash")
        XCTAssertEqual(preToolUse.actions.first?.condition, "Bash(npm run lint)")
        XCTAssertEqual(preToolUse.actions.first?.timeout, 300)
        XCTAssertEqual(preToolUse.actions.first?.statusMessage, "Running linter...")
        XCTAssertEqual(preToolUse.actions.first?.isAsync, false)
        XCTAssertEqual(preToolUse.actions.first?.shell, "bash")

        let postToolUse = try XCTUnwrap(document.value.hooks?.events["PostToolUse"])
        XCTAssertEqual(postToolUse.actions.first?.headers?["Authorization"], "Bearer $HOOK_TOKEN")
        XCTAssertEqual(postToolUse.actions.first?.allowedEnvVars ?? [], ["HOOK_TOKEN"])

        let stop = try XCTUnwrap(document.value.hooks?.events["Stop"])
        XCTAssertEqual(stop.actions.first?.model, "claude-haiku-4-5-20251001")

        let userPromptSubmit = try XCTUnwrap(document.value.hooks?.events["UserPromptSubmit"])
        XCTAssertEqual(userPromptSubmit.actions.first?.once, true)
    }

    func testParseInvalidHookCrossTypeFixtureReportsWarnings() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "invalid_hook_cross_type",
            section: "input",
            fileName: "settings.json"
        )
        let expected = try loader.loadExpectedIssueSet(
            familyPath: "parsers/settings",
            caseID: "invalid_hook_cross_type",
            fileName: "parser_issues.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL)
        let codes = Set(result.issues.map(\.code.rawValue))

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(codes, Set(expected.codes))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .invalidHookShape && $0.severity == .warning && $0.keyPath == "hooks.PreToolUse[0].headers" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .invalidHookShape && $0.severity == .warning && $0.keyPath == "hooks.PreToolUse[1].async" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .invalidHookShape && $0.severity == .warning && $0.keyPath == "hooks.PreToolUse[2].headers" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .invalidHookShape && $0.severity == .warning && $0.keyPath == "hooks.PreToolUse[3].shell" }))
    }

    func testParseInvalidHookHandlerRequirementsFixtureReportsClearIssues() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "invalid_hook_handler_requirements",
            section: "input",
            fileName: "settings.json"
        )
        let expected = try loader.loadExpectedIssueSet(
            familyPath: "parsers/settings",
            caseID: "invalid_hook_handler_requirements",
            fileName: "parser_issues.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL)
        let codes = Set(result.issues.map(\.code.rawValue))

        XCTAssertTrue(result.hasErrors)
        for code in expected.codes {
            XCTAssertTrue(codes.contains(code))
        }
        XCTAssertTrue(result.issues.contains(where: { $0.code == .invalidHookShape && $0.keyPath == "hooks.PreToolUse[0].command" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .invalidHookShape && $0.keyPath == "hooks.PreToolUse[1].url" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .invalidHookShape && $0.keyPath == "hooks.PreToolUse[2].prompt" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .invalidHookShape && $0.keyPath == "hooks.PreToolUse[3].prompt" }))
    }

    func testParsePermissionsShapeEdgeCases() throws {
        let result = parser.parse(jsonString: SettingsParserFixtures.permissionsShapeEdgeCases, sourceURL: sourceURL)

        let document = try XCTUnwrap(result.value)
        XCTAssertFalse(result.hasErrors)
        XCTAssertNil(document.value.permissions?.allow)
        XCTAssertEqual(document.value.permissions?.deny ?? [], ["Read(./tmp)"])
        XCTAssertTrue(result.issues.contains(where: { $0.code == .typeMismatch && $0.severity == .warning && $0.keyPath == "permissions.allow" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .typeMismatch && $0.severity == .warning && $0.keyPath == "permissions.defaultMode" }))
    }

    func testParseValidFullPermissionsFixture() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "valid_full_permissions",
            section: "input",
            fileName: "settings.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(document.value.permissions?.allow ?? [], ["Bash(npm run lint)", "Read(~/.zshrc)"])
        XCTAssertEqual(document.value.permissions?.deny ?? [], ["Bash(curl *)", "Read(./.env)"])
        XCTAssertEqual(document.value.permissions?.ask ?? [], ["Bash(git push *)"])
        XCTAssertEqual(document.value.permissions?.defaultMode, "acceptEdits")
        XCTAssertEqual(document.value.permissions?.additionalDirectories ?? [], ["../docs/"])
        XCTAssertEqual(document.value.permissions?.disableBypassPermissionsMode, "disable")
        XCTAssertEqual(document.value.allowManagedPermissionRulesOnly, true)
    }

    func testParseInvalidPermissionsFixtureCapturesInfoWarningAndTypeMismatch() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "invalid_permissions",
            section: "input",
            fileName: "settings.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(document.value.permissions?.defaultMode, "yolo")
        XCTAssertNil(document.value.permissions?.additionalDirectories)
        XCTAssertNil(document.value.permissions?.disableBypassPermissionsMode)
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .preservedUnknownValue &&
            $0.severity == .info &&
            $0.keyPath == "permissions.defaultMode"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .typeMismatch &&
            $0.severity == .warning &&
            $0.keyPath == "permissions.additionalDirectories"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .typeMismatch &&
            $0.severity == .warning &&
            $0.keyPath == "permissions.disableBypassPermissionsMode"
        }))
    }

    func testParseExperimentalDelegateModeProducesInfoLevelIssue() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "experimental_delegate_mode",
            section: "input",
            fileName: "settings.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(document.value.permissions?.defaultMode, "delegate")
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .preservedUnknownValue &&
            $0.severity == .info &&
            $0.keyPath == "permissions.defaultMode"
        }))
    }

    func testDisableBypassPermissionsModeNonDisableStringProducesWarning() {
        let result = parser.parse(
            jsonString: """
            {
              "permissions": {
                "disableBypassPermissionsMode": "warn"
              }
            }
            """,
            sourceURL: sourceURL
        )

        XCTAssertEqual(result.value?.value.permissions?.disableBypassPermissionsMode, "warn")
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .preservedUnknownValue &&
            $0.severity == .warning &&
            $0.keyPath == "permissions.disableBypassPermissionsMode"
        }))
    }

    func testParsePreservesUnknownFieldsForForwardCompatibility() throws {
        let result = parser.parse(jsonString: SettingsParserFixtures.unknownFieldsPreserved, sourceURL: sourceURL)

        XCTAssertFalse(result.hasErrors)
        let document = try XCTUnwrap(result.value)
        XCTAssertEqual(document.unsupportedTopLevelKeys.count, 2)
        XCTAssertEqual(document.unsupportedTopLevelKeys["futureSetting"], .string("enabled"))
        XCTAssertEqual(document.unsupportedTopLevelKeys["newNested"]?.isObject, true)
        XCTAssertEqual(document.value.pluginSettings["plugins"]?.isObject, true)
        XCTAssertTrue(result.issues.contains(where: { $0.code == .preservedUnsupportedKey && $0.keyPath == "futureSetting" }))
    }

    func testParseValidMcpControlsFixture() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "valid_mcp_controls",
            section: "input",
            fileName: "settings.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL, scope: .managed)
        let document = try XCTUnwrap(result.value)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(document.value.allowManagedMcpServersOnly, nil)
        XCTAssertEqual(document.value.enableAllProjectMcpServers, true)
        XCTAssertEqual(document.value.enabledMcpjsonServers ?? [], ["memory", "github"])
        XCTAssertEqual(document.value.disabledMcpjsonServers ?? [], ["filesystem"])
        XCTAssertEqual(
            document.value.allowedMcpServers,
            [
                McpRestrictionRule(serverName: "github", serverCommand: nil, serverUrl: nil, unknownFields: nil),
                McpRestrictionRule(
                    serverName: nil,
                    serverCommand: ["npx", "-y", "@modelcontextprotocol/server-github"],
                    serverUrl: nil,
                    unknownFields: nil
                )
            ]
        )
        XCTAssertEqual(
            document.value.deniedMcpServers,
            [
                McpRestrictionRule(serverName: "filesystem", serverCommand: nil, serverUrl: nil, unknownFields: nil),
                McpRestrictionRule(
                    serverName: nil,
                    serverCommand: nil,
                    serverUrl: "https://untrusted.example.com/*",
                    unknownFields: nil
                )
            ]
        )
    }

    func testParseInvalidMcpControlsFixtureCapturesAttributedDiagnostics() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "invalid_mcp_controls",
            section: "input",
            fileName: "settings.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)

        XCTAssertTrue(result.hasErrors)
        XCTAssertEqual(document.value.allowedMcpServers?.count, 0)
        XCTAssertNil(document.value.enabledMcpjsonServers)
        XCTAssertNil(document.value.deniedMcpServers)
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .typeMismatch &&
            $0.severity == .error &&
            $0.keyPath == "enabledMcpjsonServers"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .typeMismatch &&
            $0.severity == .warning &&
            $0.keyPath == "allowedMcpServers[0]"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .typeMismatch &&
            $0.severity == .warning &&
            $0.keyPath == "allowedMcpServers[1].serverCommand"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .invalidMcpRestrictionRule &&
            $0.severity == .error &&
            $0.keyPath == "allowedMcpServers[1]"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .invalidMcpRestrictionRule &&
            $0.severity == .error &&
            $0.keyPath == "allowedMcpServers[2]"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .invalidMcpRestrictionRule &&
            $0.severity == .error &&
            $0.keyPath == "allowedMcpServers[3]"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .typeMismatch &&
            $0.severity == .error &&
            $0.keyPath == "deniedMcpServers"
        }))
    }

    func testManagedOnlyMcpSettingInNonManagedScopeProducesWarning() {
        let result = parser.parse(
            jsonString: """
            {
              "allowManagedMcpServersOnly": true
            }
            """,
            sourceURL: sourceURL,
            scope: .project
        )

        XCTAssertEqual(result.value?.value.allowManagedMcpServersOnly, true)
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .managedOnlySettingInNonManagedScope &&
            $0.severity == .warning &&
            $0.keyPath == "allowManagedMcpServersOnly"
        }))
    }

    func testMcpRestrictionRulePreservesUnknownFields() throws {
        let result = parser.parse(
            jsonString: """
            {
              "deniedMcpServers": [
                {
                  "serverName": "github",
                  "comment": "future metadata"
                }
              ]
            }
            """,
            sourceURL: sourceURL
        )

        let rule = try XCTUnwrap(result.value?.value.deniedMcpServers?.first)
        XCTAssertEqual(rule.unknownFields, ["comment": .string("future metadata")])
    }

    func testParseValidSandboxFullFixture() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "valid_sandbox_full",
            section: "input",
            fileName: "settings.json"
        )
        let expected = try loader.loadExpectedIssueSet(
            familyPath: "parsers/settings",
            caseID: "valid_sandbox_full",
            fileName: "parser_issues.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)
        let sandbox = try XCTUnwrap(document.value.sandbox)
        let filesystem = try XCTUnwrap(sandbox.filesystem)
        let network = try XCTUnwrap(sandbox.network)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(Set(result.issues.map(\.code.rawValue)), Set(expected.codes))
        XCTAssertEqual(sandbox.enabled, true)
        XCTAssertEqual(sandbox.failIfUnavailable, true)
        XCTAssertEqual(sandbox.autoAllowBashIfSandboxed, true)
        XCTAssertEqual(sandbox.excludedCommands ?? [], ["docker", "git"])
        XCTAssertEqual(sandbox.allowUnsandboxedCommands, false)
        XCTAssertEqual(filesystem.allowWrite ?? [], ["/tmp/build", "~/.kube"])
        XCTAssertEqual(filesystem.denyWrite ?? [], ["/etc"])
        XCTAssertEqual(filesystem.denyRead ?? [], ["~/.aws/credentials"])
        XCTAssertEqual(filesystem.allowRead ?? [], ["."])
        XCTAssertEqual(network.allowUnixSockets ?? [], ["/var/run/docker.sock"])
        XCTAssertEqual(network.allowLocalBinding, true)
        XCTAssertEqual(network.allowedDomains ?? [], ["github.com", "*.npmjs.org"])
        XCTAssertEqual(network.httpProxyPort, 8080)
        XCTAssertEqual(network.socksProxyPort, 8081)
        XCTAssertEqual(document.value.rawValue(for: "sandbox.filesystem.allowWrite"), .array([.string("/tmp/build"), .string("~/.kube")]))
        XCTAssertEqual(document.value.rawValue(for: "sandbox.network.allowedDomains"), .array([.string("github.com"), .string("*.npmjs.org")]))
    }

    func testParseValidSandboxMinimalFixture() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "valid_sandbox_minimal",
            section: "input",
            fileName: "settings.json"
        )
        let expected = try loader.loadExpectedIssueSet(
            familyPath: "parsers/settings",
            caseID: "valid_sandbox_minimal",
            fileName: "parser_issues.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)
        let sandbox = try XCTUnwrap(document.value.sandbox)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(Set(result.issues.map(\.code.rawValue)), Set(expected.codes))
        XCTAssertEqual(sandbox.enabled, true)
        XCTAssertNil(sandbox.filesystem)
        XCTAssertNil(sandbox.network)
    }

    func testParseSandboxPartialNestedObjectsAndUnknownFields() throws {
        let result = parser.parse(
            jsonString: """
            {
              "sandbox": {
                "enableWeakerNestedSandbox": true,
                "note": "preserve me",
                "filesystem": {
                  "allowRead": ["./tmp"],
                  "futureFs": "keep"
                },
                "network": {
                  "allowAllUnixSockets": true,
                  "futureNet": 3
                }
              }
            }
            """,
            sourceURL: sourceURL
        )

        let sandbox = try XCTUnwrap(result.value?.value.sandbox)
        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(sandbox.enableWeakerNestedSandbox, true)
        XCTAssertEqual(sandbox.unknownFields, ["note": .string("preserve me")])
        XCTAssertEqual(sandbox.filesystem?.allowRead ?? [], ["./tmp"])
        XCTAssertEqual(sandbox.filesystem?.unknownFields, ["futureFs": .string("keep")])
        XCTAssertEqual(sandbox.network?.allowAllUnixSockets, true)
        XCTAssertEqual(sandbox.network?.unknownFields, ["futureNet": .number(3)])
    }

    func testParseInvalidSandboxShapesFixtureReportsNestedIssues() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "invalid_sandbox_shapes",
            section: "input",
            fileName: "settings.json"
        )
        let expected = try loader.loadExpectedIssueSet(
            familyPath: "parsers/settings",
            caseID: "invalid_sandbox_shapes",
            fileName: "parser_issues.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)
        let codes = Set(result.issues.map(\.code.rawValue))

        XCTAssertTrue(result.hasErrors)
        XCTAssertEqual(codes, Set(expected.codes))
        XCTAssertNil(document.value.sandbox?.enabled)
        XCTAssertNil(document.value.sandbox?.excludedCommands)
        XCTAssertNil(document.value.sandbox?.filesystem)
        XCTAssertNil(document.value.sandbox?.network?.httpProxyPort)
        XCTAssertNil(document.value.sandbox?.network?.allowedDomains)
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .typeMismatch &&
            $0.severity == .warning &&
            $0.keyPath == "sandbox.enabled"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .typeMismatch &&
            $0.severity == .warning &&
            $0.keyPath == "sandbox.excludedCommands"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .typeMismatch &&
            $0.severity == .error &&
            $0.keyPath == "sandbox.filesystem"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .typeMismatch &&
            $0.severity == .warning &&
            $0.keyPath == "sandbox.network.httpProxyPort"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .typeMismatch &&
            $0.severity == .warning &&
            $0.keyPath == "sandbox.network.allowedDomains"
        }))
    }

    func testManagedOnlySandboxSettingsInNonManagedScopeProduceWarnings() {
        let result = parser.parse(
            jsonString: """
            {
              "sandbox": {
                "filesystem": {
                  "allowManagedReadPathsOnly": true
                },
                "network": {
                  "allowManagedDomainsOnly": true
                }
              }
            }
            """,
            sourceURL: sourceURL,
            scope: .project
        )

        XCTAssertEqual(result.value?.value.sandbox?.filesystem?.allowManagedReadPathsOnly, true)
        XCTAssertEqual(result.value?.value.sandbox?.network?.allowManagedDomainsOnly, true)
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .managedOnlySettingInNonManagedScope &&
            $0.severity == .warning &&
            $0.keyPath == "sandbox.filesystem.allowManagedReadPathsOnly"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .managedOnlySettingInNonManagedScope &&
            $0.severity == .warning &&
            $0.keyPath == "sandbox.network.allowManagedDomainsOnly"
        }))
    }

    func testParseValidPluginMarketplaceControlsFixtureSupportsTypedMarketplaceSources() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "valid_plugin_marketplace_controls",
            section: "input",
            fileName: "settings.json"
        )
        let expected = try loader.loadExpectedIssueSet(
            familyPath: "parsers/settings",
            caseID: "valid_plugin_marketplace_controls",
            fileName: "parser_issues.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL, scope: .managed)
        let document = try XCTUnwrap(result.value)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(Set(result.issues.map(\.code.rawValue)), Set(expected.codes))
        XCTAssertEqual(document.value.enabledPlugins?["formatter@official"], true)
        XCTAssertEqual(document.value.enabledPlugins?["reviewer@partner"], false)
        XCTAssertEqual(document.value.pluginTrustMessage, "Install only approved plugins.")
        XCTAssertEqual(document.value.channelsEnabled, true)
        XCTAssertEqual(document.value.allowedChannelPlugins?.count, 2)
        XCTAssertEqual(document.value.allowedChannelPlugins?.first?.plugin, "formatter")
        XCTAssertEqual(document.value.allowedChannelPlugins?.first?.marketplace, "official")
        XCTAssertEqual(document.value.allowedChannelPlugins?.first?.channels ?? [], ["stable", "beta"])
        XCTAssertEqual(document.value.allowedChannelPlugins?.first?.unknownFields, ["note": .string("preferred")])
        XCTAssertEqual(document.value.allowedChannelPlugins?.last?.plugin, "reviewer@partner")

        let officialMarketplace = try XCTUnwrap(document.value.extraKnownMarketplaces?["official"])
        XCTAssertEqual(officialMarketplace.id, "official")
        XCTAssertEqual(
            officialMarketplace.source,
            .github(
                ParsedGitHubMarketplaceSource(
                    repo: "anthropic/plugins",
                    ref: "main",
                    subpath: "catalog",
                    unknownFields: nil
                )
            )
        )

        let partnerMarketplace = try XCTUnwrap(document.value.extraKnownMarketplaces?["partner"])
        XCTAssertEqual(partnerMarketplace.id, "partner")
        XCTAssertEqual(
            partnerMarketplace.source,
            .url(
                ParsedURLMarketplaceSource(
                    url: "https://plugins.example.com/index.json",
                    checksum: "sha256:abc123",
                    unknownFields: nil
                )
            )
        )

        XCTAssertEqual(document.value.strictKnownMarketplaces?.count, 5)
        XCTAssertEqual(document.value.blockedMarketplaces?.count, 1)
        XCTAssertEqual(document.value.rawValue(for: "extraKnownMarketplaces.official")?.isObject, true)
        XCTAssertEqual(document.value.rawValue(for: "blockedMarketplaces")?.isArray, true)
    }

    func testParseInvalidPluginMarketplaceControlsFixtureReportsAttributedTypeMismatches() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "invalid_plugin_marketplace_controls",
            section: "input",
            fileName: "settings.json"
        )
        let expected = try loader.loadExpectedIssueSet(
            familyPath: "parsers/settings",
            caseID: "invalid_plugin_marketplace_controls",
            fileName: "parser_issues.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(Set(result.issues.map(\.code.rawValue)), Set(expected.codes))
        XCTAssertNil(document.value.enabledPlugins)
        XCTAssertNil(document.value.extraKnownMarketplaces)
        XCTAssertNil(document.value.strictKnownMarketplaces)
        XCTAssertNil(document.value.pluginTrustMessage)
        XCTAssertNil(document.value.channelsEnabled)
        XCTAssertEqual(document.value.blockedMarketplaces?.count, 0)
        XCTAssertEqual(document.value.allowedChannelPlugins?.count, 0)
        XCTAssertTrue(result.issues.contains(where: { $0.code == .typeMismatch && $0.keyPath == "enabledPlugins" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .typeMismatch && $0.keyPath == "extraKnownMarketplaces" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .typeMismatch && $0.keyPath == "strictKnownMarketplaces" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .typeMismatch && $0.keyPath == "blockedMarketplaces[0]" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .typeMismatch && $0.keyPath == "pluginTrustMessage" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .typeMismatch && $0.keyPath == "channelsEnabled" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .typeMismatch && $0.keyPath == "allowedChannelPlugins[0]" }))
    }

    func testManagedOnlyPluginMarketplaceControlsInNonManagedScopeProduceWarnings() {
        let result = parser.parse(
            jsonString: """
            {
              "pluginTrustMessage": "Managed only",
              "channelsEnabled": true,
              "allowedChannelPlugins": [
                {
                  "plugin": "formatter"
                }
              ],
              "strictKnownMarketplaces": [
                {
                  "id": "official",
                  "source": {
                    "type": "github",
                    "repo": "anthropic/plugins"
                  }
                }
              ],
              "blockedMarketplaces": [
                {
                  "id": "legacy",
                  "source": {
                    "type": "url",
                    "url": "https://legacy.example.com"
                  }
                }
              ]
            }
            """,
            sourceURL: sourceURL,
            scope: .project
        )

        XCTAssertEqual(result.value?.value.pluginTrustMessage, "Managed only")
        XCTAssertEqual(result.value?.value.channelsEnabled, true)
        XCTAssertEqual(result.value?.value.allowedChannelPlugins?.count, 1)
        XCTAssertEqual(result.value?.value.strictKnownMarketplaces?.count, 1)
        XCTAssertEqual(result.value?.value.blockedMarketplaces?.count, 1)
        XCTAssertTrue(result.issues.contains(where: { $0.code == .managedOnlySettingInNonManagedScope && $0.keyPath == "pluginTrustMessage" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .managedOnlySettingInNonManagedScope && $0.keyPath == "channelsEnabled" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .managedOnlySettingInNonManagedScope && $0.keyPath == "allowedChannelPlugins" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .managedOnlySettingInNonManagedScope && $0.keyPath == "strictKnownMarketplaces" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .managedOnlySettingInNonManagedScope && $0.keyPath == "blockedMarketplaces" }))
    }

    func testNonObjectSandboxParentsProduceErrors() {
        let topLevelResult = parser.parse(
            jsonString: """
            {
              "sandbox": "disabled"
            }
            """,
            sourceURL: sourceURL
        )
        XCTAssertTrue(topLevelResult.hasErrors)
        XCTAssertTrue(topLevelResult.issues.contains(where: {
            $0.code == .typeMismatch &&
            $0.severity == .error &&
            $0.keyPath == "sandbox"
        }))

        let nestedResult = parser.parse(
            jsonString: """
            {
              "sandbox": {
                "network": false
              }
            }
            """,
            sourceURL: sourceURL
        )
        XCTAssertTrue(nestedResult.hasErrors)
        XCTAssertTrue(nestedResult.issues.contains(where: {
            $0.code == .typeMismatch &&
            $0.severity == .error &&
            $0.keyPath == "sandbox.network"
        }))
    }

    func testRegistryCoversCorrectedModernKeysAndAdvancedMetadata() throws {
        let registry = SettingsKeyRegistry.shared

        XCTAssertEqual(registry.definition(for: "alwaysThinkingEnabled")?.type, .bool)
        XCTAssertEqual(registry.definition(for: "availableModels")?.type, .stringArray)
        XCTAssertEqual(registry.definition(for: "modelOverrides")?.type, .dictionary(value: .string))
        XCTAssertEqual(registry.definition(for: "effortLevel")?.type, .string)
        XCTAssertEqual(registry.definition(for: "defaultShell")?.type, .string)
        XCTAssertEqual(registry.definition(for: "defaultShell")?.category, .uiSessionExperience)
        XCTAssertEqual(registry.definition(for: "language")?.type, .string)
        XCTAssertEqual(registry.definition(for: "respectGitignore")?.type, .bool)
        XCTAssertEqual(registry.definition(for: "companyAnnouncements")?.type, .stringArray)
        XCTAssertEqual(registry.definition(for: "companyAnnouncements")?.mergeHint, .appendUnique)
        XCTAssertEqual(registry.definition(for: "channelsEnabled")?.type, .bool)
        XCTAssertEqual(registry.definition(for: "enabledPlugins")?.type, .dictionary(value: .bool))
        XCTAssertEqual(registry.definition(for: "extraKnownMarketplaces")?.type, .dictionary(value: .object(properties: [
            "id": .string,
            "source": .object(properties: [
                "type": .string
            ], allowAdditionalProperties: true)
        ], allowAdditionalProperties: true)))
        XCTAssertEqual(registry.definition(for: "allowedChannelPlugins")?.type, .array(element: .object(properties: [
            "plugin": .string,
            "marketplace": .string,
            "channels": .stringArray
        ], allowAdditionalProperties: true)))
        XCTAssertEqual(registry.definition(for: "autoMemoryEnabled")?.type, .bool)
        XCTAssertEqual(registry.definition(for: "claudeMdExcludes")?.type, .stringArray)
        XCTAssertEqual(registry.definition(for: "permissions.ask")?.type, .stringArray)
        XCTAssertEqual(registry.definition(for: "permissions.defaultMode")?.type, .string)
        XCTAssertEqual(registry.definition(for: "permissions.additionalDirectories")?.type, .stringArray)
        XCTAssertEqual(registry.definition(for: "permissions.disableBypassPermissionsMode")?.type, .string)
        XCTAssertEqual(registry.definition(for: "feedbackSurveyRate")?.type, .number)
        XCTAssertEqual(registry.definition(for: "agent")?.type, .string)
        XCTAssertEqual(registry.definition(for: "agent")?.category, .modelReasoning)
        XCTAssertEqual(registry.definition(for: "forceLoginMethod")?.type, .string)
        XCTAssertEqual(registry.definition(for: "forceLoginMethod")?.category, .authenticationIdentity)
        XCTAssertEqual(registry.definition(for: "forceLoginOrgUUID")?.type, .string)
        XCTAssertEqual(registry.definition(for: "otelHeadersHelper")?.type, .string)
        XCTAssertEqual(registry.definition(for: "awsAuthRefresh")?.type, .string)
        XCTAssertEqual(registry.definition(for: "awsCredentialExport")?.type, .string)
        XCTAssertTrue(try XCTUnwrap(registry.definition(for: "allowManagedPermissionRulesOnly")).isManagedOnly)
        XCTAssertTrue(try XCTUnwrap(registry.definition(for: "allowManagedMcpServersOnly")).isManagedOnly)
        XCTAssertEqual(registry.definition(for: "allowedMcpServers")?.type, .array(element: .object(properties: [
            "serverName": .string,
            "serverCommand": .stringArray,
            "serverUrl": .string
        ], allowAdditionalProperties: true)))
        XCTAssertEqual(registry.definition(for: "enabledMcpjsonServers")?.type, .stringArray)
        XCTAssertEqual(registry.definition(for: "disabledMcpjsonServers")?.type, .stringArray)
        XCTAssertEqual(registry.definition(for: "sandbox.enabled")?.type, .bool)
        XCTAssertEqual(registry.definition(for: "sandbox.excludedCommands")?.type, .stringArray)
        XCTAssertEqual(registry.definition(for: "sandbox.enableWeakerNestedSandbox")?.type, .bool)
        XCTAssertEqual(registry.definition(for: "sandbox.filesystem.allowWrite")?.type, .stringArray)
        XCTAssertEqual(registry.definition(for: "sandbox.filesystem.allowRead")?.mergeHint, .appendUnique)
        XCTAssertTrue(try XCTUnwrap(registry.definition(for: "sandbox.filesystem.allowManagedReadPathsOnly")).isManagedOnly)
        XCTAssertEqual(registry.definition(for: "sandbox.network.allowUnixSockets")?.type, .stringArray)
        XCTAssertEqual(registry.definition(for: "sandbox.network.allowedDomains")?.mergeHint, .appendUnique)
        XCTAssertTrue(try XCTUnwrap(registry.definition(for: "sandbox.network.allowManagedDomainsOnly")).isManagedOnly)
        XCTAssertEqual(registry.definition(for: "strictKnownMarketplaces")?.type, .array(element: .object(properties: [
            "id": .string,
            "source": .object(properties: [
                "type": .string
            ], allowAdditionalProperties: true)
        ], allowAdditionalProperties: true)))
        XCTAssertEqual(registry.definition(for: "blockedMarketplaces")?.type, .array(element: .object(properties: [
            "id": .string,
            "source": .object(properties: [
                "type": .string
            ], allowAdditionalProperties: true)
        ], allowAdditionalProperties: true)))
        XCTAssertEqual(registry.definition(for: "pluginTrustMessage")?.type, .string)
        XCTAssertEqual(registry.definition(for: "statusLine")?.type, .object(properties: [
            "type": .string,
            "command": .string,
            "padding": .integer
        ], allowAdditionalProperties: true))
        XCTAssertEqual(registry.definition(for: "fileSuggestion")?.type, .object(properties: [
            "type": .string,
            "command": .string
        ], allowAdditionalProperties: true))
        XCTAssertEqual(registry.definition(for: "spinnerVerbs")?.type, .object(properties: [
            "mode": .string,
            "verbs": .stringArray
        ], allowAdditionalProperties: true))
        XCTAssertEqual(registry.definition(for: "spinnerTipsOverride")?.type, .object(properties: [
            "excludeDefault": .bool,
            "tips": .stringArray
        ], allowAdditionalProperties: true))
        XCTAssertEqual(registry.definition(for: "showClearContextOnPlanAccept")?.type, .bool)
        XCTAssertEqual(registry.definition(for: "worktree")?.type, .object(properties: [
            "sparsePaths": .stringArray,
            "symlinkDirectories": .stringArray
        ], allowAdditionalProperties: true))
        XCTAssertEqual(registry.definition(for: "worktree.sparsePaths")?.mergeHint, .appendUnique)
        XCTAssertEqual(registry.definition(for: "worktree.symlinkDirectories")?.mergeHint, .appendUnique)
        XCTAssertEqual(registry.definition(for: "plansDirectory")?.type, .string)
        XCTAssertEqual(registry.definition(for: "autoUpdatesChannel")?.type, .string)
        XCTAssertEqual(registry.definition(for: "disableDeepLinkRegistration")?.type, .string)
        XCTAssertEqual(
            registry.definition(for: "useAutoModeDuringPlan")?.applicableScopes,
            [.managed, .user, .projectLocal]
        )
        XCTAssertTrue(try XCTUnwrap(registry.definition(for: "channelsEnabled")).isManagedOnly)
        XCTAssertTrue(try XCTUnwrap(registry.definition(for: "allowedChannelPlugins")).isManagedOnly)
        XCTAssertTrue(try XCTUnwrap(registry.definition(for: "strictKnownMarketplaces")).isManagedOnly)
        XCTAssertTrue(try XCTUnwrap(registry.definition(for: "blockedMarketplaces")).isManagedOnly)
        XCTAssertTrue(try XCTUnwrap(registry.definition(for: "pluginTrustMessage")).isManagedOnly)
        XCTAssertTrue(try XCTUnwrap(registry.definition(for: "pluginConfigs")).isAdvanced)
        XCTAssertTrue(try XCTUnwrap(registry.definition(for: "pluginConfigs")).isReadOnlyDiagnostic)
        XCTAssertTrue(try XCTUnwrap(registry.definition(for: "skippedPlugins")).isAdvanced)
        XCTAssertTrue(try XCTUnwrap(registry.definition(for: "skippedMarketplaces")).isAdvanced)
    }

    func testRegistryCoveredModernSettingsFixturePreservesRawValues() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "valid_registry_modern",
            section: "input",
            fileName: "settings.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(document.value.rawValue(for: "defaultShell"), .string("bash"))
        XCTAssertEqual(document.value.rawValue(for: "autoMemoryEnabled"), .bool(true))
        XCTAssertEqual(document.value.rawValue(for: "enabledPlugins.formatter@official"), .bool(true))
        XCTAssertEqual(document.value.rawValue(for: "extraKnownMarketplaces.official")?.isObject, true)
        XCTAssertEqual(document.value.rawValue(for: "allowedChannelPlugins")?.isArray, true)
        XCTAssertEqual(document.value.rawValue(for: "blockedMarketplaces")?.isArray, true)
        XCTAssertEqual(document.value.rawValue(for: "pluginTrustMessage"), .string("Install only approved plugins."))
        XCTAssertEqual(document.value.rawValue(for: "allowManagedMcpServersOnly"), .bool(true))
        XCTAssertEqual(document.value.rawValue(for: "sandbox.network.httpProxyPort"), .number(8080))
        XCTAssertEqual(document.value.rawValue(for: "worktree.sparsePaths"), .array([.string("Sources/**"), .string("Tests/**")]))
        XCTAssertEqual(document.value.rawValue(for: "pluginConfigs.examplePlugin"), .object(["enabled": .bool(true)]))
        XCTAssertEqual(document.value.rawValue(for: "skippedPlugins"), .array([.string("legacy-plugin")]))
        XCTAssertEqual(document.unsupportedTopLevelKeys["futureSetting"], .string("preserved"))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .preservedUnsupportedKey && $0.keyPath == "futureSetting" }))
    }

    func testRegistryKnownWrongTypeProducesWarningFixture() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "invalid_registry_known_type",
            section: "input",
            fileName: "settings.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)

        XCTAssertFalse(result.hasErrors)
        XCTAssertNil(document.value.rawValue(for: "futureSetting"))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .typeMismatch &&
            $0.severity == .warning &&
            $0.keyPath == "defaultShell"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .typeMismatch &&
            $0.severity == .warning &&
            $0.keyPath == "allowedMcpServers[0]"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .typeMismatch &&
            $0.severity == .warning &&
            $0.keyPath == "strictKnownMarketplaces"
        }))
    }

    func testMisplacedClaudeJsonOnlyKeysWarnInSettingsJson() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "misplaced_claude_json_keys",
            section: "input",
            fileName: "settings.json"
        )
        let expected = try loader.loadExpectedIssueSet(
            familyPath: "parsers/settings",
            caseID: "misplaced_claude_json_keys",
            fileName: "parser_issues.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)
        let codes = Set(result.issues.map(\.code.rawValue))

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(codes, Set(expected.codes))
        XCTAssertEqual(document.unsupportedTopLevelKeys["editorMode"], .string("vim"))
        XCTAssertEqual(document.unsupportedTopLevelKeys["teammateMode"], .string("auto"))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .claudeJsonOnlyKeyInSettings &&
            $0.severity == .warning &&
            $0.keyPath == "editorMode"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .claudeJsonOnlyKeyInSettings &&
            $0.severity == .warning &&
            $0.keyPath == "teammateMode"
        }))
    }

    func testParseFixtureFileFromCanonicalParserLayout() throws {
        let loader = FixtureLoader.shared
        let jsonString = try loader.loadString(
            familyPath: "parsers/settings",
            caseID: "valid_basic",
            section: "input",
            fileName: "settings.json"
        )

        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)
        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(document.value.cleanupPeriodDays, 30)
        XCTAssertEqual(document.value.includeGitInstructions, true)
        XCTAssertEqual(document.value.env?.values["FOO"], "bar")
    }

    func testSharedFixtureCaseCanBeReusedByParserSuite() throws {
        let loader = FixtureLoader.shared
        let projectLocalJSON = try loader.loadString(
            familyPath: "shared/settings",
            caseID: "override_project_wins",
            section: "input",
            fileName: "project.settings.local.json"
        )

        let result = parser.parse(jsonString: projectLocalJSON, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)
        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(document.value.cleanupPeriodDays, 30)
        XCTAssertEqual(document.value.includeGitInstructions, true)
    }
}

private enum SettingsParserFixtures {
    static let validUserSettings = """
    {
      "$schema": "https://example.com/schema",
      "apiKeyHelper": "security find-generic-password",
      "cleanupPeriodDays": 30,
      "companyAnnouncements": ["Welcome to Acme Corp!", "Remember to file your expenses."],
      "includeGitInstructions": true,
      "disableAllHooks": false,
      "allowManagedHooksOnly": false,
      "allowedHttpHookUrls": ["https://hooks.example.com/a", "https://hooks.example.com/b"],
      "httpHookAllowedEnvVars": ["PATH", "HOME"],
      "env": {
        "FOO": "bar",
        "BAZ": "qux"
      }
    }
    """

    static let validProjectSettings = """
    {
      "autoMode": true,
      "disableAutoMode": false,
      "useAutoModeDuringPlan": true,
      "permissions": {
        "allow": ["Bash(git status)", "Read(./**)"],
        "deny": ["Bash(rm -rf /)"],
        "defaultMode": "default"
      }
    }
    """

    static let validLocalProjectOverrides = """
    {
      "disableDeepLinkRegistration": "disable",
      "autoMemoryDirectory": ".claude/memory",
      "includeCoAuthoredBy": false
    }
    """

    static let validHooksStructure = """
    {
      "hooks": {
        "preToolUse": [
          {
            "type": "command",
            "command": "echo preparing",
            "if": "Bash(echo preparing)",
            "timeout": 5,
            "statusMessage": "Preparing tool call",
            "async": false,
            "shell": "bash"
          },
          {
            "type": "http",
            "url": "https://hooks.example.com/pre"
          },
          {
            "type": "prompt",
            "prompt": "Review the pending tool call: $ARGUMENTS",
            "model": "claude-haiku-4-5-20251001"
          },
          {
            "type": "agent",
            "prompt": "Validate the request before tool execution: $ARGUMENTS",
            "once": true
          }
        ],
        "postToolUse": {
          "matcher": "Bash",
          "hooks": [
            {
              "type": "http",
              "url": "https://hooks.example.com/post",
              "statusMessage": "Sending tool result",
              "headers": {
                "Authorization": "Bearer $HOOK_TOKEN"
              },
              "allowedEnvVars": ["HOOK_TOKEN"]
            }
          ]
        }
      }
    }
    """

    static let invalidJSON = """
    {
      "includeGitInstructions": true,
      "hooks": {
        "preToolUse": [
          { "type": "command", "command": "echo hi" }
        ]
    """

    static let invalidHooksShape = """
    {
      "hooks": {
        "preToolUse": "not-an-array"
      }
    }
    """

    static let permissionsShapeEdgeCases = """
    {
      "permissions": {
        "allow": "Bash(*)",
        "deny": ["Read(./tmp)"],
        "defaultMode": true
      }
    }
    """

    static let unknownFieldsPreserved = """
    {
      "futureSetting": "enabled",
      "newNested": {
        "inner": true
      },
      "plugins": {
        "example": {
          "enabled": true
        }
      }
    }
    """
}

private extension JSONValue {
    var isArray: Bool {
        if case .array = self {
            return true
        }
        return false
    }

    var isObject: Bool {
        if case .object = self {
            return true
        }
        return false
    }
}

final class SchemaFetcherTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        MockURLProtocol.reset()
    }

    func testFetch_ValidUrl_Success() async throws {
        let data = try fixtureData(caseID: "validSchema", fileName: "remote-schema.json")
        MockURLProtocol.handler = { _ in
            (
                HTTPURLResponse(url: URL(string: "https://example.com/schema.json")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                data
            )
        }

        let fetcher = SchemaFetcher(schemaUrl: URL(string: "https://example.com/schema.json")!)
        let result = await fetcher.fetch(session: makeSession())

        guard case .success(let schema) = result else {
            return XCTFail("Expected success, got \(result)")
        }
        XCTAssertEqual(schema["model"]?.type, "string")
        XCTAssertEqual(
            schema["model"]?.allowedValues,
            ["claude-3-5", "claude-opus", "gpt-4", "new-model-v2"]
        )
        XCTAssertEqual(schema["newKey"]?.type, "boolean")
    }

    func testFetch_InvalidUrl_FallbackToBuiltIn() async {
        MockURLProtocol.handler = { _ in
            (
                HTTPURLResponse(url: URL(string: "https://example.com/schema.json")!, statusCode: 404, httpVersion: nil, headerFields: nil)!,
                Data()
            )
        }

        let fetcher = SchemaFetcher(schemaUrl: URL(string: "https://example.com/schema.json")!)
        let result = await fetcher.fetch(session: makeSession())

        guard case .fallbackToBuiltIn(let reason) = result else {
            return XCTFail("Expected fallback, got \(result)")
        }
        XCTAssertTrue(reason.contains("HTTP status 404"))
    }

    func testFetch_TimeoutExceeded_FallbackToBuiltIn() async {
        MockURLProtocol.handler = { _ in throw URLError(.timedOut) }

        let fetcher = SchemaFetcher(schemaUrl: URL(string: "https://example.com/schema.json")!)
        let result = await fetcher.fetch(session: makeSession(), timeoutSeconds: 1)

        guard case .fallbackToBuiltIn(let reason) = result else {
            return XCTFail("Expected fallback, got \(result)")
        }
        XCTAssertTrue(reason.localizedCaseInsensitiveContains("timed out"))
    }

    func testFetch_InvalidJsonResponse_FallbackToBuiltIn() async throws {
        let data = try fixtureData(caseID: "invalidSchema", fileName: "invalid-schema.json")
        MockURLProtocol.handler = { _ in
            (
                HTTPURLResponse(url: URL(string: "https://example.com/schema.json")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                data
            )
        }

        let fetcher = SchemaFetcher(schemaUrl: URL(string: "https://example.com/schema.json")!)
        let result = await fetcher.fetch(session: makeSession())

        guard case .fallbackToBuiltIn(let reason) = result else {
            return XCTFail("Expected fallback, got \(result)")
        }
        XCTAssertTrue(reason.localizedCaseInsensitiveContains("parsing failed"))
    }

    func testFetch_LargeSchema_Rejected_FallbackToBuiltIn() async {
        let oversized = Data(repeating: 0x41, count: 10 * 1_024 * 1_024 + 1)
        MockURLProtocol.handler = { _ in
            (
                HTTPURLResponse(url: URL(string: "https://example.com/schema.json")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                oversized
            )
        }

        let fetcher = SchemaFetcher(schemaUrl: URL(string: "https://example.com/schema.json")!)
        let result = await fetcher.fetch(session: makeSession())

        guard case .fallbackToBuiltIn(let reason) = result else {
            return XCTFail("Expected fallback, got \(result)")
        }
        XCTAssertTrue(reason.contains("10 MB"))
    }

    func testCompare_NewKeysDetected_Included() {
        let fetcher = SchemaFetcher()
        var remote = SchemaFetcher.builtInRegistry
        for index in 1...5 {
            remote["newKey\(index)"] = SchemaRule(keyPath: "newKey\(index)", type: "string")
        }

        let comparison = fetcher.compareWithBuiltIn(remote: remote)
        XCTAssertEqual(comparison.newKeys.count, 5)
    }

    func testCompare_RemovedKeys_Detected() {
        let fetcher = SchemaFetcher()
        var remote = SchemaFetcher.builtInRegistry
        Array(remote.keys.sorted().prefix(5)).forEach { remote.removeValue(forKey: $0) }

        let comparison = fetcher.compareWithBuiltIn(remote: remote)
        XCTAssertEqual(comparison.removedKeys.count, 5)
    }

    func testCompare_UpdatedKeys_Detected() {
        let fetcher = SchemaFetcher()
        var remote = SchemaFetcher.builtInRegistry
        remote["model"] = SchemaRule(keyPath: "model", type: "string", allowedValues: ["new-model"])

        let comparison = fetcher.compareWithBuiltIn(remote: remote)
        XCTAssertEqual(Array(comparison.updatedKeys.keys), ["model"])
    }

    func testMerge_RemoteAndBuiltIn_BuiltInWins() {
        let fetcher = SchemaFetcher()
        let merged = fetcher.mergedRegistry(remote: ["model": SchemaRule(keyPath: "model", type: "boolean")])
        XCTAssertEqual(merged["model"], SchemaFetcher.builtInRegistry["model"])
    }

    func testMerge_NewKeyIncluded_InMerged() {
        let fetcher = SchemaFetcher()
        let merged = fetcher.mergedRegistry(remote: ["newKey": SchemaRule(keyPath: "newKey", type: "boolean")])
        XCTAssertEqual(merged["newKey"]?.type, "boolean")
    }

    func testCache_Hit_ReturnsCachedSchema() async {
        let cache = InMemorySchemaCache()
        let schema = ["cachedKey": SchemaRule(keyPath: "cachedKey", type: "string")]
        cache.set(key: "https://example.com/schema.json", schema: schema, fetchedAt: Date())

        let fetcher = SchemaFetcher(schemaUrl: URL(string: "https://example.com/schema.json")!, cache: cache)
        let result = await fetcher.fetch(session: makeSession())

        guard case .cachedSchema(let cachedSchema, _) = result else {
            return XCTFail("Expected cached schema, got \(result)")
        }
        XCTAssertEqual(cachedSchema, schema)
        XCTAssertEqual(MockURLProtocol.requestCount, 0)
    }

    func testCache_Expired_FetchesFresh() async throws {
        let cache = InMemorySchemaCache(ttl: 1)
        cache.set(
            key: "https://example.com/schema.json",
            schema: ["cachedKey": SchemaRule(keyPath: "cachedKey", type: "string")],
            fetchedAt: Date(timeIntervalSinceNow: -5)
        )

        let freshData = try fixtureData(caseID: "validSchema", fileName: "remote-schema.json")
        MockURLProtocol.handler = { _ in
            (
                HTTPURLResponse(url: URL(string: "https://example.com/schema.json")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                freshData
            )
        }

        let fetcher = SchemaFetcher(schemaUrl: URL(string: "https://example.com/schema.json")!, cache: cache)
        let result = await fetcher.fetch(session: makeSession())

        guard case .success = result else {
            return XCTFail("Expected fresh success, got \(result)")
        }
        XCTAssertEqual(MockURLProtocol.requestCount, 1)
    }

    func testInMemoryCache_SetAndGet_Retrieves() {
        let cache = InMemorySchemaCache()
        let fetchedAt = Date()
        let schema = ["cachedKey": SchemaRule(keyPath: "cachedKey", type: "string")]

        cache.set(key: "cache-key", schema: schema, fetchedAt: fetchedAt)
        let entry = cache.get(key: "cache-key")

        XCTAssertEqual(entry?.0, schema)
        XCTAssertEqual(entry?.1, fetchedAt)
    }

    func testInMemoryCache_Invalidate_Clears() {
        let cache = InMemorySchemaCache()
        cache.set(key: "cache-key", schema: ["cachedKey": SchemaRule(keyPath: "cachedKey", type: "string")], fetchedAt: Date())
        cache.invalidate(key: "cache-key")
        XCTAssertNil(cache.get(key: "cache-key"))
    }

    func testService_IsFetchingEnabled_Respected() async {
        let preferences = makePreferences()
        var stored = preferences.schemaFetcherPreferences
        stored.isEnabled = false
        preferences.schemaFetcherPreferences = stored

        let service = SchemaFetcherService(
            schemaFetcher: SchemaFetcher(schemaUrl: URL(string: "https://example.com/schema.json")!),
            preferences: preferences
        )
        let result = await service.refreshSchema(session: makeSession())

        guard case .fallbackToBuiltIn(let reason) = result else {
            return XCTFail("Expected fallback, got \(result)")
        }
        XCTAssertTrue(reason.localizedCaseInsensitiveContains("disabled"))
        XCTAssertEqual(MockURLProtocol.requestCount, 0)
    }

    func testService_LastFetchedAt_Updated() async throws {
        let preferences = makePreferences(enabled: true)
        let data = try fixtureData(caseID: "validSchema", fileName: "remote-schema.json")
        MockURLProtocol.handler = { _ in
            (
                HTTPURLResponse(url: URL(string: "https://example.com/schema.json")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                data
            )
        }

        let service = SchemaFetcherService(
            schemaFetcher: SchemaFetcher(schemaUrl: URL(string: "https://example.com/schema.json")!),
            preferences: preferences
        )
        _ = await service.refreshSchema(session: makeSession())
        XCTAssertNotNil(service.lastFetchedAt)
    }

    func testService_CurrentMergedRegistry_ContainsNewKeys() async throws {
        let preferences = makePreferences(enabled: true)
        let data = try fixtureData(caseID: "validSchema", fileName: "remote-schema.json")
        MockURLProtocol.handler = { _ in
            (
                HTTPURLResponse(url: URL(string: "https://example.com/schema.json")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                data
            )
        }

        let service = SchemaFetcherService(
            schemaFetcher: SchemaFetcher(schemaUrl: URL(string: "https://example.com/schema.json")!),
            preferences: preferences
        )
        _ = await service.refreshSchema(session: makeSession())
        XCTAssertEqual(service.currentMergedRegistry["newKey"]?.type, "boolean")
    }

    func testService_NewKeysDetected_ReturnsNewOnly() async throws {
        let preferences = makePreferences(enabled: true)
        let data = try fixtureData(caseID: "validSchema", fileName: "remote-schema.json")
        MockURLProtocol.handler = { _ in
            (
                HTTPURLResponse(url: URL(string: "https://example.com/schema.json")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                data
            )
        }

        let service = SchemaFetcherService(
            schemaFetcher: SchemaFetcher(schemaUrl: URL(string: "https://example.com/schema.json")!),
            preferences: preferences
        )
        _ = await service.refreshSchema(session: makeSession())
        XCTAssertEqual(Array(service.newKeysDetected().keys), ["newKey"])
    }

    func testSchemaValidatorMarksFetchedKnownKeysDifferentlyThanTrulyUnknownKeys() async throws {
        let preferences = makePreferences(enabled: true)
        let data = try fixtureData(caseID: "validSchema", fileName: "remote-schema.json")
        MockURLProtocol.handler = { _ in
            (
                HTTPURLResponse(url: URL(string: "https://example.com/schema.json")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                data
            )
        }

        let service = SchemaFetcherService(
            schemaFetcher: SchemaFetcher(schemaUrl: URL(string: "https://example.com/schema.json")!),
            preferences: preferences
        )
        _ = await service.refreshSchema(session: makeSession())

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
                pluginSettings: [:],
                keyedStorage: ["newKey": .bool(true), "totallyUnknown": .string("value")],
                registryValues: [:]
            ),
            rawTopLevelObject: ["newKey": .bool(true), "totallyUnknown": .string("value")],
            unsupportedTopLevelKeys: ["newKey": .bool(true), "totallyUnknown": .string("value")]
        )

        let result = SchemaValidator().validate(settings: document, schemaFetcherService: service)

        XCTAssertTrue(result.issues.contains(where: {
            $0.code.rawValue == "schema.settings.schemaKnownRemoteKey" && $0.keyPath == "newKey" && $0.severity == .info
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code.rawValue == "schema.settings.unknownKey" && $0.keyPath == "totallyUnknown" && $0.severity == .warning
        }))
    }

    private func fixtureData(caseID: FixtureCaseID, fileName: String) throws -> Data {
        let descriptor = try FixtureLoader.shared.descriptor(
            familyPath: "parsers/schema-fetcher",
            caseID: caseID
        )
        return try Data(contentsOf: descriptor.inputFileURL(named: fileName))
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func makePreferences(enabled: Bool = false) -> AppPreferences {
        let suiteName = "SchemaFetcherTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let preferences = AppPreferences(defaults: defaults)
        var stored = preferences.schemaFetcherPreferences
        stored.isEnabled = enabled
        preferences.schemaFetcherPreferences = stored
        return preferences
    }
}

private final class MockURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var requestCountStorage = 0
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return requestCountStorage
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        requestCountStorage = 0
        handler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.lock()
        Self.requestCountStorage += 1
        let handler = Self.handler
        Self.lock.unlock()

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

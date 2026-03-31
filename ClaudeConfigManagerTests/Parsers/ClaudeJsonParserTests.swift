import XCTest
@testable import ClaudeConfigManager

final class ClaudeJsonParserTests: XCTestCase {
    private let parser = ClaudeJsonParser()
    private let sourceURL = URL(fileURLWithPath: "/tmp/.claude.json", isDirectory: false)

    func testParseValidBaselineFixture() throws {
        let result = parser.parse(jsonString: ClaudeJsonParserFixtures.validBaseline, sourceURL: sourceURL)

        XCTAssertFalse(result.hasErrors)
        let document = try XCTUnwrap(result.value)
        XCTAssertEqual(document.value.schema, "https://example.com/claude-json.schema.json")
        XCTAssertEqual(document.value.globalPreferences?.defaultModel, "claude-sonnet")
        XCTAssertEqual(document.value.globalPreferences?.defaultMode, "plan")
        XCTAssertEqual(document.value.globalPreferences?.telemetryEnabled, false)
        XCTAssertEqual(document.unsupportedTopLevelKeys.count, 0)
    }

    func testParseValidUserAndLocalMcpEntries() throws {
        let result = parser.parse(jsonString: ClaudeJsonParserFixtures.validUserAndLocalMcp, sourceURL: sourceURL)

        XCTAssertFalse(result.hasErrors)
        let document = try XCTUnwrap(result.value)

        let userServer = try XCTUnwrap(document.value.mcpState?.userServers["filesystem"])
        XCTAssertEqual(userServer.command, "npx")
        XCTAssertEqual(userServer.args ?? [], ["-y", "@modelcontextprotocol/server-filesystem"])
        XCTAssertEqual(userServer.env?["HOME"], "/Users/test")
        XCTAssertEqual(userServer.enabled, true)

        let localServer = try XCTUnwrap(document.value.mcpState?.localServers["notes"])
        XCTAssertEqual(localServer.url, "http://127.0.0.1:7777")
        XCTAssertEqual(localServer.headers?["Authorization"], "Bearer token")
        XCTAssertEqual(localServer.transportType, .http)
        XCTAssertEqual(localServer.serverSource, .claudeJson)
    }

    func testParseStdioTransportCapturesCwdAndUnknownFields() throws {
        let sourceURL = URL(fileURLWithPath: "/tmp/project/.mcp.json", isDirectory: false)
        let result = parser.parse(jsonString: ClaudeJsonParserFixtures.validMcpTransportsWrapped, sourceURL: sourceURL)

        XCTAssertFalse(result.hasErrors)
        let document = try XCTUnwrap(result.value)
        let github = try XCTUnwrap(document.value.mcpState?.localServers["github"])
        XCTAssertEqual(github.transportType, .stdio)
        XCTAssertEqual(github.command, "npx")
        XCTAssertEqual(github.args ?? [], ["-y", "@modelcontextprotocol/server-github"])
        XCTAssertEqual(github.env?["GITHUB_TOKEN"], "...")
        XCTAssertEqual(github.cwd, "/tmp/project")
        XCTAssertEqual(github.serverSource, .mcpJson(path: "/tmp/project/.mcp.json"))
        XCTAssertEqual(github.config.unknownFields?["futureFlag"], .bool(true))
    }

    func testParseSseTransportEmitsDeprecationInfo() throws {
        let sourceURL = URL(fileURLWithPath: "/tmp/project/.mcp.json", isDirectory: false)
        let result = parser.parse(jsonString: ClaudeJsonParserFixtures.validMcpTransportsWrapped, sourceURL: sourceURL)

        let document = try XCTUnwrap(result.value)
        let legacy = try XCTUnwrap(document.value.mcpState?.localServers["legacy-sse"])
        XCTAssertEqual(legacy.transportType, .sse)
        XCTAssertEqual(legacy.url, "https://old.example.com/sse")
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .deprecatedMcpTransport &&
            $0.severity == .info &&
            $0.keyPath == "mcp.local.legacy-sse"
        }))
    }

    func testParsePluginProvidedServerUsesPluginTransportAndSource() throws {
        let managedURL = URL(fileURLWithPath: "/Library/Application Support/ClaudeCode/managed-mcp.json", isDirectory: false)
        let result = parser.parse(jsonString: ClaudeJsonParserFixtures.pluginMcpWrapped, sourceURL: managedURL)

        XCTAssertFalse(result.hasErrors)
        let document = try XCTUnwrap(result.value)
        let pluginServer = try XCTUnwrap(document.value.mcpState?.localServers["github-plugin"])
        XCTAssertEqual(pluginServer.transportType, .plugin)
        XCTAssertEqual(pluginServer.pluginId, "com.anthropic.github")
        XCTAssertEqual(pluginServer.pluginName, "GitHub")
        XCTAssertEqual(pluginServer.serverSource, .plugin(id: "com.anthropic.github"))
    }

    func testParseManagedMcpSourceUsesManagedProvenance() throws {
        let managedURL = URL(fileURLWithPath: "/Library/Application Support/ClaudeCode/managed-mcp.json", isDirectory: false)
        let result = parser.parse(jsonString: ClaudeJsonParserFixtures.validMcpTransportsWrapped, sourceURL: managedURL)

        XCTAssertFalse(result.hasErrors)
        let document = try XCTUnwrap(result.value)
        let remote = try XCTUnwrap(document.value.mcpState?.localServers["remote-api"])
        XCTAssertEqual(remote.transportType, .http)
        XCTAssertEqual(remote.serverSource, .managed)
    }

    func testParseAmbiguousAndEmptyMcpServersEmitWarnings() throws {
        let sourceURL = URL(fileURLWithPath: "/tmp/project/.mcp.json", isDirectory: false)
        let result = parser.parse(jsonString: ClaudeJsonParserFixtures.invalidMcpTransportsWrapped, sourceURL: sourceURL)

        let document = try XCTUnwrap(result.value)
        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(document.value.mcpState?.localServers["empty"]?.transportType, .unknown)
        XCTAssertEqual(document.value.mcpState?.localServers["ambiguous"]?.transportType, .stdio)
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .missingMcpTransport &&
            $0.severity == .warning &&
            $0.keyPath == "mcp.local.empty"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .ambiguousMcpTransport &&
            $0.severity == .warning &&
            $0.keyPath == "mcp.local.ambiguous"
        }))
    }

    func testParseValidTrustState() throws {
        let result = parser.parse(jsonString: ClaudeJsonParserFixtures.validTrustState, sourceURL: sourceURL)

        XCTAssertFalse(result.hasErrors)
        let document = try XCTUnwrap(result.value)
        XCTAssertEqual(document.value.trustState?.trustedProjectPaths ?? [], ["/Users/test/work/app"])
        XCTAssertEqual(document.value.trustState?.blockedProjectPaths ?? [], ["/tmp/untrusted"])
    }

    func testParseValidGlobalConfigKeys() throws {
        let result = parser.parse(jsonString: ClaudeJsonParserFixtures.validGlobalConfigKeys, sourceURL: sourceURL)

        XCTAssertFalse(result.hasErrors)
        let document = try XCTUnwrap(result.value)
        XCTAssertEqual(document.value.autoConnectIde, true)
        XCTAssertEqual(document.value.autoInstallIdeExtension, false)
        XCTAssertEqual(document.value.editorMode, "vim")
        XCTAssertEqual(document.value.showTurnDuration, false)
        XCTAssertEqual(document.value.terminalProgressBarEnabled, true)
        XCTAssertEqual(document.value.teammateMode, "tmux")
        XCTAssertEqual(document.value.globalPreferences?.defaultModel, "claude-sonnet-4-6")
    }

    func testParseInvalidGlobalConfigEnumsWarnAndPreserveRawValues() throws {
        let result = parser.parse(jsonString: ClaudeJsonParserFixtures.invalidGlobalConfigEnums, sourceURL: sourceURL)

        XCTAssertFalse(result.hasErrors)
        let document = try XCTUnwrap(result.value)
        XCTAssertNil(document.value.editorMode)
        XCTAssertNil(document.value.teammateMode)
        XCTAssertEqual(document.rawTopLevelObject["editorMode"], .string("emacs"))
        XCTAssertEqual(document.rawTopLevelObject["teammateMode"], .string("split-screen"))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .preservedUnknownValue &&
            $0.severity == .warning &&
            $0.keyPath == "editorMode"
        }))
        XCTAssertTrue(result.issues.contains(where: {
            $0.code == .preservedUnknownValue &&
            $0.severity == .warning &&
            $0.keyPath == "teammateMode"
        }))
    }

    func testParseInvalidJSONProducesSyntaxIssue() {
        let result = parser.parse(jsonString: ClaudeJsonParserFixtures.invalidJSON, sourceURL: sourceURL)

        XCTAssertNil(result.value)
        XCTAssertTrue(result.hasErrors)
        XCTAssertTrue(result.issues.contains(where: { $0.code == .invalidJSON }))
    }

    func testParseMalformedNestedMcpStructureProducesSyntaxIssue() throws {
        let result = parser.parse(jsonString: ClaudeJsonParserFixtures.invalidMcpShape, sourceURL: sourceURL)

        let document = try XCTUnwrap(result.value)
        XCTAssertTrue(result.hasErrors)
        XCTAssertTrue(result.issues.contains(where: { $0.code == .invalidClaudeJsonMcpShape }))
        XCTAssertEqual(document.value.mcpState?.userServers.count ?? 0, 0)
    }

    func testParseMalformedTrustStateStructureProducesTypeMismatch() throws {
        let result = parser.parse(jsonString: ClaudeJsonParserFixtures.invalidTrustShape, sourceURL: sourceURL)

        let document = try XCTUnwrap(result.value)
        XCTAssertTrue(result.hasErrors)
        XCTAssertTrue(result.issues.contains(where: { $0.code == .typeMismatch && $0.keyPath == "trust.trustedProjectPaths" }))
        XCTAssertEqual(document.value.trustState?.trustedProjectPaths ?? [], [])
        XCTAssertEqual(document.value.trustState?.blockedProjectPaths ?? [], ["/tmp/blocked"])
    }

    func testParsePreservesUnknownFieldsForForwardCompatibility() throws {
        let result = parser.parse(jsonString: ClaudeJsonParserFixtures.unknownFieldsPreserved, sourceURL: sourceURL)

        XCTAssertFalse(result.hasErrors)
        let document = try XCTUnwrap(result.value)
        XCTAssertEqual(document.unsupportedTopLevelKeys["futureKey"], .string("enabled"))
        XCTAssertTrue(isObject(document.unsupportedTopLevelKeys["futureNested"]))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .preservedUnsupportedKey && $0.keyPath == "futureKey" }))
    }

    func testParseSettingsFamilyKeysAreNotModeledAsClaudeJsonFields() throws {
        let result = parser.parse(jsonString: ClaudeJsonParserFixtures.settingsLikePayload, sourceURL: sourceURL)

        let document = try XCTUnwrap(result.value)
        XCTAssertTrue(result.issues.contains(where: { $0.code == .settingsFamilyKeyInClaudeJson && $0.keyPath == "permissions" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .settingsFamilyKeyInClaudeJson && $0.keyPath == "hooks" }))
        XCTAssertTrue(isObject(document.settingsFamilyTopLevelKeys["permissions"]))
        XCTAssertTrue(isObject(document.settingsFamilyTopLevelKeys["hooks"]))
        XCTAssertNil(document.value.mcpState)
        XCTAssertNil(document.value.globalPreferences)
    }

    func testParseFixtureValidBasicFromCanonicalParserLayout() throws {
        let loader = FixtureLoader.shared
        let json = try loader.loadString(
            familyPath: "parsers/claude_json",
            caseID: "valid_basic",
            section: "input",
            fileName: ".claude.json"
        )

        let result = parser.parse(jsonString: json, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)
        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(document.value.globalPreferences?.defaultModel, "claude-sonnet")
        XCTAssertEqual(document.value.mcpState?.localServers["notes"]?.url, "http://127.0.0.1:7777")
        XCTAssertEqual(document.value.mcpState?.userServers["filesystem"]?.command, "npx")
    }

    func testParseFixtureInvalidMcpShapeIncludesExpectedIssueCode() throws {
        let loader = FixtureLoader.shared
        let json = try loader.loadString(
            familyPath: "parsers/claude_json",
            caseID: "invalid_mcp_shape",
            section: "input",
            fileName: ".claude.json"
        )
        let expected = try loader.loadExpectedIssueSet(
            familyPath: "parsers/claude_json",
            caseID: "invalid_mcp_shape",
            fileName: "parser_issues.json"
        )

        let result = parser.parse(jsonString: json, sourceURL: sourceURL)
        let codes = Set(result.issues.map(\.code.rawValue))
        XCTAssertTrue(result.hasErrors)
        for code in expected.codes {
            XCTAssertTrue(codes.contains(code))
        }
    }

    func testParseFixturePreservesForwardCompatibleTopLevelKeys() throws {
        let loader = FixtureLoader.shared
        let json = try loader.loadString(
            familyPath: "parsers/claude_json",
            caseID: "forward_unknown_fields",
            section: "input",
            fileName: ".claude.json"
        )

        let result = parser.parse(jsonString: json, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)
        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(document.unsupportedTopLevelKeys["futureRoot"], .string("enabled"))
        XCTAssertTrue(isObject(document.unsupportedTopLevelKeys["futureNested"]))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .preservedUnsupportedKey && $0.keyPath == "futureRoot" }))
    }

    func testParseFixtureValidGlobalConfig() throws {
        let loader = FixtureLoader.shared
        let json = try loader.loadString(
            familyPath: "parsers/claude_json",
            caseID: "valid_global_config",
            section: "input",
            fileName: ".claude.json"
        )
        let expected = try loader.loadExpectedIssueSet(
            familyPath: "parsers/claude_json",
            caseID: "valid_global_config",
            fileName: "parser_issues.json"
        )

        let result = parser.parse(jsonString: json, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)
        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(Set(result.issues.map(\.code.rawValue)), Set(expected.codes))
        XCTAssertEqual(document.value.autoConnectIde, true)
        XCTAssertEqual(document.value.autoInstallIdeExtension, false)
        XCTAssertEqual(document.value.editorMode, "vim")
        XCTAssertEqual(document.value.showTurnDuration, false)
        XCTAssertEqual(document.value.terminalProgressBarEnabled, true)
        XCTAssertEqual(document.value.teammateMode, "tmux")
    }

    func testParseFixtureInvalidGlobalConfigEnumsIncludesExpectedIssueCodes() throws {
        let loader = FixtureLoader.shared
        let json = try loader.loadString(
            familyPath: "parsers/claude_json",
            caseID: "invalid_global_config_enums",
            section: "input",
            fileName: ".claude.json"
        )
        let expected = try loader.loadExpectedIssueSet(
            familyPath: "parsers/claude_json",
            caseID: "invalid_global_config_enums",
            fileName: "parser_issues.json"
        )

        let result = parser.parse(jsonString: json, sourceURL: sourceURL)
        let codes = Set(result.issues.map(\.code.rawValue))
        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(codes, Set(expected.codes))
    }

    private func isObject(_ value: JSONValue?) -> Bool {
        guard let value else {
            return false
        }
        if case .object = value {
            return true
        }
        return false
    }
}

private enum ClaudeJsonParserFixtures {
    static let validBaseline = """
    {
      "$schema": "https://example.com/claude-json.schema.json",
      "globalPreferences": {
        "defaultModel": "claude-sonnet",
        "defaultMode": "plan",
        "telemetryEnabled": false
      },
      "mcp": {
        "user": {},
        "local": {}
      },
      "trust": {
        "trustedProjectPaths": [],
        "blockedProjectPaths": []
      }
    }
    """

    static let validUserAndLocalMcp = """
    {
      "mcp": {
        "user": {
          "filesystem": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-filesystem"],
            "env": {
              "HOME": "/Users/test"
            },
            "enabled": true
          }
        },
        "local": {
          "notes": {
            "url": "http://127.0.0.1:7777",
            "headers": {
              "Authorization": "Bearer token"
            }
          }
        }
      }
    }
    """

    static let validTrustState = """
    {
      "trust": {
        "trustedProjectPaths": ["/Users/test/work/app"],
        "blockedProjectPaths": ["/tmp/untrusted"]
      }
    }
    """

    static let validGlobalConfigKeys = """
    {
      "autoConnectIde": true,
      "autoInstallIdeExtension": false,
      "editorMode": "vim",
      "showTurnDuration": false,
      "terminalProgressBarEnabled": true,
      "teammateMode": "tmux",
      "globalPreferences": {
        "defaultModel": "claude-sonnet-4-6"
      }
    }
    """

    static let invalidGlobalConfigEnums = """
    {
      "editorMode": "emacs",
      "teammateMode": "split-screen"
    }
    """

    static let invalidJSON = """
    {
      "mcp": {
        "user": {
          "filesystem": {
            "command": "npx"
          }
        }
    """

    static let invalidMcpShape = """
    {
      "mcp": {
        "user": [],
        "local": {
          "notObject": "bad"
        }
      }
    }
    """

    static let invalidTrustShape = """
    {
      "trust": {
        "trustedProjectPaths": "not-an-array",
        "blockedProjectPaths": ["/tmp/blocked"]
      }
    }
    """

    static let unknownFieldsPreserved = """
    {
      "futureKey": "enabled",
      "futureNested": {
        "inner": true
      }
    }
    """

    static let settingsLikePayload = """
    {
      "permissions": {
        "allow": ["Bash(git status)"]
      },
      "hooks": {
        "preToolUse": []
      }
    }
    """

    static let validMcpTransportsWrapped = """
    {
      "mcp": {
        "local": {
          "github": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-github"],
            "env": { "GITHUB_TOKEN": "..." },
            "cwd": "/tmp/project",
            "futureFlag": true
          },
          "remote-api": {
            "url": "https://api.example.com/mcp",
            "headers": { "Authorization": "Bearer token" }
          },
          "legacy-sse": {
            "url": "https://old.example.com/sse",
            "transport": "sse"
          }
        }
      }
    }
    """

    static let pluginMcpWrapped = """
    {
      "mcp": {
        "local": {
          "github-plugin": {
            "pluginId": "com.anthropic.github",
            "pluginName": "GitHub"
          }
        }
      }
    }
    """

    static let invalidMcpTransportsWrapped = """
    {
      "mcp": {
        "local": {
          "empty": {},
          "ambiguous": {
            "command": "tool",
            "url": "https://example.com"
          }
        }
      }
    }
    """
}

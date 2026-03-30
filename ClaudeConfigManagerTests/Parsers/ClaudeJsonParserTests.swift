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
    }

    func testParseValidTrustState() throws {
        let result = parser.parse(jsonString: ClaudeJsonParserFixtures.validTrustState, sourceURL: sourceURL)

        XCTAssertFalse(result.hasErrors)
        let document = try XCTUnwrap(result.value)
        XCTAssertEqual(document.value.trustState?.trustedProjectPaths ?? [], ["/Users/test/work/app"])
        XCTAssertEqual(document.value.trustState?.blockedProjectPaths ?? [], ["/tmp/untrusted"])
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
}

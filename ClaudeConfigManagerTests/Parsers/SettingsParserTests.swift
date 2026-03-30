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
        XCTAssertEqual(document.value.companyAnnouncements, true)
        XCTAssertEqual(document.value.env?.values["FOO"], "bar")
        XCTAssertEqual(document.value.includeGitInstructions, true)
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
    }

    func testParseValidLocalProjectOverridesFixture() throws {
        let result = parser.parse(jsonString: SettingsParserFixtures.validLocalProjectOverrides, sourceURL: sourceURL)

        XCTAssertFalse(result.hasErrors)
        let document = try XCTUnwrap(result.value)
        XCTAssertEqual(document.value.disableDeepLinkRegistration, true)
        XCTAssertEqual(document.value.autoMemoryDirectory, ".claude/memory")
        XCTAssertEqual(document.value.includeCoAuthoredBy, false)
    }

    func testParseValidHooksStructureFixture() throws {
        let result = parser.parse(jsonString: SettingsParserFixtures.validHooksStructure, sourceURL: sourceURL)

        XCTAssertFalse(result.hasErrors)
        let document = try XCTUnwrap(result.value)

        let preToolUse = try XCTUnwrap(document.value.hooks?.events["preToolUse"])
        XCTAssertEqual(preToolUse.actions.count, 2)
        XCTAssertEqual(preToolUse.actions.first?.type, "command")
        XCTAssertEqual(preToolUse.actions.first?.command, "echo preparing")

        let postToolUse = try XCTUnwrap(document.value.hooks?.events["postToolUse"])
        XCTAssertEqual(postToolUse.matcher, "Bash")
        XCTAssertEqual(postToolUse.actions.count, 1)
        XCTAssertEqual(postToolUse.actions.first?.url, "https://hooks.example.com/post")
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

    func testParsePermissionsShapeEdgeCases() throws {
        let result = parser.parse(jsonString: SettingsParserFixtures.permissionsShapeEdgeCases, sourceURL: sourceURL)

        let document = try XCTUnwrap(result.value)
        XCTAssertTrue(result.hasErrors)
        XCTAssertNil(document.value.permissions?.allow)
        XCTAssertEqual(document.value.permissions?.deny ?? [], ["Read(./tmp)"])
        XCTAssertTrue(result.issues.contains(where: { $0.code == .typeMismatch && $0.keyPath == "permissions.allow" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .typeMismatch && $0.keyPath == "permissions.mode" }))
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
}

private enum SettingsParserFixtures {
    static let validUserSettings = """
    {
      "$schema": "https://example.com/schema",
      "apiKeyHelper": "security find-generic-password",
      "cleanupPeriodDays": 30,
      "companyAnnouncements": true,
      "includeGitInstructions": true,
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
        "mode": "default"
      }
    }
    """

    static let validLocalProjectOverrides = """
    {
      "disableDeepLinkRegistration": true,
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
            "timeoutMs": 500
          },
          {
            "type": "http",
            "url": "https://hooks.example.com/pre"
          }
        ],
        "postToolUse": {
          "matcher": "Bash",
          "hooks": [
            {
              "type": "http",
              "url": "https://hooks.example.com/post"
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
        "mode": true
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
    var isObject: Bool {
        if case .object = self {
            return true
        }
        return false
    }
}

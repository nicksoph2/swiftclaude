import XCTest
@testable import ClaudeConfigManager

final class SettingsDocumentValueAccessorsTests: XCTestCase {
    private let parser = SettingsParser()
    private let sourceURL = URL(fileURLWithPath: "/tmp/settings.json", isDirectory: false)

    func testTypedAccessorsReturnScalarArrayObjectAndUnsupportedValues() throws {
        let result = parser.parse(jsonString: fixtureJSON, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)

        XCTAssertEqual(document.value.string(for: "model"), "sonnet")
        XCTAssertEqual(document.value.bool(for: "alwaysThinkingEnabled"), true)
        XCTAssertEqual(document.value.int(for: "cleanupPeriodDays"), 21)
        XCTAssertEqual(document.value.number(for: "cleanupPeriodDays"), 21)
        XCTAssertEqual(document.value.stringArray(for: "allowedHttpHookUrls"), ["https://hooks.example.com/a"])
        XCTAssertEqual(document.value.stringArray(for: "enabledMcpjsonServers"), ["docs"])
        XCTAssertEqual(
            document.value.object(for: "sandbox.network"),
            [
                "httpProxyPort": .number(8080),
                "socksProxyPort": .number(1080)
            ]
        )
        XCTAssertEqual(document.value.jsonValue(for: "futureSetting"), .string("preserved"))
    }

    func testTypedAccessorsReturnNilForAbsentOrWrongTypeValues() throws {
        let result = parser.parse(jsonString: fixtureJSON, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)

        XCTAssertNil(document.value.string(for: "cleanupPeriodDays"))
        XCTAssertNil(document.value.bool(for: "model"))
        XCTAssertNil(document.value.int(for: "sandbox.network"))
        XCTAssertNil(document.value.number(for: "missing"))
        XCTAssertNil(document.value.stringArray(for: "sandbox"))
        XCTAssertNil(document.value.object(for: "alwaysThinkingEnabled"))
    }

    func testGroupedAccessorsReturnConfiguredFamilyMaps() throws {
        let result = parser.parse(jsonString: fixtureJSON, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)

        XCTAssertEqual(
            document.value.modelSettings,
            [
                "alwaysThinkingEnabled": .bool(true),
                "fastMode": .bool(false),
                "model": .string("sonnet"),
                "reasoning": .string("high")
            ]
        )
        XCTAssertEqual(
            document.value.permissionSettings,
            [
                "permissions": .object([
                    "allow": .array([.string("Read(./**)")]),
                    "disableBypassPermissionsMode": .string("disable"),
                    "defaultMode": .string("default")
                ])
            ]
        )
        XCTAssertEqual(
            document.value.hookPolicySettings,
            [
                "allowedHttpHookUrls": .array([.string("https://hooks.example.com/a")]),
                "hooks": .object([
                    "preToolUse": .array([
                        .object([
                            "type": .string("command"),
                            "command": .string("echo hi")
                        ])
                    ])
                ])
            ]
        )
        XCTAssertEqual(document.value.mcpSettings["allowedMcpServers"]?.isArray, true)
        XCTAssertEqual(document.value.mcpSettings["enabledMcpjsonServers"], .array([.string("docs")]))
        XCTAssertEqual(document.value.sandboxSettings["sandbox"]?.isObject, true)
        XCTAssertEqual(document.value.pluginAndMarketplaceSettings["plugins"]?.isObject, true)
        XCTAssertEqual(document.value.pluginAndMarketplaceSettings["enabledPlugins"]?.isObject, true)
        XCTAssertEqual(document.value.pluginAndMarketplaceSettings["channelsEnabled"], .bool(true))
        XCTAssertEqual(document.value.pluginAndMarketplaceSettings["extraKnownMarketplaces"]?.isObject, true)
        XCTAssertEqual(document.value.pluginAndMarketplaceSettings["pluginConfigs"]?.isObject, true)
        XCTAssertEqual(document.value.authenticationAndHelperSettings["apiKeyHelper"], .string("/usr/bin/security"))
        XCTAssertEqual(document.value.authenticationAndHelperSettings["forceLoginMethod"], .string("console"))
        XCTAssertEqual(document.value.authenticationAndHelperSettings["forceLoginOrgUUID"], .string("123e4567-e89b-12d3-a456-426614174000"))
        XCTAssertEqual(document.value.authenticationAndHelperSettings["otelHeadersHelper"], .string("/usr/local/bin/otel-headers"))
        XCTAssertEqual(document.value.authenticationAndHelperSettings["awsAuthRefresh"], .string("/usr/local/bin/aws-refresh"))
        XCTAssertEqual(document.value.authenticationAndHelperSettings["awsCredentialExport"], .string("/usr/local/bin/aws-export"))
        XCTAssertNil(document.value.authenticationAndHelperSettings["defaultShell"])
        XCTAssertEqual(document.value.uiSessionSettings["statusLine"]?.isObject, true)
        XCTAssertEqual(document.value.uiSessionSettings["defaultShell"], .string("bash"))
        XCTAssertEqual(document.value.worktreeSettings["worktree"]?.isObject, true)
        XCTAssertEqual(document.value.memoryAndClaudeMdSettings["memory"]?.isObject, true)
    }

    func testGroupedAccessorsReturnEmptyDictionariesWhenUnset() {
        let value = SettingsDocumentValue(
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
            allowManagedPermissionRulesOnly: nil,
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
        )

        XCTAssertEqual(value.modelSettings, [:])
        XCTAssertEqual(value.permissionSettings, [:])
        XCTAssertEqual(value.hookPolicySettings, [:])
        XCTAssertEqual(value.mcpSettings, [:])
        XCTAssertEqual(value.sandboxSettings, [:])
        XCTAssertEqual(value.pluginAndMarketplaceSettings, [:])
        XCTAssertEqual(value.authenticationAndHelperSettings, [:])
        XCTAssertEqual(value.uiSessionSettings, [:])
        XCTAssertEqual(value.worktreeSettings, [:])
        XCTAssertEqual(value.memoryAndClaudeMdSettings, [:])
    }

    private let fixtureJSON = """
    {
      "apiKeyHelper": "/usr/bin/security",
      "forceLoginMethod": "console",
      "forceLoginOrgUUID": "123e4567-e89b-12d3-a456-426614174000",
      "otelHeadersHelper": "/usr/local/bin/otel-headers",
      "awsAuthRefresh": "/usr/local/bin/aws-refresh",
      "awsCredentialExport": "/usr/local/bin/aws-export",
      "defaultShell": "bash",
      "model": "sonnet",
      "reasoning": "high",
      "alwaysThinkingEnabled": true,
      "fastMode": false,
      "cleanupPeriodDays": 21,
      "permissions": {
        "allow": ["Read(./**)"],
        "defaultMode": "default",
        "disableBypassPermissionsMode": "disable"
      },
      "hooks": {
        "preToolUse": [
          {
            "type": "command",
            "command": "echo hi"
          }
        ]
      },
      "allowedHttpHookUrls": ["https://hooks.example.com/a"],
      "enabledMcpjsonServers": ["docs"],
      "allowedMcpServers": [
        {
          "serverName": "docs"
        }
      ],
      "sandbox": {
        "network": {
          "httpProxyPort": 8080,
          "socksProxyPort": 1080
        }
      },
      "plugins": {
        "formatter": {
          "enabled": true
        }
      },
      "enabledPlugins": {
        "formatter@official": true
      },
      "extraKnownMarketplaces": {
        "official": {
          "source": {
            "type": "github",
            "repo": "anthropic/plugins"
          }
        }
      },
      "channelsEnabled": true,
      "pluginConfigs": {
        "formatter": {
          "enabled": true
        }
      },
      "statusLine": {
        "type": "command",
        "command": "status",
        "padding": 1
      },
      "worktree": {
        "sparsePaths": ["Sources/**"]
      },
      "memory": {
        "maxEntries": 20
      },
      "futureSetting": "preserved"
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

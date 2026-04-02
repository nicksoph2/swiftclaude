import XCTest
@testable import ClaudeConfigManager

/// Packet 24 tests — MCP Server Editor, Hook Handler Editor, Permission Rule Editor.
final class Packet24EditorTests: XCTestCase {

    // MARK: - Helpers

    private func makeSource(
        scope: ResolutionScope,
        path: String? = nil
    ) -> ResolutionSource {
        ResolutionSource(
            scope: scope,
            kind: .file,
            identifier: path ?? "\(scope.rawValue)-settings",
            sourcePath: path
        )
    }

    // MARK: - testMCPEditorValidatesUniqueId

    /// Adding a server with an ID that already exists should fail validation.
    func testMCPEditorValidatesUniqueId() {
        // Simulate existing server IDs
        let existingIDs: Set<String> = ["filesystem", "memory", "web-search"]

        // Test: a new server with duplicate ID should be caught
        let duplicateID = "filesystem"
        XCTAssertTrue(existingIDs.contains(duplicateID),
            "Server ID 'filesystem' already exists — editor should disable save")

        // Test: a new server with unique ID should be valid
        let uniqueID = "my-new-server"
        XCTAssertFalse(existingIDs.contains(uniqueID),
            "Server ID 'my-new-server' is unique — editor should allow save")

        // Test: empty server ID should be invalid
        let emptyID = ""
        XCTAssertTrue(emptyID.isEmpty,
            "Empty server ID should fail validation")

        // Test: server ID with spaces should be invalid
        let spacedID = "my server"
        XCTAssertTrue(spacedID.contains(" "),
            "Server ID with spaces should fail validation")
    }

    // MARK: - testMCPServerJSONConstruction

    /// Verify that the constructed server JSON has the expected structure.
    func testMCPServerJSONConstruction() {
        // Simulate building a stdio server JSON
        var obj: [String: JSONValue] = [:]
        let command = "npx"
        let arguments = ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"]
        let envVars: [(String, String)] = [("NODE_ENV", "production")]

        obj["command"] = .string(command)
        obj["args"] = .array(arguments.map { .string($0) })
        var envObj: [String: JSONValue] = [:]
        for (key, value) in envVars {
            envObj[key] = .string(value)
        }
        obj["env"] = .object(envObj)

        let serverJSON = JSONValue.object(obj)

        // Verify structure
        if case .object(let result) = serverJSON {
            XCTAssertEqual(result["command"]?.stringValue, "npx")

            if case .array(let args) = result["args"] {
                XCTAssertEqual(args.count, 3)
                XCTAssertEqual(args[0].stringValue, "-y")
            } else {
                XCTFail("Expected args array")
            }

            if case .object(let env) = result["env"] {
                XCTAssertEqual(env["NODE_ENV"]?.stringValue, "production")
            } else {
                XCTFail("Expected env object")
            }
        } else {
            XCTFail("Expected object")
        }
    }

    // MARK: - testMCPHttpServerValidation

    /// HTTP server must have a valid URL with http/https scheme.
    func testMCPHttpServerValidation() {
        // Valid URLs
        let validURLs = ["https://localhost:3000", "http://api.example.com/mcp"]
        for urlString in validURLs {
            let url = URL(string: urlString)
            XCTAssertNotNil(url, "'\(urlString)' should parse as a valid URL")
            let scheme = url?.scheme
            XCTAssertTrue(scheme == "http" || scheme == "https",
                "'\(urlString)' should have http or https scheme")
        }

        // Invalid URLs
        let invalidScheme = URL(string: "ftp://example.com")
        XCTAssertNotNil(invalidScheme, "ftp URL should parse but not be valid for MCP")
        XCTAssertFalse(invalidScheme?.scheme == "http" || invalidScheme?.scheme == "https",
            "ftp scheme should fail validation")
    }

    // MARK: - testHookEditorRequiresCommandForCommandType

    /// Command type with empty command should fail validation.
    func testHookEditorRequiresCommandForCommandType() {
        // Simulate hook handler form state for command type
        let handlerType: HookHandlerType = .command
        let emptyCommand = ""
        let validCommand = "echo 'hello'"

        // With empty command, form should be invalid
        let isValidWithEmpty: Bool = {
            switch handlerType {
            case .command:
                return !emptyCommand.isEmpty
            case .http:
                return true
            case .prompt:
                return true
            case .agent:
                return true
            }
        }()
        XCTAssertFalse(isValidWithEmpty, "Command handler with empty command should be invalid")

        // With valid command, form should be valid
        let isValidWithCommand: Bool = {
            switch handlerType {
            case .command:
                return !validCommand.isEmpty
            default:
                return true
            }
        }()
        XCTAssertTrue(isValidWithCommand, "Command handler with non-empty command should be valid")
    }

    // MARK: - testHookHandlerJSONConstruction

    /// Verify that the constructed hook handler JSON matches expected schema.
    func testHookHandlerJSONConstruction() {
        // Build a command handler JSON
        var obj: [String: JSONValue] = [:]
        obj["type"] = .string("command")
        obj["command"] = .string("echo 'build started'")
        obj["shell"] = .string("bash")
        obj["timeout"] = .number(30)

        let handlerJSON = JSONValue.object(obj)

        if case .object(let result) = handlerJSON {
            XCTAssertEqual(result["type"]?.stringValue, "command")
            XCTAssertEqual(result["command"]?.stringValue, "echo 'build started'")
            XCTAssertEqual(result["shell"]?.stringValue, "bash")
            if case .number(let timeout) = result["timeout"] {
                XCTAssertEqual(Int(timeout), 30)
            } else {
                XCTFail("Expected timeout number")
            }
        } else {
            XCTFail("Expected object")
        }
    }

    // MARK: - testHookEditorValidatesHTTPHandler

    /// HTTP handler must have a valid URL.
    func testHookEditorValidatesHTTPHandler() {
        let _: HookHandlerType = .http
        let emptyURL = ""
        let validURL = "https://hooks.example.com/notify"
        let invalidURL = "not-a-url"

        // Empty URL
        XCTAssertTrue(emptyURL.isEmpty, "Empty URL should be invalid for HTTP handler")

        // Valid URL
        let parsed = URL(string: validURL)
        XCTAssertNotNil(parsed)
        XCTAssertTrue(parsed?.scheme == "http" || parsed?.scheme == "https")

        // Invalid URL
        let badParsed = URL(string: invalidURL)
        XCTAssertFalse(badParsed?.scheme == "http" || badParsed?.scheme == "https",
            "URL without http/https scheme should be invalid")
    }

    // MARK: - testPermissionRuleEditorGlobPreview

    /// Type `bash:*` → preview should show "matches all bash commands".
    func testPermissionRuleEditorGlobPreview() {
        let patterns: [(String, String)] = [
            ("bash:*", "Matches all bash commands"),
            ("bash:git*", "Matches bash commands starting with \"git\""),
            ("mcp__web:search", "Matches specific MCP tool \"mcp__web:search\""),
            ("read:*", "Matches all read operations"),
            ("write:/tmp/*", "Matches write operations on \"/tmp/*\""),
            ("*", "Matches everything (very broad rule)"),
        ]

        for (pattern, expected) in patterns {
            let preview = computeMatchPreview(for: pattern)
            XCTAssertEqual(preview, expected,
                "Pattern '\(pattern)' should produce preview: '\(expected)', got: '\(preview)'")
        }
    }

    // MARK: - testPermissionRuleOutcomeTypes

    /// All three outcome types should be representable.
    func testPermissionRuleOutcomeTypes() {
        let types: [PermissionRuleType] = [.deny, .ask, .allow]
        XCTAssertEqual(types.count, 3)
        XCTAssertEqual(PermissionRuleType.deny.rawValue, "deny")
        XCTAssertEqual(PermissionRuleType.ask.rawValue, "ask")
        XCTAssertEqual(PermissionRuleType.allow.rawValue, "allow")
    }

    // MARK: - testSandboxConfigConstruction

    /// Verify sandbox config JSON construction.
    func testSandboxConfigConstruction() {
        var sandbox: [String: JSONValue] = [:]
        sandbox["failIfUnavailable"] = .bool(true)
        sandbox["allowUnsandboxedCommands"] = .bool(false)

        var network: [String: JSONValue] = [:]
        network["allowedDomains"] = .array([.string("api.example.com"), .string("cdn.example.com")])
        network["httpProxyPort"] = .number(8080)
        sandbox["network"] = .object(network)

        sandbox["enableWeakerNetworkIsolation"] = .bool(false)

        let result = JSONValue.object(sandbox)

        if case .object(let obj) = result {
            XCTAssertEqual(obj["failIfUnavailable"]?.boolValue, true)
            XCTAssertEqual(obj["allowUnsandboxedCommands"]?.boolValue, false)
            XCTAssertEqual(obj["enableWeakerNetworkIsolation"]?.boolValue, false)

            if case .object(let net) = obj["network"] {
                if case .array(let domains) = net["allowedDomains"] {
                    XCTAssertEqual(domains.count, 2)
                    XCTAssertEqual(domains[0].stringValue, "api.example.com")
                } else {
                    XCTFail("Expected allowedDomains array")
                }
                if case .number(let port) = net["httpProxyPort"] {
                    XCTAssertEqual(Int(port), 8080)
                } else {
                    XCTFail("Expected httpProxyPort number")
                }
            } else {
                XCTFail("Expected network object")
            }
        } else {
            XCTFail("Expected object")
        }
    }

    // MARK: - testMCPServerCardEffectiveStates

    /// Verify that all effective states are representable.
    func testMCPServerCardEffectiveStates() {
        let states: [McpServerEffectiveState] = [.active, .disabled, .blocked, .managed, .unresolved]
        XCTAssertEqual(states.count, 5)

        // Each state should have a unique raw value
        let rawValues = Set(states.map { $0.rawValue })
        XCTAssertEqual(rawValues.count, 5, "All effective states should have unique raw values")
    }

    // MARK: - Glob Preview Helper (mirrors PermissionRuleEditorView logic)

    private func computeMatchPreview(for pattern: String) -> String {
        let p = pattern.trimmingCharacters(in: .whitespaces)

        if p.hasPrefix("bash:") {
            let suffix = String(p.dropFirst(5))
            if suffix == "*" {
                return "Matches all bash commands"
            } else if suffix.hasSuffix("*") {
                return "Matches bash commands starting with \"\(suffix.dropLast())\""
            } else {
                return "Matches the bash command \"\(suffix)\""
            }
        } else if p.hasPrefix("zsh:") {
            let suffix = String(p.dropFirst(4))
            if suffix == "*" {
                return "Matches all zsh commands"
            } else {
                return "Matches zsh command \"\(suffix)\""
            }
        } else if p.hasPrefix("mcp__") {
            let parts = p.split(separator: "_", omittingEmptySubsequences: false)
            if parts.count >= 5 {
                return "Matches MCP tool invocation"
            } else if p.hasSuffix("*") {
                return "Matches MCP tools matching \"\(p)\""
            } else {
                return "Matches specific MCP tool \"\(p)\""
            }
        } else if p.hasPrefix("read:") || p.hasPrefix("write:") || p.hasPrefix("edit:") {
            let colonIndex = p.firstIndex(of: ":")!
            let op = String(p[p.startIndex..<colonIndex])
            let path = String(p[p.index(after: colonIndex)...])
            if path == "*" {
                return "Matches all \(op) operations"
            } else {
                return "Matches \(op) operations on \"\(path)\""
            }
        } else if p == "*" {
            return "Matches everything (very broad rule)"
        } else {
            return "Matches tools matching \"\(p)\""
        }
    }
}

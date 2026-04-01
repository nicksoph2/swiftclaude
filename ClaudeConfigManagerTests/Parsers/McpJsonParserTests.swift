import XCTest
@testable import ClaudeConfigManager

final class McpJsonParserTests: XCTestCase {
    private let parser = ClaudeJsonParser()
    private let sourceURL = URL(fileURLWithPath: "/tmp/project/.mcp.json", isDirectory: false)

    func testParseFixtureValidCommandAndURLServersViaMcpSurface() throws {
        let loader = FixtureLoader.shared
        let mcpObject = try loader.loadString(
            familyPath: "parsers/mcp_json",
            caseID: "valid_command_and_url",
            section: "input",
            fileName: ".mcp.json"
        )
        let wrapped = wrapAsClaudeJsonMcpLocal(mcpObject)

        let result = parser.parse(jsonString: wrapped, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)
        let local = try XCTUnwrap(document.value.mcpState?.localServers)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(Array(local.keys).sorted(), ["filesystem", "notes"])
        XCTAssertEqual(local["filesystem"]?.command, "npx")
        XCTAssertEqual(local["filesystem"]?.args ?? [], ["-y", "@modelcontextprotocol/server-filesystem"])
        XCTAssertEqual(local["filesystem"]?.env?["HOME"], "/Users/test")
        XCTAssertEqual(local["filesystem"]?.transportType, .stdio)
        XCTAssertEqual(local["filesystem"]?.serverSource, .mcpJson(path: "/tmp/project/.mcp.json"))
        XCTAssertEqual(local["notes"]?.url, "http://127.0.0.1:7777")
        XCTAssertEqual(local["notes"]?.headers?["Authorization"], "Bearer token")
        XCTAssertEqual(local["notes"]?.transportType, .http)
        XCTAssertEqual(local["notes"]?.enabled, true)
        XCTAssertEqual(local["notes"]?.rawObject["futureField"], .string("preserved"))
    }

    func testParseFixtureInvalidShapeAndTypesIncludesExpectedIssueCodes() throws {
        let loader = FixtureLoader.shared
        let mcpObject = try loader.loadString(
            familyPath: "parsers/mcp_json",
            caseID: "invalid_shape_and_types",
            section: "input",
            fileName: ".mcp.json"
        )
        let expected = try loader.loadExpectedIssueSet(
            familyPath: "parsers/mcp_json",
            caseID: "invalid_shape_and_types",
            fileName: "parser_issues.json"
        )
        let wrapped = wrapAsClaudeJsonMcpLocal(mcpObject)

        let result = parser.parse(jsonString: wrapped, sourceURL: sourceURL)
        XCTAssertTrue(result.hasErrors)

        let issueCodes = Set(result.issues.map(\.code.rawValue))
        for code in expected.codes {
            XCTAssertTrue(issueCodes.contains(code))
        }
        XCTAssertTrue(result.issues.contains(where: { $0.keyPath == "mcp.local.broken" }))
        XCTAssertTrue(result.issues.contains(where: { $0.keyPath == "mcp.local.tool.command" }))
        XCTAssertTrue(result.issues.contains(where: { $0.keyPath == "mcp.local.tool.args[1]" }))
        XCTAssertTrue(result.issues.contains(where: { $0.keyPath == "mcp.local.tool.env.HOME" }))
    }

    func testParseFixtureValidMcpTransportsIncludesDeprecatedSse() throws {
        let loader = FixtureLoader.shared
        let mcpObject = try loader.loadString(
            familyPath: "parsers/mcp_json",
            caseID: "valid_mcp_transports",
            section: "input",
            fileName: ".mcp.json"
        )
        let expected = try loader.loadExpectedIssueSet(
            familyPath: "parsers/mcp_json",
            caseID: "valid_mcp_transports",
            fileName: "parser_issues.json"
        )
        let wrapped = wrapAsClaudeJsonMcpLocal(mcpObject)

        let result = parser.parse(jsonString: wrapped, sourceURL: sourceURL)
        let local = try XCTUnwrap(result.value?.value.mcpState?.localServers)

        XCTAssertEqual(local["github"]?.transportType, .stdio)
        XCTAssertEqual(local["github"]?.cwd, "/tmp/project")
        XCTAssertEqual(local["remote-api"]?.transportType, .http)
        XCTAssertEqual(local["legacy-sse"]?.transportType, .sse)
        let issueCodes = Set(result.issues.map(\.code.rawValue))
        for code in expected.codes {
            XCTAssertTrue(issueCodes.contains(code))
        }
    }

    func testParseFixtureInvalidMcpTransportsWarnsForEmptyAndAmbiguousDefinitions() throws {
        let loader = FixtureLoader.shared
        let mcpObject = try loader.loadString(
            familyPath: "parsers/mcp_json",
            caseID: "invalid_mcp_transports",
            section: "input",
            fileName: ".mcp.json"
        )
        let expected = try loader.loadExpectedIssueSet(
            familyPath: "parsers/mcp_json",
            caseID: "invalid_mcp_transports",
            fileName: "parser_issues.json"
        )
        let wrapped = wrapAsClaudeJsonMcpLocal(mcpObject)

        let result = parser.parse(jsonString: wrapped, sourceURL: sourceURL)
        let local = try XCTUnwrap(result.value?.value.mcpState?.localServers)

        XCTAssertEqual(local["empty"]?.transportType, .unknown)
        XCTAssertEqual(local["ambiguous"]?.transportType, .stdio)
        let issueCodes = Set(result.issues.map(\.code.rawValue))
        for code in expected.codes {
            XCTAssertTrue(issueCodes.contains(code))
        }
    }

    private func wrapAsClaudeJsonMcpLocal(_ localServersObjectJSON: String) -> String {
        """
        {
          "mcp": {
            "local": \(localServersObjectJSON)
          }
        }
        """
    }
}

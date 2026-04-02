import XCTest
@testable import ClaudeConfigManager

final class MCPServerHealthCheckerTests: XCTestCase {
    private let checker = MCPServerHealthChecker()

    // MARK: - Helpers

    private func makeServer(
        id: String,
        config: [String: JSONValue],
        state: McpServerEffectiveState = .active
    ) -> ResolvedMcpServerEntry {
        let source = ResolutionSource(
            scope: .user,
            kind: .file,
            identifier: id,
            displayName: id,
            sourcePath: "~/.claude.json"
        )
        return ResolvedMcpServerEntry(
            serverID: id,
            resolvedConfig: ResolvedValue(
                effectiveValue: .object(config),
                winningSource: source,
                trace: ResolutionTrace(participants: [source]),
                mergeMethod: .selectHighestPrecedence
            ),
            effectiveState: state,
            stateExplanation: ""
        )
    }

    // MARK: - stdio: command not found

    func testAbsoluteCommandNotFoundEmitsError() {
        let server = makeServer(
            id: "broken-stdio",
            config: [
                "command": .string("/nonexistent/path/to/binary"),
                "args": .array([])
            ]
        )

        let issues = checker.check([server])

        XCTAssertFalse(issues.isEmpty, "Expected at least one health issue")
        let issue = issues.first!
        XCTAssertEqual(issue.serverId, "broken-stdio")
        if case .commandNotFound(let path) = issue.code {
            XCTAssertEqual(path, "/nonexistent/path/to/binary")
        } else {
            XCTFail("Expected .commandNotFound, got \(issue.code)")
        }
    }

    // MARK: - http: invalid URL scheme

    func testHttpUrlInvalidSchemeEmitsError() {
        let server = makeServer(
            id: "bad-url-server",
            config: [
                "url": .string("ftp://server.example.com/api"),
                "type": .string("http")
            ]
        )

        let issues = checker.check([server])

        XCTAssertFalse(issues.isEmpty, "Expected an invalid URL issue")
        let issue = issues.first!
        XCTAssertEqual(issue.serverId, "bad-url-server")
        if case .invalidUrl(let url) = issue.code {
            XCTAssertEqual(url, "ftp://server.example.com/api")
        } else {
            XCTFail("Expected .invalidUrl, got \(issue.code)")
        }
    }

    // MARK: - http: valid URL

    func testValidHttpUrlNoIssue() {
        let server = makeServer(
            id: "good-http",
            config: [
                "url": .string("https://server.example.com"),
                "type": .string("http")
            ]
        )

        let issues = checker.check([server])

        XCTAssertTrue(issues.isEmpty, "Expected no health issues for valid https URL, got: \(issues)")
    }

    // MARK: - stdio: missing command

    func testMissingCommandForStdioEmitsError() {
        // A server with type=stdio but no command field.
        // The detector sees no "command" key and no "url" key,
        // but type=stdio triggers the stdio path.
        let server = makeServer(
            id: "no-cmd",
            config: [
                "type": .string("stdio"),
                "args": .array([.string("--verbose")])
            ]
        )

        let issues = checker.check([server])

        XCTAssertFalse(issues.isEmpty, "Expected a missing-required-field issue")
        let issue = issues.first!
        XCTAssertEqual(issue.serverId, "no-cmd")
        if case .missingRequiredField(let field) = issue.code {
            XCTAssertEqual(field, "command")
        } else {
            XCTFail("Expected .missingRequiredField(command), got \(issue.code)")
        }
        XCTAssertEqual(issue.severity, .error)
    }

    // MARK: - Multiple servers

    func testMultipleServersReturnsIssuesForEach() {
        let good = makeServer(
            id: "good",
            config: ["url": .string("https://ok.example.com")]
        )
        let bad = makeServer(
            id: "bad",
            config: ["command": .string("/does/not/exist")]
        )

        let issues = checker.check([good, bad])

        XCTAssertEqual(issues.filter { $0.serverId == "good" }.count, 0)
        XCTAssertTrue(issues.contains { $0.serverId == "bad" })
    }

    // MARK: - SyntaxIssue conversion

    func testAsSyntaxIssuesConvertsCorrectly() {
        let healthIssues = [
            MCPHealthIssue(
                serverId: "test-server",
                severity: .warning,
                code: .commandNotFound(path: "/bin/missing"),
                message: "Command '/bin/missing' not found on disk or PATH"
            )
        ]

        let syntaxIssues = MCPServerHealthChecker.asSyntaxIssues(healthIssues, sourcePath: "~/.claude.json")

        XCTAssertEqual(syntaxIssues.count, 1)
        let si = syntaxIssues[0]
        XCTAssertEqual(si.code, .mcpCommandNotFound)
        XCTAssertEqual(si.severity, .warning)
        XCTAssertEqual(si.keyPath, "mcpServers.test-server")
        XCTAssertTrue(si.message.contains("test-server"))
    }
}

import XCTest
@testable import ClaudeConfigManager

final class AgentParserTests: XCTestCase {
    private let parser = AgentParser()
    private let sourceURL = URL(fileURLWithPath: "/tmp/.claude/agents/reviewer.md", isDirectory: false)

    func testParseValidAgentWithFrontmatterAndBody() throws {
        let result = parser.parse(markdownString: AgentParserFixtures.validAgent, sourceURL: sourceURL)

        XCTAssertFalse(result.hasErrors)
        let document = try XCTUnwrap(result.value)
        let frontmatter = try XCTUnwrap(document.frontmatter)
        XCTAssertEqual(frontmatter.name, "reviewer")
        XCTAssertEqual(frontmatter.description, "Reviews pull requests")
        XCTAssertEqual(frontmatter.tools.map(\.rawValue), ["Read", "Bash(git status)"])
        XCTAssertEqual(frontmatter.unknownFields["mcpServers"], .array([.string("github")]))
        XCTAssertEqual(document.promptBody, "You are a careful reviewer.\nProvide concise feedback.")
    }

    func testParseBodyOnlyAgentWhenFrontmatterIsMissing() throws {
        let result = parser.parse(markdownString: AgentParserFixtures.bodyOnlyAgent, sourceURL: sourceURL)

        XCTAssertFalse(result.hasErrors)
        let document = try XCTUnwrap(result.value)
        XCTAssertNil(document.frontmatter)
        XCTAssertNil(document.rawFrontmatter)
        XCTAssertEqual(document.promptBody, AgentParserFixtures.bodyOnlyAgent)
    }

    func testParseMissingClosingFenceProducesDiagnosticAndPreservesBody() throws {
        let result = parser.parse(markdownString: AgentParserFixtures.missingClosingFence, sourceURL: sourceURL)

        let document = try XCTUnwrap(result.value)
        XCTAssertTrue(result.hasErrors)
        XCTAssertTrue(result.issues.contains(where: { $0.code == .invalidFrontmatterFence }))
        XCTAssertNil(document.frontmatter)
        XCTAssertEqual(document.promptBody, AgentParserFixtures.missingClosingFence)
    }

    func testParseMalformedFrontmatterProducesDiagnostic() throws {
        let result = parser.parse(markdownString: AgentParserFixtures.malformedFrontmatter, sourceURL: sourceURL)

        let document = try XCTUnwrap(result.value)
        XCTAssertTrue(result.hasErrors)
        XCTAssertTrue(result.issues.contains(where: { $0.code == .invalidYAMLFrontmatter }))
        XCTAssertEqual(document.promptBody, "Prompt body")
    }

    func testParseTopLevelNonObjectFrontmatterProducesDiagnostic() throws {
        let result = parser.parse(markdownString: AgentParserFixtures.topLevelListFrontmatter, sourceURL: sourceURL)

        let document = try XCTUnwrap(result.value)
        XCTAssertTrue(result.hasErrors)
        XCTAssertTrue(result.issues.contains(where: { $0.code == .frontmatterTopLevelNotObject }))
        XCTAssertNil(document.frontmatter)
        XCTAssertEqual(document.promptBody, "Body text")
    }

    func testParseKnownFieldTypeMismatchProducesDiagnosticsWithRecovery() throws {
        let result = parser.parse(markdownString: AgentParserFixtures.typeMismatchFields, sourceURL: sourceURL)

        let document = try XCTUnwrap(result.value)
        let frontmatter = try XCTUnwrap(document.frontmatter)
        XCTAssertTrue(result.hasErrors)
        XCTAssertTrue(result.issues.contains(where: { $0.code == .typeMismatch && $0.keyPath == "name" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .typeMismatch && $0.keyPath == "description" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .typeMismatch && $0.keyPath == "tools[1]" }))
        XCTAssertEqual(frontmatter.tools.map(\.rawValue), ["Read", "Bash"])
        XCTAssertEqual(document.promptBody, "Prompt body")
    }

    func testParseFrontmatterWithCRLFKeepsPromptBodyAndParsesFields() throws {
        let result = parser.parse(markdownString: AgentParserFixtures.crlfFrontmatter, sourceURL: sourceURL)

        XCTAssertFalse(result.hasErrors)
        let document = try XCTUnwrap(result.value)
        let frontmatter = try XCTUnwrap(document.frontmatter)
        XCTAssertEqual(frontmatter.name, "reviewer")
        XCTAssertEqual(frontmatter.tools.map(\.rawValue), ["Read", "Bash(git status)"])
        XCTAssertEqual(document.promptBody, "Prompt line one.\r\nPrompt line two.")
    }

    func testParseFixtureValidBasicFromCanonicalParserLayout() throws {
        let loader = FixtureLoader.shared
        let markdown = try loader.loadString(
            familyPath: "parsers/agent",
            caseID: "valid_basic",
            section: "input",
            fileName: "agent.md"
        )

        let result = parser.parse(markdownString: markdown, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)
        let frontmatter = try XCTUnwrap(document.frontmatter)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(frontmatter.name, "reviewer")
        XCTAssertEqual(frontmatter.tools.map(\.rawValue), ["Read", "Bash(git status)"])
        XCTAssertEqual(frontmatter.unknownFields["owner"], .string("platform"))
    }

    func testParseFixtureTypeMismatchContainsExpectedIssueCode() throws {
        let loader = FixtureLoader.shared
        let markdown = try loader.loadString(
            familyPath: "parsers/agent",
            caseID: "type_mismatch_fields",
            section: "input",
            fileName: "agent.md"
        )
        let expected = try loader.loadExpectedIssueSet(
            familyPath: "parsers/agent",
            caseID: "type_mismatch_fields",
            fileName: "parser_issues.json"
        )

        let result = parser.parse(markdownString: markdown, sourceURL: sourceURL)
        let issueCodes = Set(result.issues.map(\.code.rawValue))
        XCTAssertTrue(result.hasErrors)
        for code in expected.codes {
            XCTAssertTrue(issueCodes.contains(code))
        }
        XCTAssertEqual(result.issues.first?.sourcePath, sourceURL.path)
    }
}

private enum AgentParserFixtures {
    static let validAgent = """
    ---
    name: reviewer
    description: Reviews pull requests
    tools:
      - Read
      - Bash(git status)
    mcpServers: [github]
    ---
    You are a careful reviewer.
    Provide concise feedback.
    """

    static let bodyOnlyAgent = """
    You are an agent with no frontmatter.
    """

    static let missingClosingFence = """
    ---
    name: broken
    description: Missing close fence
    Prompt starts here unexpectedly.
    """

    static let malformedFrontmatter = """
    ---
    name reviewer
    tools:
      - Read
    ---
    Prompt body
    """

    static let topLevelListFrontmatter = """
    ---
    - reviewer
    - helper
    ---
    Body text
    """

    static let typeMismatchFields = """
    ---
    name: [reviewer]
    description: 42
    tools:
      - Read
      - 123
      - Bash
    ---
    Prompt body
    """

    static let crlfFrontmatter = """
    ---
    name: reviewer
    tools:
      - Read
      - Bash(git status)
    ---
    Prompt line one.
    Prompt line two.
    """.replacingOccurrences(of: "\n", with: "\r\n")
}

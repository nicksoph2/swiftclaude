import XCTest
@testable import ClaudeConfigManager

final class ClaudeMdParserTests: XCTestCase {
    private let parser = ClaudeMdParser()
    private let sourceURL = URL(fileURLWithPath: "/tmp/CLAUDE.md", isDirectory: false)

    func testParseFixtureValidMultipleImportsPreservesOrderingAndDuplicates() throws {
        let loader = FixtureLoader.shared
        let markdown = try loader.loadString(
            familyPath: "parsers/claude_md",
            caseID: "valid_multiple_imports",
            section: "input",
            fileName: "CLAUDE.md"
        )

        let result = parser.parse(markdown: markdown, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)

        XCTAssertFalse(result.hasErrors)
        XCTAssertEqual(document.rawBody, markdown)
        XCTAssertEqual(document.imports.count, 3)
        XCTAssertEqual(document.imports.map(\.rawPath), ["docs/a.md", "docs/b.md", "docs/a.md"])
        XCTAssertEqual(document.imports.map(\.status), [.valid, .valid, .valid])
        XCTAssertEqual(document.imports.map { $0.range?.startLine }, [3, 5, 6])
    }

    func testParseFixtureMixedValidAndInvalidTokensProducesExpectedIssueCode() throws {
        let loader = FixtureLoader.shared
        let markdown = try loader.loadString(
            familyPath: "parsers/claude_md",
            caseID: "mixed_valid_invalid_tokens",
            section: "input",
            fileName: "CLAUDE.md"
        )
        let expected = try loader.loadExpectedIssueSet(
            familyPath: "parsers/claude_md",
            caseID: "mixed_valid_invalid_tokens",
            fileName: "parser_issues.json"
        )

        let result = parser.parse(markdown: markdown, sourceURL: sourceURL)
        let document = try XCTUnwrap(result.value)

        XCTAssertFalse(result.issues.isEmpty, "Expected warning-level issues for malformed tokens")
        XCTAssertEqual(document.imports.map(\.status), [.valid, .malformed, .malformed, .valid])
        XCTAssertEqual(document.imports.map(\.rawPath), ["docs/valid.md", nil, nil, "docs/second.md"])

        let issueCodes = Set(result.issues.map(\.code.rawValue))
        for code in expected.codes {
            XCTAssertTrue(issueCodes.contains(code))
        }
        XCTAssertTrue(result.issues.allSatisfy { $0.sourcePath == sourceURL.path })
    }
}

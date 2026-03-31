import XCTest
@testable import ClaudeConfigManager

final class SkillParserTests: XCTestCase {
    private let parser = SkillParser()
    private let skillDirectoryURL = URL(fileURLWithPath: "/tmp/.claude/skills/my-skill", isDirectory: true)

    func testParseValidSkillWithFrontmatterAndReferences() throws {
        let result = parser.parse(skillDirectoryURL: skillDirectoryURL, markdownString: SkillParserFixtures.validSkill)

        XCTAssertFalse(result.hasErrors)
        let document = try XCTUnwrap(result.value)
        XCTAssertTrue(document.directory.hasSkillMarkdown)
        XCTAssertEqual(document.directory.skillMarkdownURL.path, "/tmp/.claude/skills/my-skill/SKILL.md")

        let frontmatter = try XCTUnwrap(document.frontmatter)
        XCTAssertEqual(frontmatter.name, "my-skill")
        XCTAssertEqual(frontmatter.description, "Helps with parser tasks")
        XCTAssertEqual(frontmatter.version, "1.0.0")
        XCTAssertEqual(frontmatter.tags, ["swift", "parsing"])
        XCTAssertEqual(frontmatter.unknownFields["owner"], .string("platform"))

        XCTAssertEqual(document.supportingReferences.count, 4)
        XCTAssertEqual(document.supportingReferences[0].kind, .link)
        XCTAssertEqual(document.supportingReferences[0].normalizedPath, "references/guide.md")
        XCTAssertTrue(document.supportingReferences[0].isParseableLocalFileReference)

        XCTAssertEqual(document.supportingReferences[1].kind, .image)
        XCTAssertEqual(document.supportingReferences[1].normalizedPath, "assets/diagram.png")
        XCTAssertTrue(document.supportingReferences[1].isParseableLocalFileReference)

        XCTAssertEqual(document.supportingReferences[2].normalizedPath, "/tmp/run.sh")
        XCTAssertTrue(document.supportingReferences[2].isParseableLocalFileReference)

        XCTAssertEqual(document.supportingReferences[3].normalizedPath, "https://example.com/spec")
        XCTAssertFalse(document.supportingReferences[3].isParseableLocalFileReference)
    }

    func testParseBodyOnlySkillWhenFrontmatterMissing() throws {
        let result = parser.parse(skillDirectoryURL: skillDirectoryURL, markdownString: SkillParserFixtures.bodyOnlySkill)

        XCTAssertFalse(result.hasErrors)
        let document = try XCTUnwrap(result.value)
        XCTAssertNil(document.frontmatter)
        XCTAssertNil(document.rawFrontmatter)
        XCTAssertEqual(document.body, SkillParserFixtures.bodyOnlySkill)
    }

    func testParseMissingSkillMarkdownProducesDiagnostic() throws {
        let result = parser.parse(skillDirectoryURL: skillDirectoryURL, skillMarkdownData: nil)

        XCTAssertTrue(result.hasErrors)
        let document = try XCTUnwrap(result.value)
        XCTAssertFalse(document.directory.hasSkillMarkdown)
        XCTAssertNil(document.body)
        XCTAssertTrue(result.issues.contains(where: { $0.code == .missingSkillMarkdown }))
    }

    func testParseMissingClosingFenceProducesDiagnosticAndPreservesBody() throws {
        let result = parser.parse(skillDirectoryURL: skillDirectoryURL, markdownString: SkillParserFixtures.missingClosingFence)

        let document = try XCTUnwrap(result.value)
        XCTAssertTrue(result.hasErrors)
        XCTAssertTrue(result.issues.contains(where: { $0.code == .invalidFrontmatterFence }))
        XCTAssertNil(document.frontmatter)
        XCTAssertEqual(document.body, SkillParserFixtures.missingClosingFence)
    }

    func testParseMalformedFrontmatterProducesDiagnostic() throws {
        let result = parser.parse(skillDirectoryURL: skillDirectoryURL, markdownString: SkillParserFixtures.malformedFrontmatter)

        let document = try XCTUnwrap(result.value)
        XCTAssertTrue(result.hasErrors)
        XCTAssertTrue(result.issues.contains(where: { $0.code == .invalidYAMLFrontmatter }))
        XCTAssertEqual(document.body, "Body text")
    }

    func testParseKnownFieldTypeMismatchProducesDiagnosticsWithRecovery() throws {
        let result = parser.parse(skillDirectoryURL: skillDirectoryURL, markdownString: SkillParserFixtures.typeMismatchFrontmatter)

        let document = try XCTUnwrap(result.value)
        let frontmatter = try XCTUnwrap(document.frontmatter)
        XCTAssertTrue(result.hasErrors)
        XCTAssertTrue(result.issues.contains(where: { $0.code == .typeMismatch && $0.keyPath == "name" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .typeMismatch && $0.keyPath == "description" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .typeMismatch && $0.keyPath == "version" }))
        XCTAssertTrue(result.issues.contains(where: { $0.code == .typeMismatch && $0.keyPath == "tags[1]" }))
        XCTAssertEqual(frontmatter.tags, ["swift", "parser"])
    }

    func testParseMalformedMarkdownReferenceTokenProducesDiagnostic() {
        let result = parser.parse(skillDirectoryURL: skillDirectoryURL, markdownString: SkillParserFixtures.malformedReference)

        XCTAssertTrue(result.hasErrors)
        XCTAssertTrue(result.issues.contains(where: { $0.code == .invalidMarkdownReferenceToken }))
    }

    func testParseReferenceNormalizationSupportsAngleBracketsAndRelativeTraversal() throws {
        let result = parser.parse(skillDirectoryURL: skillDirectoryURL, markdownString: SkillParserFixtures.edgeCaseReferences)

        XCTAssertFalse(result.hasErrors)
        let document = try XCTUnwrap(result.value)
        XCTAssertEqual(document.supportingReferences.count, 2)
        XCTAssertEqual(document.supportingReferences[0].normalizedPath, "./references/Guide v1.md")
        XCTAssertTrue(document.supportingReferences[0].isParseableLocalFileReference)
        XCTAssertEqual(document.supportingReferences[1].normalizedPath, "../shared/tool.sh")
        XCTAssertTrue(document.supportingReferences[1].isParseableLocalFileReference)
    }
}

private enum SkillParserFixtures {
    static let validSkill = """
    ---
    name: my-skill
    description: Helps with parser tasks
    version: 1.0.0
    tags:
      - swift
      - parsing
    owner: platform
    ---
    See [Guide](references/guide.md).
    ![Diagram](assets/diagram.png)
    Run [Script](/tmp/run.sh)
    External [Spec](https://example.com/spec)
    """

    static let bodyOnlySkill = """
    # Skill Body
    Use [Reference](references/readme.md)
    """

    static let missingClosingFence = """
    ---
    name: broken
    description: Missing close fence
    This should remain body text.
    """

    static let malformedFrontmatter = """
    ---
    name my-skill
    tags:
      - parser
    ---
    Body text
    """

    static let typeMismatchFrontmatter = """
    ---
    name: [my-skill]
    description: 42
    version: [1, 0]
    tags:
      - swift
      - 9
      - parser
    ---
    Body text
    """

    static let malformedReference = """
    ---
    name: malformed-ref
    ---
    Missing close [Guide](references/guide.md
    """

    static let edgeCaseReferences = """
    ---
    name: edge-cases
    ---
    [One](<./references/Guide v1.md>)
    [Two](../shared/tool.sh)
    """
}

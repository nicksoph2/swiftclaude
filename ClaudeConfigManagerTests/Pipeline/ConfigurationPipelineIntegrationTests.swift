import XCTest
@testable import ClaudeConfigManager

/// Integration tests that feed real fixture files through the full pipeline
/// and assert that resolver output is non-empty, correct, and carries proper provenance.
///
/// These tests exercise Discovery → Parsing → Resolver Input Building → Resolution → Projection
/// end-to-end, with no mocks. The fixture directory structure mirrors a real workspace:
///
///   multi_scope_basic/
///     user_root/           ← globalRootURL (user-scope settings + CLAUDE.md)
///     project_root/        ← projectRootURL (project + project-local settings, MCP, agents, CLAUDE.md)
///
@MainActor
final class ConfigurationPipelineIntegrationTests: XCTestCase {

    // MARK: - Fixture Paths

    /// Root of the multi-scope fixture directory, resolved via #filePath at compile time.
    private static let fixtureRoot: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()            // Pipeline/
            .deletingLastPathComponent()            // ClaudeConfigManagerTests/
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("Pipeline", isDirectory: true)
            .appendingPathComponent("multi_scope_basic", isDirectory: true)
    }()

    private static let userRootURL: URL = fixtureRoot.appendingPathComponent("user_root", isDirectory: true)
    private static let projectRootURL: URL = fixtureRoot.appendingPathComponent("project_root", isDirectory: true)

    // MARK: - Shared Pipeline

    private var pipeline: ConfigurationPipeline!

    override func setUp() async throws {
        try await super.setUp()
        pipeline = ConfigurationPipeline()
        await pipeline.run(
            globalRootURL: Self.userRootURL,
            projectRootURLs: [Self.projectRootURL]
        )
    }

    override func tearDown() async throws {
        pipeline = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Find a resolved settings entry by key path.
    private func settingsEntry(for keyPath: String) -> ResolvedSettingsEntry? {
        pipeline.projection?.settings?.entries.first(where: { $0.keyPath == keyPath })
    }

    /// Extract an array of strings from a JSONValue.array of .string elements.
    private func stringArray(from value: JSONValue?) -> [String] {
        guard case .array(let items)? = value else { return [] }
        return items.compactMap { item -> String? in
            guard case .string(let s) = item else { return nil }
            return s
        }
    }

    // MARK: - Test: Resolution Produces Non-Empty Results

    func testResolutionProducesNonEmptyResults() {
        XCTAssertNotNil(pipeline.projection, "Projection should be non-nil after pipeline run")
        let settings = pipeline.projection?.settings
        XCTAssertNotNil(settings, "Settings snapshot should be non-nil")
        XCTAssertFalse(settings!.entries.isEmpty, "Settings entries should not be empty")

        let hasWinningValue = settings!.entries.contains(where: { $0.value.effectiveValue != nil })
        XCTAssertTrue(hasWinningValue, "At least one entry should have a non-nil winningValue")
    }

    // MARK: - Test: User-Scope-Only Key Resolves

    func testUserScopeKeyResolves() {
        // "theme" is defined only in the user settings fixture
        let entry = settingsEntry(for: "theme")
        XCTAssertNotNil(entry, "Entry for 'theme' should exist")

        XCTAssertEqual(
            entry?.value.winningSource?.scope, .user,
            "Winning scope for user-only key 'theme' should be .user"
        )
        XCTAssertEqual(
            entry?.value.effectiveValue, .string("dark"),
            "Winning value for 'theme' should match user settings.json fixture"
        )
    }

    // MARK: - Test: Project Scope Overrides User

    func testProjectScopeOverridesUser() {
        // "timeout" is defined only at project scope
        let timeoutEntry = settingsEntry(for: "timeout")
        XCTAssertNotNil(timeoutEntry, "Entry for 'timeout' should exist")
        XCTAssertEqual(
            timeoutEntry?.value.winningSource?.scope, .project,
            "Winning scope for project-only key 'timeout' should be .project"
        )
        XCTAssertEqual(
            timeoutEntry?.value.effectiveValue, .number(30000),
            "Winning value for 'timeout' should match project settings.json fixture"
        )

        // "model" is defined at user AND project (and project-local).
        // Without project-local, project would beat user. With project-local present,
        // project-local beats both. Either way, user should appear as overridden.
        let modelEntry = settingsEntry(for: "model")
        XCTAssertNotNil(modelEntry, "Entry for 'model' should exist")

        let overriddenScopes = modelEntry?.value.trace.overridden.map(\.scope) ?? []
        XCTAssertTrue(
            overriddenScopes.contains(.user),
            "The provenance chain for 'model' should contain a .user entry with overridden status"
        )
    }

    // MARK: - Test: Project-Local Overrides Project

    func testProjectLocalOverridesProject() {
        // "model" is defined at user, project, AND project-local.
        // project-local (.projectLocal tier=2) should beat project (.projectShared tier=3) and user (tier=4).
        let entry = settingsEntry(for: "model")
        XCTAssertNotNil(entry, "Entry for 'model' should exist")

        XCTAssertEqual(
            entry?.value.winningSource?.scope, .projectLocal,
            "Winning scope for 'model' should be .projectLocal"
        )
        XCTAssertEqual(
            entry?.value.effectiveValue, .string("claude-opus-4-20250115"),
            "Winning value for 'model' should match project-local settings.local.json fixture"
        )

        let overriddenScopes = entry?.value.trace.overridden.map(\.scope) ?? []
        XCTAssertTrue(
            overriddenScopes.contains(.project),
            "The provenance chain should include a .project entry with overridden status"
        )
        XCTAssertTrue(
            overriddenScopes.contains(.user),
            "The provenance chain should include a .user entry with overridden status"
        )
    }

    // MARK: - Test: Array Merge Accumulates Across Scopes

    func testArrayMergeAccumulatesAcrossScopes() {
        // "permissions" is defined at user scope (deny: ["Bash(rm -rf /)", "WebFetch(evil.com)"])
        // and project scope (deny: ["Bash(sudo)", "WebFetch(malware.com)"]).
        // The resolver should merge deny arrays using append-unique.
        let entry = settingsEntry(for: "permissions")
        XCTAssertNotNil(entry, "Entry for 'permissions' should exist")

        guard case .object(let permissionsObj)? = entry?.value.effectiveValue else {
            XCTFail("Permissions effective value should be an object")
            return
        }

        let denyValues = stringArray(from: permissionsObj["deny"])
        XCTAssertTrue(
            denyValues.contains("Bash(rm -rf /)"),
            "Merged deny array should contain user-scope entry 'Bash(rm -rf /)'"
        )
        XCTAssertTrue(
            denyValues.contains("Bash(sudo)"),
            "Merged deny array should contain project-scope entry 'Bash(sudo)'"
        )
        XCTAssertTrue(
            denyValues.contains("WebFetch(evil.com)"),
            "Merged deny array should contain user-scope entry 'WebFetch(evil.com)'"
        )
        XCTAssertTrue(
            denyValues.contains("WebFetch(malware.com)"),
            "Merged deny array should contain project-scope entry 'WebFetch(malware.com)'"
        )

        // The permissions merge uses deepMergeObject method
        XCTAssertEqual(
            entry?.value.mergeMethod, .deepMergeObject,
            "Permissions should use deepMergeObject merge method"
        )
    }

    // MARK: - Test: MCP Candidates Reach Resolver

    func testMcpCandidatesReachResolver() {
        // The project_root/.mcp.json fixture defines a "filesystem" server.
        let mcpSnapshot = pipeline.projection?.mcp
        XCTAssertNotNil(mcpSnapshot, "MCP snapshot should be non-nil")
        XCTAssertFalse(
            mcpSnapshot!.servers.isEmpty,
            "MCP servers should not be empty — the .mcp.json fixture defines at least one server"
        )

        let filesystemServer = mcpSnapshot!.servers.first(where: { $0.serverID == "filesystem" })
        XCTAssertNotNil(filesystemServer, "Should find the 'filesystem' MCP server from fixture")
    }

    // MARK: - Test: No Nil-Document Regression For Settings

    func testNoNilDocumentRegressionForSettings() {
        // For every ParseResultRecord corresponding to a settings.json file,
        // the typed settings document should be non-nil (the Packet 01 fix).
        let settingsRecords = pipeline.parseResults.filter { $0.fileType == .settings }

        XCTAssertFalse(settingsRecords.isEmpty, "Pipeline should have parsed at least one settings file")

        for record in settingsRecords {
            // Only check records where the source file actually exists and was readable
            guard record.parseIssues.allSatisfy({ $0.severity != .error }) else {
                continue
            }
            // Skip records for files that were discovered but not present on disk
            guard record.rawContent != nil || record.parsedSettings != nil else {
                continue
            }
            XCTAssertNotNil(
                record.parsedSettings,
                "ParseResultRecord for settings file '\(record.sourceFile.lastPathComponent)' at scope \(record.scope) should have a non-nil parsedSettings document — this is a regression guard for the Packet 01 nil-document bug"
            )
        }
    }

    // MARK: - Test: No Nil-Document Regression For Agents

    func testNilDocumentRegressionForAgents() {
        // The project_root/.claude/agents/test-agent.md fixture should produce a typed document.
        let agentRecords = pipeline.parseResults.filter { $0.fileType == .agent }

        XCTAssertFalse(agentRecords.isEmpty, "Pipeline should have parsed at least one agent file")

        for record in agentRecords {
            guard record.parseIssues.allSatisfy({ $0.severity != .error }) else {
                continue
            }
            guard record.rawTextContent != nil || record.parsedAgent != nil else {
                continue
            }
            XCTAssertNotNil(
                record.parsedAgent,
                "ParseResultRecord for agent file '\(record.sourceFile.lastPathComponent)' at scope \(record.scope) should have a non-nil parsedAgent document — regression guard for nil-document bug"
            )
        }
    }

    // MARK: - Test: Pipeline Completes Successfully

    func testPipelineCompletesSuccessfully() {
        if case .completed = pipeline.pipelineState {
            XCTAssertTrue(true, "Pipeline completed successfully")
        } else {
            XCTFail("Pipeline should be in .completed state, got \(pipeline.pipelineState)")
        }
    }
}

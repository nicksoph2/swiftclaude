import XCTest
@testable import ClaudeConfigManager

// MARK: - Mock Inspector

/// A mock `ManagedScopeInspecting` that returns a pre-built `ManagedScopeViewModel`.
private struct StubManagedScopeInspector: ManagedScopeInspecting {
    let viewModel: ManagedScopeViewModel

    func inspect() -> ManagedScopeViewModel {
        viewModel
    }
}

// MARK: - Mock Dependencies for ManagedScopeInspector

private struct StubSandboxProbe: SandboxProbing {
    let isRunningInSandbox: Bool
}

private struct StubMDMPolicyReader: MDMPolicyReading {
    let policies: [String: JSONValue]
    let issues: [SyntaxIssue]

    init(policies: [String: JSONValue] = [:], issues: [SyntaxIssue] = []) {
        self.policies = policies
        self.issues = issues
    }

    func readPolicies() -> ParseResult<[String: JSONValue]> {
        let value = policies.isEmpty ? nil : policies
        return ParseResult(value: value, issues: issues)
    }
}

private struct StubManagedFileSystem: ManagedSettingsFileSystem {
    let existsResults: [String: Bool]
    let readableResults: [String: Bool]
    let directoryFlags: [String: Bool]
    let directoryContents: [String: [String]]

    init(
        existsResults: [String: Bool] = [:],
        readableResults: [String: Bool] = [:],
        directoryFlags: [String: Bool] = [:],
        directoryContents: [String: [String]] = [:]
    ) {
        self.existsResults = existsResults
        self.readableResults = readableResults
        self.directoryFlags = directoryFlags
        self.directoryContents = directoryContents
    }

    func fileExists(atPath path: String) -> Bool {
        existsResults[path] ?? false
    }

    func fileExists(atPath path: String, isDirectory: inout ObjCBool) -> Bool {
        let exists = existsResults[path] ?? false
        isDirectory = ObjCBool(directoryFlags[path] ?? false)
        return exists
    }

    func isReadable(atPath path: String) -> Bool {
        readableResults[path] ?? false
    }

    func contentsOfDirectory(atPath path: String, error: inout NSError?) -> [String] {
        directoryContents[path] ?? []
    }
}

// MARK: - Tests

final class ManagedScopeInspectorTests: XCTestCase {

    // MARK: - ViewModel via Stub Inspector

    func testViewModelFromStubInspectorSurfacesAllFields() {
        let status = ManagedScopeStatusModel(resolution: nil, accessOutcome: .missing)
        let tierRows = [
            ManagedScopeViewModel.TierRow(
                title: "Server-managed settings",
                statusStyle: .absent,
                detail: "No server-managed payload.",
                sourceSummary: nil
            )
        ]
        let fileRows = [
            ManagedScopeViewModel.SourceRow(
                title: "managed-settings.json",
                path: "/Library/Application Support/ClaudeCode/managed-settings.json",
                statusStyle: .absent,
                detail: "Not found."
            )
        ]
        let mcpSummary = ManagedScopeViewModel.ManagedMcpSummary(
            statusStyle: .absent,
            detail: "No managed MCP file was found.",
            serverIDs: []
        )
        let claudeMdSummary = ManagedScopeViewModel.ManagedClaudeMdSummary(
            statusStyle: .absent,
            detail: "No managed CLAUDE.md found.",
            content: nil,
            importCount: 0,
            issueMessages: []
        )

        let vm = ManagedScopeViewModel(
            status: status,
            tierRows: tierRows,
            fileSourceRows: fileRows,
            managedMcp: mcpSummary,
            managedClaudeMd: claudeMdSummary,
            notes: ["Test note"]
        )

        XCTAssertEqual(vm.status.activeTierLabel, "none")
        XCTAssertEqual(vm.tierRows.count, 1)
        XCTAssertEqual(vm.fileSourceRows.count, 1)
        XCTAssertEqual(vm.managedMcp.statusStyle, .absent)
        XCTAssertEqual(vm.managedClaudeMd.statusStyle, .absent)
        XCTAssertEqual(vm.notes, ["Test note"])
    }

    // MARK: - Inspector: No Managed Config

    func testInspectorWithNoManagedConfigProducesAbsentTiers() {
        let inspector = makeStubbedInspector(
            fileSystem: noManagedFilesFileSystem(),
            sandboxed: false,
            mdmPolicies: [:]
        )

        let vm = inspector.inspect()

        XCTAssertEqual(vm.status.activeTierLabel, "none")
        XCTAssertEqual(vm.tierRows.count, 3)

        let serverRow = vm.tierRows.first(where: { $0.title.contains("Server") })
        XCTAssertEqual(serverRow?.statusStyle, .absent)

        let mdmRow = vm.tierRows.first(where: { $0.title.contains("MDM") })
        XCTAssertEqual(mdmRow?.statusStyle, .absent)

        let fileRow = vm.tierRows.first(where: { $0.title.contains("File-based") })
        XCTAssertEqual(fileRow?.statusStyle, .absent)
    }

    // MARK: - Inspector: File-Based Managed Settings Active

    func testInspectorWithFileBasedSettingsShowsFileBasedTierActive() {
        let settingsJSON = """
        { "cleanupPeriodDays": 30 }
        """.data(using: .utf8)!

        let inspector = makeStubbedInspector(
            fileSystem: fileBasedManagedFileSystem(),
            sandboxed: false,
            mdmPolicies: [:],
            fileContents: [
                "/Library/Application Support/ClaudeCode/managed-settings.json": settingsJSON
            ]
        )

        let vm = inspector.inspect()

        XCTAssertEqual(vm.status.activeTierLabel, "fileBased")
        XCTAssertEqual(vm.status.detail, "File-based managed settings")

        let fileRow = vm.tierRows.first(where: { $0.title.contains("File-based") })
        XCTAssertEqual(fileRow?.statusStyle, .active)

        let serverRow = vm.tierRows.first(where: { $0.title.contains("Server") })
        XCTAssertEqual(serverRow?.statusStyle, .absent)
    }

    // MARK: - Inspector: MDM Active Suppresses File-Based

    func testInspectorWithMDMActiveShowsFileBasedSuppressed() {
        let settingsJSON = """
        { "cleanupPeriodDays": 30 }
        """.data(using: .utf8)!

        let inspector = makeStubbedInspector(
            fileSystem: fileBasedManagedFileSystem(),
            sandboxed: false,
            mdmPolicies: ["cleanupPeriodDays": .number(60)],
            fileContents: [
                "/Library/Application Support/ClaudeCode/managed-settings.json": settingsJSON
            ]
        )

        let vm = inspector.inspect()

        XCTAssertEqual(vm.status.activeTierLabel, "mdmPolicy")

        let mdmRow = vm.tierRows.first(where: { $0.title.contains("MDM") })
        XCTAssertEqual(mdmRow?.statusStyle, .active)

        let fileRow = vm.tierRows.first(where: { $0.title.contains("File-based") })
        XCTAssertEqual(fileRow?.statusStyle, .suppressed)
    }

    // MARK: - Inspector: Sandbox Restricted

    func testInspectorInSandboxShowsInaccessibleForFileBased() {
        let inspector = makeStubbedInspector(
            fileSystem: noManagedFilesFileSystem(),
            sandboxed: true,
            mdmPolicies: [:]
        )

        let vm = inspector.inspect()

        XCTAssertTrue(vm.status.accessOutcome.requiresExplicitFallbackUI)

        let fileRow = vm.tierRows.first(where: { $0.title.contains("File-based") })
        XCTAssertEqual(fileRow?.statusStyle, .inaccessible)
    }

    // MARK: - Inspector: Managed MCP Present

    func testInspectorWithManagedMcpShowsServers() {
        let settingsJSON = """
        { "cleanupPeriodDays": 30 }
        """.data(using: .utf8)!

        let mcpJSON = """
        { "mcpServers": { "filesystem": { "command": "fs-server" }, "github": { "command": "gh-server" } } }
        """.data(using: .utf8)!

        let inspector = makeStubbedInspector(
            fileSystem: fileBasedManagedFileSystem(mcpPresent: true),
            sandboxed: false,
            mdmPolicies: [:],
            fileContents: [
                "/Library/Application Support/ClaudeCode/managed-settings.json": settingsJSON,
                "/Library/Application Support/ClaudeCode/managed-mcp.json": mcpJSON
            ]
        )

        let vm = inspector.inspect()

        XCTAssertEqual(vm.managedMcp.statusStyle, .available)
        XCTAssertEqual(vm.managedMcp.serverIDs.count, 2)
        XCTAssertTrue(vm.managedMcp.serverIDs.contains("filesystem"))
        XCTAssertTrue(vm.managedMcp.serverIDs.contains("github"))
    }

    // MARK: - Inspector: Managed MCP Absent

    func testInspectorWithoutManagedMcpShowsAbsent() {
        let inspector = makeStubbedInspector(
            fileSystem: noManagedFilesFileSystem(),
            sandboxed: false,
            mdmPolicies: [:]
        )

        let vm = inspector.inspect()

        XCTAssertEqual(vm.managedMcp.statusStyle, .absent)
        XCTAssertTrue(vm.managedMcp.serverIDs.isEmpty)
    }

    // MARK: - Inspector: Managed CLAUDE.md Present

    func testInspectorWithManagedClaudeMdShowsContent() {
        let settingsJSON = """
        { "cleanupPeriodDays": 30 }
        """.data(using: .utf8)!

        let claudeMd = """
        # Managed Instructions
        Always use the approved linter.
        """.data(using: .utf8)!

        let inspector = makeStubbedInspector(
            fileSystem: fileBasedManagedFileSystem(claudeMdPresent: true),
            sandboxed: false,
            mdmPolicies: [:],
            fileContents: [
                "/Library/Application Support/ClaudeCode/managed-settings.json": settingsJSON,
                "/Library/Application Support/ClaudeCode/CLAUDE.md": claudeMd
            ]
        )

        let vm = inspector.inspect()

        XCTAssertEqual(vm.managedClaudeMd.statusStyle, .available)
        XCTAssertNotNil(vm.managedClaudeMd.content)
        XCTAssertTrue(vm.managedClaudeMd.content?.contains("approved linter") ?? false)
    }

    // MARK: - Inspector: Managed CLAUDE.md Absent

    func testInspectorWithoutManagedClaudeMdShowsAbsent() {
        let inspector = makeStubbedInspector(
            fileSystem: noManagedFilesFileSystem(),
            sandboxed: false,
            mdmPolicies: [:]
        )

        let vm = inspector.inspect()

        XCTAssertEqual(vm.managedClaudeMd.statusStyle, .absent)
        XCTAssertNil(vm.managedClaudeMd.content)
    }

    // MARK: - Inspector: Managed CLAUDE.md Inaccessible in Sandbox

    func testInspectorInSandboxShowsClaudeMdInaccessible() {
        let inspector = makeStubbedInspector(
            fileSystem: noManagedFilesFileSystem(),
            sandboxed: true,
            mdmPolicies: [:]
        )

        let vm = inspector.inspect()

        XCTAssertEqual(vm.managedClaudeMd.statusStyle, .inaccessible)
    }

    // MARK: - Inspector: CLAUDE.md with @import tokens

    func testInspectorWithClaudeMdImportsCountsValidImports() {
        let settingsJSON = """
        { "cleanupPeriodDays": 30 }
        """.data(using: .utf8)!

        let claudeMd = """
        # Instructions
        @import ./security-rules.md
        @import ./compliance-rules.md
        Some other instructions here.
        """.data(using: .utf8)!

        let inspector = makeStubbedInspector(
            fileSystem: fileBasedManagedFileSystem(claudeMdPresent: true),
            sandboxed: false,
            mdmPolicies: [:],
            fileContents: [
                "/Library/Application Support/ClaudeCode/managed-settings.json": settingsJSON,
                "/Library/Application Support/ClaudeCode/CLAUDE.md": claudeMd
            ]
        )

        let vm = inspector.inspect()

        XCTAssertEqual(vm.managedClaudeMd.statusStyle, .available)
        XCTAssertEqual(vm.managedClaudeMd.importCount, 2)
    }

    // MARK: - ManagedScopeStatusModel

    func testStatusModelWithNoResolutionShowsNone() {
        let status = ManagedScopeStatusModel(resolution: nil, accessOutcome: .missing)

        XCTAssertEqual(status.activeTierLabel, "none")
        XCTAssertEqual(status.title, "No managed tier active")
        XCTAssertTrue(status.sourceSummaries.isEmpty)
    }

    func testStatusModelWithActiveResolutionShowsTierKind() {
        let source = ResolutionSource(
            scope: .managed,
            kind: .managed,
            identifier: "managed-settings",
            displayName: "managed-settings.json",
            sourcePath: "/Library/Application Support/ClaudeCode/managed-settings.json",
            availability: .present
        )

        let resolution = ManagedSettingsResolution(
            activeTier: ManagedSettingsActiveTier(
                kind: .fileBased,
                sources: [source]
            ),
            settingsCandidates: [],
            managedMcpDocuments: [],
            notes: []
        )

        let status = ManagedScopeStatusModel(resolution: resolution, accessOutcome: .accessible)

        XCTAssertEqual(status.activeTierLabel, "fileBased")
        XCTAssertEqual(status.title, "Active managed tier")
        XCTAssertFalse(status.sourceSummaries.isEmpty)
    }

    // MARK: - ManagedAccessOutcome

    func testAccessOutcomeFallbackUI() {
        XCTAssertFalse(ManagedAccessOutcome.accessible.requiresExplicitFallbackUI)
        XCTAssertFalse(ManagedAccessOutcome.missing.requiresExplicitFallbackUI)
        XCTAssertTrue(ManagedAccessOutcome.sandboxRestricted.requiresExplicitFallbackUI)
        XCTAssertTrue(ManagedAccessOutcome.inaccessible(diagnostics: nil).requiresExplicitFallbackUI)
        XCTAssertTrue(ManagedAccessOutcome.inaccessible(diagnostics: "perm denied").requiresExplicitFallbackUI)
    }

    // MARK: - Discovered File Source Rows

    func testFileRowsIncludeAllExpectedManagedSources() {
        let settingsJSON = """
        { "cleanupPeriodDays": 30 }
        """.data(using: .utf8)!

        let inspector = makeStubbedInspector(
            fileSystem: fileBasedManagedFileSystem(),
            sandboxed: false,
            mdmPolicies: [:],
            fileContents: [
                "/Library/Application Support/ClaudeCode/managed-settings.json": settingsJSON
            ]
        )

        let vm = inspector.inspect()

        let titles = vm.fileSourceRows.map(\.title)
        XCTAssertTrue(titles.contains("managed-settings.json"))
        XCTAssertTrue(titles.contains("managed-mcp.json"))
        XCTAssertTrue(titles.contains("CLAUDE.md"))
    }

    // MARK: - StatusStyle Labels

    func testStatusStyleLabels() {
        XCTAssertEqual(ManagedScopeViewModel.StatusStyle.active.label, "Active")
        XCTAssertEqual(ManagedScopeViewModel.StatusStyle.available.label, "Available")
        XCTAssertEqual(ManagedScopeViewModel.StatusStyle.suppressed.label, "Suppressed")
        XCTAssertEqual(ManagedScopeViewModel.StatusStyle.absent.label, "Absent")
        XCTAssertEqual(ManagedScopeViewModel.StatusStyle.inaccessible.label, "Inaccessible")
    }

    // MARK: - Helpers

    private func makeStubbedInspector(
        fileSystem: StubManagedFileSystem,
        sandboxed: Bool,
        mdmPolicies: [String: JSONValue],
        fileContents: [String: Data] = [:]
    ) -> ManagedScopeInspector {
        let locator = ManagedSettingsLocator(fileSystem: fileSystem)
        let probe = StubSandboxProbe(isRunningInSandbox: sandboxed)
        let mdmReader = StubMDMPolicyReader(policies: mdmPolicies)

        let dataLoader: @Sendable (URL) throws -> Data = { url in
            if let data = fileContents[url.path] {
                return data
            }
            throw NSError(
                domain: "TestDataLoader",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Test file not found: \(url.path)"]
            )
        }

        return ManagedScopeInspector(
            managedSettingsLocator: locator,
            sandboxProbe: probe,
            mdmPolicyReader: mdmReader,
            settingsParser: SettingsParser(),
            claudeJsonParser: ClaudeJsonParser(),
            claudeMdParser: ClaudeMdParser(),
            dataLoader: dataLoader,
            managedSettingsResolver: ManagedSettingsResolver()
        )
    }

    private func noManagedFilesFileSystem() -> StubManagedFileSystem {
        StubManagedFileSystem()
    }

    private func fileBasedManagedFileSystem(
        mcpPresent: Bool = false,
        claudeMdPresent: Bool = false
    ) -> StubManagedFileSystem {
        let root = "/Library/Application Support/ClaudeCode"
        let settings = "\(root)/managed-settings.json"
        let dropInDir = "\(root)/managed-settings.d"
        let mcpPath = "\(root)/managed-mcp.json"
        let claudeMdPath = "\(root)/CLAUDE.md"

        let exists: [String: Bool] = [
            root: true,
            settings: true,
            dropInDir: false,
            mcpPath: mcpPresent,
            claudeMdPath: claudeMdPresent,
        ]

        let readable: [String: Bool] = [
            root: true,
            settings: true,
            mcpPath: mcpPresent,
            claudeMdPath: claudeMdPresent,
        ]

        let dirFlags: [String: Bool] = [
            root: true,
            settings: false,
            dropInDir: false,
            mcpPath: false,
            claudeMdPath: false,
        ]

        return StubManagedFileSystem(
            existsResults: exists,
            readableResults: readable,
            directoryFlags: dirFlags,
            directoryContents: [:]
        )
    }
}

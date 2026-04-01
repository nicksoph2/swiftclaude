import Foundation

/// Result of locating managed configuration files.
struct ManagedScanResult: Equatable, Sendable {
    /// The managed-settings.json file, if present and readable.
    var settingsFile: DiscoveredFile?

    /// Files in managed-settings.d/, sorted lexicographically by filename.
    /// Empty if the directory does not exist.
    var settingsOverrideFiles: [DiscoveredFile]

    /// The managed-mcp.json file, if present and readable.
    var mcpFile: DiscoveredFile?

    /// The CLAUDE.md file in the managed root, if present and readable.
    var claudeMdFile: DiscoveredFile?

    /// MDM-managed preferences from com.anthropic.claudecode, if present.
    var mdmResult: MDMSettingsResult?
}

/// Result of reading MDM-managed settings from the system preference domain.
struct MDMSettingsResult: Equatable, Sendable {
    /// Normalised MDM values keyed by preference key.
    var values: [String: JSONValue]

    /// Description of the source: "MDM (com.anthropic.claudecode)".
    var source: String
}

/// Locates all managed configuration files on disk.
struct ManagedFileLocator {
    private let fileSystem: ManagedSettingsFileSystem
    private let mdmReader: MDMPolicyReading

    init(
        fileSystem: ManagedSettingsFileSystem = DefaultManagedSettingsFileSystem(),
        mdmReader: MDMPolicyReading = MDMPolicyReader()
    ) {
        self.fileSystem = fileSystem
        self.mdmReader = mdmReader
    }

    /// Attempt to locate all managed config files.
    /// Returns a ManagedScanResult regardless of whether files exist.
    func locate() -> ManagedScanResult {
        let locator = ManagedSettingsLocator(fileSystem: fileSystem)
        let snapshot = locator.discoverySnapshot()

        let scope = DiscoveryScopeIdentity.managed()

        var settingsFile: DiscoveredFile?
        if snapshot.settingsFile.status != .missing {
            settingsFile = DiscoveredFile(
                scope: scope,
                kind: .managedSettingsJSON,
                url: snapshot.settingsFile.url,
                provenance: .canonicalExpected,
                status: snapshot.settingsFile.status.discoveryPathStatus
            )
        }

        var mcpFile: DiscoveredFile?
        if snapshot.mcpFile.status != .missing {
            mcpFile = DiscoveredFile(
                scope: scope,
                kind: .managedMcpJSON,
                url: snapshot.mcpFile.url,
                provenance: .canonicalExpected,
                status: snapshot.mcpFile.status.discoveryPathStatus
            )
        }

        var claudeMdFile: DiscoveredFile?
        if snapshot.claudeMdFile.status != .missing {
            claudeMdFile = DiscoveredFile(
                scope: scope,
                kind: .managedClaudeMarkdown,
                url: snapshot.claudeMdFile.url,
                provenance: .canonicalExpected,
                status: snapshot.claudeMdFile.status.discoveryPathStatus
            )
        }

        let settingsOverrideFiles = snapshot.dropInFiles.map { file in
            DiscoveredFile(
                scope: scope,
                kind: .managedSettingsDropIn,
                url: file.url,
                provenance: .canonicalExpected,
                status: file.status.discoveryPathStatus
            )
        }

        // Read MDM preferences
        let mdmResult: MDMSettingsResult?
        let mdmParseResult = mdmReader.readPolicies()
        if let mdmValues = mdmParseResult.value, !mdmValues.isEmpty {
            mdmResult = MDMSettingsResult(
                values: mdmValues,
                source: "MDM (com.anthropic.claudecode)"
            )
        } else {
            mdmResult = nil
        }

        return ManagedScanResult(
            settingsFile: settingsFile,
            settingsOverrideFiles: settingsOverrideFiles,
            mcpFile: mcpFile,
            claudeMdFile: claudeMdFile,
            mdmResult: mdmResult
        )
    }
}

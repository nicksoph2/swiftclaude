import Foundation

// MARK: - Snapshot Model

struct SnapshotProvenanceEntry: Codable, Equatable {
    let scope: String
    let sourcePath: String?
    let value: JSONValue?
}

struct SnapshotSettingsEntry: Codable, Equatable {
    let keyPath: String
    let resolvedValue: JSONValue?
    let redacted: Bool
    let winningScope: String?
    let winningSourcePath: String?
    let provenance: [SnapshotProvenanceEntry]
}

struct SnapshotInstructionsEntry: Codable, Equatable {
    let composedText: String?
    let blockCount: Int
    let winningScope: String?
    let winningSourcePath: String?
}

struct SnapshotMcpEntry: Codable, Equatable {
    let serverID: String
    let winningScope: String?
    let winningSourcePath: String?
    let provenance: [SnapshotProvenanceEntry]
}

struct SnapshotPermissionsEntry: Codable, Equatable {
    let permissionKeyCount: Int
    let entries: [SnapshotSettingsEntry]
}

struct SnapshotHooksEntry: Codable, Equatable {
    let eventCount: Int
    let events: [String]
}

struct ConfigurationSnapshot: Codable, Equatable {
    let exportedAt: Date
    let appVersion: String
    let resolvedSettings: [SnapshotSettingsEntry]
    let resolvedInstructions: SnapshotInstructionsEntry
    let mcpServers: [SnapshotMcpEntry]
    let permissionRules: SnapshotPermissionsEntry
    let hooks: SnapshotHooksEntry
}

// MARK: - Exporter

struct ConfigurationSnapshotExporter {

    // MARK: - Sensitive Key Detection

    static let sensitivePatterns: [String] = [
        "token", "key", "secret", "password"
    ]

    static func isSensitiveKey(_ keyPath: String) -> Bool {
        let lower = keyPath.lowercased()
        if lower.hasPrefix("env.") { return true }
        for pattern in sensitivePatterns {
            if lower.contains(pattern) { return true }
        }
        return false
    }

    // MARK: - Export

    func export(
        _ projection: SessionProjection,
        scanResult: ScanResult
    ) -> ConfigurationSnapshot {
        let settingsEntries = exportSettings(projection.settings)
        let instructionsEntry = exportInstructions(projection.instructions)
        let mcpEntries = exportMcp(projection.mcp)
        let permissionsEntry = exportPermissions(projection.settings)
        let hooksEntry = exportHooks(projection.hooks)

        return ConfigurationSnapshot(
            exportedAt: Date(),
            appVersion: appVersion(),
            resolvedSettings: settingsEntries,
            resolvedInstructions: instructionsEntry,
            mcpServers: mcpEntries,
            permissionRules: permissionsEntry,
            hooks: hooksEntry
        )
    }

    // MARK: - Settings Export

    private func exportSettings(_ settings: ResolvedSettingsSnapshot?) -> [SnapshotSettingsEntry] {
        guard let settings else { return [] }
        return settings.entries.map { entry in
            let isSensitive = Self.isSensitiveKey(entry.keyPath)
            let resolvedValue: JSONValue? = isSensitive ? .string("<redacted>") : entry.value.effectiveValue
            let provenance = buildProvenance(from: entry.value.trace, redact: isSensitive)

            return SnapshotSettingsEntry(
                keyPath: entry.keyPath,
                resolvedValue: resolvedValue,
                redacted: isSensitive,
                winningScope: entry.value.winningSource?.scope.rawValue,
                winningSourcePath: entry.value.winningSource?.sourcePath,
                provenance: provenance
            )
        }
    }

    // MARK: - Instructions Export

    private func exportInstructions(_ instructions: ResolvedInstructionSnapshot?) -> SnapshotInstructionsEntry {
        guard let instructions else {
            return SnapshotInstructionsEntry(
                composedText: nil,
                blockCount: 0,
                winningScope: nil,
                winningSourcePath: nil
            )
        }
        return SnapshotInstructionsEntry(
            composedText: instructions.composedInstructions.effectiveValue,
            blockCount: instructions.orderedBlocks.count,
            winningScope: instructions.composedInstructions.winningSource?.scope.rawValue,
            winningSourcePath: instructions.composedInstructions.winningSource?.sourcePath
        )
    }

    // MARK: - MCP Export

    private func exportMcp(_ mcp: ResolvedMcpSnapshot?) -> [SnapshotMcpEntry] {
        guard let mcp else { return [] }
        return mcp.servers.map { server in
            let provenance = server.resolvedConfig.trace.participants.map { source in
                SnapshotProvenanceEntry(
                    scope: source.scope.rawValue,
                    sourcePath: source.sourcePath,
                    value: nil
                )
            }
            return SnapshotMcpEntry(
                serverID: server.serverID,
                winningScope: server.resolvedConfig.winningSource?.scope.rawValue,
                winningSourcePath: server.resolvedConfig.winningSource?.sourcePath,
                provenance: provenance
            )
        }
    }

    // MARK: - Permissions Export

    private func exportPermissions(_ settings: ResolvedSettingsSnapshot?) -> SnapshotPermissionsEntry {
        guard let settings else {
            return SnapshotPermissionsEntry(permissionKeyCount: 0, entries: [])
        }
        let permissionEntries = settings.entries.filter { isPermissionKey($0.keyPath) }
        let snapshotEntries = permissionEntries.map { entry in
            SnapshotSettingsEntry(
                keyPath: entry.keyPath,
                resolvedValue: entry.value.effectiveValue,
                redacted: false,
                winningScope: entry.value.winningSource?.scope.rawValue,
                winningSourcePath: entry.value.winningSource?.sourcePath,
                provenance: buildProvenance(from: entry.value.trace, redact: false)
            )
        }
        return SnapshotPermissionsEntry(
            permissionKeyCount: snapshotEntries.count,
            entries: snapshotEntries
        )
    }

    // MARK: - Hooks Export

    private func exportHooks(_ hooks: ResolvedHookSnapshot?) -> SnapshotHooksEntry {
        guard let hooks else {
            return SnapshotHooksEntry(eventCount: 0, events: [])
        }
        let eventNames = hooks.events.map { $0.eventType.canonicalName }
        return SnapshotHooksEntry(
            eventCount: hooks.events.count,
            events: eventNames
        )
    }

    // MARK: - Helpers

    private func buildProvenance(from trace: ResolutionTrace, redact: Bool) -> [SnapshotProvenanceEntry] {
        let allSources = trace.participants + trace.overridden
        return allSources.map { source in
            SnapshotProvenanceEntry(
                scope: source.scope.rawValue,
                sourcePath: source.sourcePath,
                value: redact ? .string("<redacted>") : nil
            )
        }
    }

    private func isPermissionKey(_ keyPath: String) -> Bool {
        let lower = keyPath.lowercased()
        return lower.contains("permission") || lower.contains("allow") || lower.contains("deny")
            || lower.contains("disable") || lower.contains("enable")
    }

    private func appVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    // MARK: - JSON Serialization

    func serializeToJSON(_ snapshot: ConfigurationSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    static func deserializeFromJSON(_ data: Data) throws -> ConfigurationSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ConfigurationSnapshot.self, from: data)
    }
}

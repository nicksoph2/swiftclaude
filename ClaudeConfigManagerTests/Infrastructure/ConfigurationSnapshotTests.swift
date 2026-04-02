import XCTest
@testable import ClaudeConfigManager

final class ConfigurationSnapshotTests: XCTestCase {

    // MARK: - Helpers

    private func makeSettingsEntry(
        keyPath: String,
        value: JSONValue,
        scope: ResolutionScope = .user,
        sourcePath: String? = "/test/settings.json"
    ) -> ResolvedSettingsEntry {
        let source = ResolutionSource(
            scope: scope,
            kind: .file,
            identifier: "\(scope.rawValue)-settings",
            sourcePath: sourcePath
        )
        let trace = ResolutionTrace(participants: [source])
        let resolvedValue = ResolvedValue<JSONValue>(
            effectiveValue: value,
            winningSource: source,
            trace: trace,
            mergeMethod: .selectHighestPrecedence
        )
        return ResolvedSettingsEntry(keyPath: keyPath, value: resolvedValue)
    }

    private func makeProjection(entries: [ResolvedSettingsEntry]) -> SessionProjection {
        let settings = ResolvedSettingsSnapshot(entries: entries)
        return SessionProjection(settings: settings)
    }

    private func makeScanResult() -> ScanResult {
        ScanResult(
            managedResult: ManagedScanResult(
                settingsFile: nil,
                settingsOverrideFiles: [],
                mcpFile: nil,
                claudeMdFile: nil,
                mdmResult: nil
            ),
            managedWorkspace: nil,
            userWorkspace: nil,
            projectWorkspaces: [],
            issues: []
        )
    }

    // MARK: - G1: Snapshot Redaction Tests

    func testSnapshotRedactsEnvKeys() {
        let entries = [
            makeSettingsEntry(keyPath: "env.API_KEY", value: .string("sk-secret-12345")),
            makeSettingsEntry(keyPath: "model", value: .string("claude-opus")),
            makeSettingsEntry(keyPath: "env.HOME", value: .string("/Users/test")),
        ]
        let projection = makeProjection(entries: entries)
        let scanResult = makeScanResult()

        let exporter = ConfigurationSnapshotExporter()
        let snapshot = exporter.export(projection, scanResult: scanResult)

        // env.API_KEY should be redacted
        let apiKeyEntry = snapshot.resolvedSettings.first { $0.keyPath == "env.API_KEY" }
        XCTAssertNotNil(apiKeyEntry)
        XCTAssertTrue(apiKeyEntry!.redacted)
        XCTAssertEqual(apiKeyEntry!.resolvedValue, .string("<redacted>"))

        // env.HOME should also be redacted (any env.* key)
        let homeEntry = snapshot.resolvedSettings.first { $0.keyPath == "env.HOME" }
        XCTAssertNotNil(homeEntry)
        XCTAssertTrue(homeEntry!.redacted)
        XCTAssertEqual(homeEntry!.resolvedValue, .string("<redacted>"))

        // model should NOT be redacted
        let modelEntry = snapshot.resolvedSettings.first { $0.keyPath == "model" }
        XCTAssertNotNil(modelEntry)
        XCTAssertFalse(modelEntry!.redacted)
        XCTAssertEqual(modelEntry!.resolvedValue, .string("claude-opus"))
    }

    func testSnapshotRedactsTokenSecretPasswordKeys() {
        let entries = [
            makeSettingsEntry(keyPath: "apiToken", value: .string("tok-123")),
            makeSettingsEntry(keyPath: "auth_secret", value: .string("sec-456")),
            makeSettingsEntry(keyPath: "db_password", value: .string("pw-789")),
            makeSettingsEntry(keyPath: "encryptionKey", value: .string("key-abc")),
            makeSettingsEntry(keyPath: "normalSetting", value: .string("safe")),
        ]
        let projection = makeProjection(entries: entries)
        let scanResult = makeScanResult()

        let exporter = ConfigurationSnapshotExporter()
        let snapshot = exporter.export(projection, scanResult: scanResult)

        XCTAssertTrue(snapshot.resolvedSettings.first { $0.keyPath == "apiToken" }!.redacted)
        XCTAssertTrue(snapshot.resolvedSettings.first { $0.keyPath == "auth_secret" }!.redacted)
        XCTAssertTrue(snapshot.resolvedSettings.first { $0.keyPath == "db_password" }!.redacted)
        XCTAssertTrue(snapshot.resolvedSettings.first { $0.keyPath == "encryptionKey" }!.redacted)
        XCTAssertFalse(snapshot.resolvedSettings.first { $0.keyPath == "normalSetting" }!.redacted)
    }

    func testSnapshotJSONRoundTrip() throws {
        let entries = [
            makeSettingsEntry(keyPath: "model", value: .string("claude-opus")),
            makeSettingsEntry(keyPath: "verbose", value: .bool(true)),
        ]
        let projection = makeProjection(entries: entries)
        let scanResult = makeScanResult()

        let exporter = ConfigurationSnapshotExporter()
        let snapshot = exporter.export(projection, scanResult: scanResult)

        let data = try exporter.serializeToJSON(snapshot)
        let decoded = try ConfigurationSnapshotExporter.deserializeFromJSON(data)

        XCTAssertEqual(snapshot.resolvedSettings.count, decoded.resolvedSettings.count)
        XCTAssertEqual(snapshot.appVersion, decoded.appVersion)

        for (original, roundTripped) in zip(snapshot.resolvedSettings, decoded.resolvedSettings) {
            XCTAssertEqual(original.keyPath, roundTripped.keyPath)
            XCTAssertEqual(original.resolvedValue, roundTripped.resolvedValue)
            XCTAssertEqual(original.redacted, roundTripped.redacted)
        }
    }

    func testSensitiveKeyDetection() {
        XCTAssertTrue(ConfigurationSnapshotExporter.isSensitiveKey("env.API_KEY"))
        XCTAssertTrue(ConfigurationSnapshotExporter.isSensitiveKey("env.anything"))
        XCTAssertTrue(ConfigurationSnapshotExporter.isSensitiveKey("apiToken"))
        XCTAssertTrue(ConfigurationSnapshotExporter.isSensitiveKey("SECRET_VALUE"))
        XCTAssertTrue(ConfigurationSnapshotExporter.isSensitiveKey("userPassword"))
        XCTAssertTrue(ConfigurationSnapshotExporter.isSensitiveKey("encryptionKey"))
        XCTAssertFalse(ConfigurationSnapshotExporter.isSensitiveKey("model"))
        XCTAssertFalse(ConfigurationSnapshotExporter.isSensitiveKey("verbose"))
        XCTAssertFalse(ConfigurationSnapshotExporter.isSensitiveKey("theme"))
    }
}

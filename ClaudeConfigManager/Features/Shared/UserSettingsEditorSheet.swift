import SwiftUI

/// Sheet wrapper for UserSettingsEditorView that handles file loading
struct UserSettingsEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    let fileURL: URL
    
    var body: some View {
        if let document = loadDocument() {
            UserSettingsEditorView(
                fileURL: fileURL,
                fileSize: getFileSize(),
                lastModified: getLastModified(),
                document: document
            )
        } else {
            VStack {
                Text("Unable to load settings file")
                    .foregroundStyle(.secondary)
                Button("Dismiss") { dismiss() }
            }
        }
    }
    
    private func loadDocument() -> ParsedSettingsDocument? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return createEmptyDocument()
        }
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            guard let data = content.data(using: .utf8) else { return nil }
            let parser = SettingsParser()
            let result = parser.parse(data: data, sourceURL: fileURL, scope: .user)
            return result.value
        } catch {
            return createEmptyDocument()
        }
    }
    
    private func createEmptyDocument() -> ParsedSettingsDocument {
        ParsedSettingsDocument(
            source: SourceFileReference(url: fileURL),
            value: SettingsDocumentValue(
                schema: nil, apiKeyHelper: nil, autoMemoryDirectory: nil, cleanupPeriodDays: nil,
                companyAnnouncements: nil, env: nil, attribution: nil, includeCoAuthoredBy: nil,
                includeGitInstructions: nil, permissions: nil, autoMode: nil, disableAutoMode: nil,
                useAutoModeDuringPlan: nil, worktree: nil, disableDeepLinkRegistration: nil, hooks: nil, disableAllHooks: nil,
                allowManagedHooksOnly: nil, allowedHTTPHookURLs: nil, httpHookAllowedEnvVars: nil,
                allowManagedMcpServersOnly: nil, enableAllProjectMcpServers: nil, enabledMcpjsonServers: nil,
                disabledMcpjsonServers: nil, allowedMcpServers: nil, deniedMcpServers: nil,
                sandbox: nil, enabledPlugins: nil, extraKnownMarketplaces: nil, strictKnownMarketplaces: nil,
                blockedMarketplaces: nil, pluginTrustMessage: nil, channelsEnabled: nil,
                allowedChannelPlugins: nil, language: nil, respectGitignore: nil, outputStyle: nil,
                defaultShell: nil, voiceEnabled: nil, prefersReducedMotion: nil, spinnerTipsEnabled: nil,
                showClearContextOnPlanAccept: nil, pluginSettings: [:], keyedStorage: [:], registryValues: [:]
            ),
            rawTopLevelObject: [:],
            unsupportedTopLevelKeys: [:]
        )
    }
    
    private func getFileSize() -> Int {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            return attributes[.size] as? Int ?? 0
        } catch {
            return 0
        }
    }
    
    private func getLastModified() -> Date {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            return attributes[.modificationDate] as? Date ?? Date()
        } catch {
            return Date()
        }
    }
}

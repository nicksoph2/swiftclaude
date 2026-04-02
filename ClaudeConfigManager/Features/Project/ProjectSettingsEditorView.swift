import SwiftUI

/// Editor for project scope settings files (.claude/settings.json and .claude/settings.local.json)
struct ProjectSettingsEditorView: View {
    @Environment(\.dismiss) var dismiss
    
    let teamFileURL: URL
    let personalFileURL: URL
    let teamDocument: ParsedSettingsDocument?
    let personalDocument: ParsedSettingsDocument?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Team settings section
                    teamSettingsSection
                    
                    // Personal settings section
                    personalSettingsSection
                }
                .padding(16)
            }
            .navigationTitle("Project Settings")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var teamSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(".claude/settings.json", systemImage: "person.2")
                    .font(.headline)
                Text("— shared with team")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            
            if let doc = teamDocument {
                settingsListForDocument(doc)
            } else {
                Text("No team settings file")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .padding(12)
            }
        }
        .padding(16)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var personalSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label(".claude/settings.local.json", systemImage: "person")
                        .font(.headline)
                    Text("— personal override")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                
                Text("Changes here override team settings but are not committed to version control.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let doc = personalDocument {
                settingsListForDocument(doc)
            } else {
                Text("No personal settings file")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .padding(12)
            }
        }
        .padding(16)
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
                .foregroundStyle(.separator.opacity(0.5))
        )
    }
    
    private func settingsListForDocument(_ doc: ParsedSettingsDocument) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(doc.rawTopLevelObject.sorted { $0.key < $1.key }.enumerated()), id: \.element.key) { idx, pair in
                let (key, value) = pair
                settingsRow(key: key, value: value)
                if idx < doc.rawTopLevelObject.count - 1 {
                    Divider()
                }
            }
        }
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func settingsRow(key: String, value: JSONValue) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(key)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                Text(valueDisplayString(value))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: { }) {
                Image(systemName: "pencil")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
    }
    
    private func valueDisplayString(_ value: JSONValue) -> String {
        switch value {
        case .string(let s):
            return s.count > 50 ? String(s.prefix(50)) + "..." : s
        case .number(let n):
            return String(n)
        case .bool(let b):
            return b ? "true" : "false"
        case .array(let arr):
            return "[\(arr.count) items]"
        case .object(let obj):
            return "{\(obj.count) keys}"
        case .null:
            return "null"
        }
    }
}

#Preview {
    let mockTeamDoc = ParsedSettingsDocument(
        source: SourceFileReference(url: URL(fileURLWithPath: "/Projects/test/.claude/settings.json")),
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
        rawTopLevelObject: ["model": .string("claude-opus-4-1-20250805")],
        unsupportedTopLevelKeys: [:]
    )
    
    return ProjectSettingsEditorView(
        teamFileURL: URL(fileURLWithPath: "/Projects/test/.claude/settings.json"),
        personalFileURL: URL(fileURLWithPath: "/Projects/test/.claude/settings.local.json"),
        teamDocument: mockTeamDoc,
        personalDocument: nil
    )
}

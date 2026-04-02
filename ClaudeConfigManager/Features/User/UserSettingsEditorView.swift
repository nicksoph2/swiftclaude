import SwiftUI

/// Editor for ~/.claude/settings.json in user scope
struct UserSettingsEditorView: View {
    @Environment(\.dismiss) var dismiss
    @State private var isSaving = false
    @State private var showAddKeyPicker = false
    @State private var selectedNewKey: String?
    @State private var showSandboxEditor = false
    
    let fileURL: URL
    let fileSize: Int
    let lastModified: Date
    let document: ParsedSettingsDocument
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    settingsGroupedList
                    addNewSettingButton
                }
                .padding(16)
            }
            .navigationTitle("User Settings")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAddKeyPicker) {
                addKeyPickerSheet
            }
            .sheet(isPresented: $showSandboxEditor) {
                SandboxConfigEditorView(
                    currentSettings: document.rawTopLevelObject,
                    targetScope: .user,
                    onSave: { _, _ in
                        // Save via AtomicFileWriter in real integration
                    }
                )
            }
        }
        .onAppear {
            // Settings loaded from document
        }
    }
    
    private var settingsGroupedList: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(settingCategories, id: \.0) { category, keys in
                if !keys.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(category)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if category == "Sandbox" {
                                Button {
                                    showSandboxEditor = true
                                } label: {
                                    Label("Configure", systemImage: "gearshape")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.blue)
                            }
                        }

                        VStack(spacing: 0) {
                            ForEach(Array(keys.enumerated()), id: \.element.0) { idx, pair in
                                let (key, value) = pair
                                settingsRow(key: key, value: value)
                                if idx < keys.count - 1 {
                                    Divider()
                                }
                            }
                        }
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    private var settingCategories: [(String, [(String, JSONValue)])] {
        let allKeys: [String: JSONValue] = document.rawTopLevelObject
        
        let categories: [String: [String]] = [
            "Model": ["model", "smallModel", "largeLargeContextModel", "maxTokens", "temperature", "streaming"],
            "Permissions": Array(allKeys.keys.filter { $0.hasPrefix("permissions.") }),
            "Hooks": Array(allKeys.keys.filter { $0.hasPrefix("hooks.") }),
            "MCP Policy": Array(allKeys.keys.filter { $0.hasPrefix("allowedMcpServers") || $0.hasPrefix("deniedMcpServers") || $0.hasPrefix("disabledMcpServers") }),
            "Sandbox": Array(allKeys.keys.filter { $0.hasPrefix("sandbox.") }),
            "UI": ["verbose", "debug", "outputFormat", "preferredNotifChannel", "statusLine", "showTurnDuration"],
            "Worktree": Array(allKeys.keys.filter { $0.hasPrefix("worktree.") }),
            "Attribution": ["attribution", "includeCoAuthoredBy", "includeGitInstructions"],
        ]
        
        return categories.compactMap { category, keyNames -> (String, [(String, JSONValue)])? in
            let validKeys = keyNames.filter { allKeys[$0] != nil }
            let pairs = validKeys.compactMap { key -> (String, JSONValue)? in
                guard let value = allKeys[key] else { return nil }
                return (key, value)
            }
            return pairs.isEmpty ? nil : (category, pairs)
        }
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
    
    private var addNewSettingButton: some View {
        Button(action: { showAddKeyPicker = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add new setting")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.blue)
    }
    
    private var addKeyPickerSheet: some View {
        NavigationStack {
            Form {
                Section("Available Settings") {
                    Picker("Select a key", selection: $selectedNewKey) {
                        ForEach(availableKeys, id: \.self) { key in
                            Text(key).tag(Optional(key))
                        }
                    }
                }
            }
            .navigationTitle("Add Setting")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Add") {
                        // Add selected key
                        showAddKeyPicker = false
                    }
                    .disabled(selectedNewKey == nil)
                }
            }
        }
    }
    
    private var availableKeys: [String] {
        // Return keys from registry not already in document
        let existingKeys = Set(document.rawTopLevelObject.keys)
        let allRegisteredKeys = [
            "model", "smallModel", "largeLargeContextModel", "maxTokens", "temperature", "streaming",
            "verbose", "debug", "outputFormat", "preferredNotifChannel", "statusLine", "showTurnDuration",
            "permissions", "hooks", "sandbox", "worktree", "attribution", "includeCoAuthoredBy",
        ]
        return allRegisteredKeys.filter { !existingKeys.contains($0) }
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
    let mockDoc = ParsedSettingsDocument(
        source: SourceFileReference(url: URL(fileURLWithPath: "/Users/test/.claude/settings.json")),
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
        rawTopLevelObject: ["model": .string("claude-sonnet-4-5-20250102")],
        unsupportedTopLevelKeys: [:]
    )
    
    return UserSettingsEditorView(
        fileURL: URL(fileURLWithPath: "/Users/test/.claude/settings.json"),
        fileSize: 256,
        lastModified: Date(),
        document: mockDoc
    )
}

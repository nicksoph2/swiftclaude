import SwiftUI

/// Structured editor for sandbox configuration settings.
/// Replaces raw JSON editing with form fields for the sandbox settings family.
struct SandboxConfigEditorView: View {
    @Environment(\.dismiss) var dismiss

    let currentSettings: [String: JSONValue]
    let targetScope: ResolutionScope
    let onSave: ([String: JSONValue], ResolutionScope) async -> Void

    @State private var failIfUnavailable: Bool
    @State private var allowUnsandboxedCommands: Bool
    @State private var allowedDomains: [String]
    @State private var newDomain: String = ""
    @State private var httpProxyPort: Int
    @State private var socksProxyPort: Int
    @State private var enableWeakerNetworkIsolation: Bool
    @State private var isSaving: Bool = false

    init(
        currentSettings: [String: JSONValue],
        targetScope: ResolutionScope,
        onSave: @escaping ([String: JSONValue], ResolutionScope) async -> Void
    ) {
        self.currentSettings = currentSettings
        self.targetScope = targetScope
        self.onSave = onSave

        // Parse current values from the settings
        let sandboxObj = currentSettings["sandbox"]?.objectValue ?? [:]

        _failIfUnavailable = State(initialValue: sandboxObj["failIfUnavailable"]?.boolValue ?? false)
        _allowUnsandboxedCommands = State(initialValue: sandboxObj["allowUnsandboxedCommands"]?.boolValue ?? false)

        let networkObj = sandboxObj["network"]?.objectValue ?? [:]
        let domains = networkObj["allowedDomains"]?.arrayValue?.compactMap { $0.stringValue } ?? []
        _allowedDomains = State(initialValue: domains)

        _httpProxyPort = State(initialValue: networkObj["httpProxyPort"]?.intValue ?? 0)
        _socksProxyPort = State(initialValue: networkObj["socksProxyPort"]?.intValue ?? 0)
        _enableWeakerNetworkIsolation = State(initialValue: sandboxObj["enableWeakerNetworkIsolation"]?.boolValue ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                generalSection
                networkSection
            }
            .formStyle(.grouped)
            .navigationTitle("Sandbox Configuration")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await performSave() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 400)
    }

    // MARK: - Sections

    private var generalSection: some View {
        Section {
            Toggle("Fail if sandbox unavailable", isOn: $failIfUnavailable)

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Allow unsandboxed commands", isOn: $allowUnsandboxedCommands)

                if allowUnsandboxedCommands {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                        Text("Disabling sandbox protections may allow unintended system access.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        } header: {
            Text("General")
        } footer: {
            HStack(spacing: 8) {
                Text("Scope:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScopeColorScheme.scopeBadge(for: targetScope)
            }
        }
    }

    private var networkSection: some View {
        Section("Network") {
            // Allowed domains list
            VStack(alignment: .leading, spacing: 8) {
                Text("Allowed Domains")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if allowedDomains.isEmpty {
                    Text("No domains allowed. All network access will be sandboxed.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .italic()
                }

                ForEach(allowedDomains.indices, id: \.self) { index in
                    HStack {
                        Text(allowedDomains[index])
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        if allowedDomains[index].trimmingCharacters(in: .whitespaces).isEmpty {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                                .help("Empty domain string")
                        }

                        Button(role: .destructive) {
                            allowedDomains.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("hostname.example.com", text: $newDomain)
                        .font(.system(.caption, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                    Button {
                        guard !newDomain.isEmpty else { return }
                        allowedDomains.append(newDomain)
                        newDomain = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(newDomain.isEmpty)
                }
            }

            // Proxy ports
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("HTTP Proxy Port")
                    Spacer()
                    TextField("", value: $httpProxyPort, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    Stepper("", value: $httpProxyPort, in: 0...65535)
                        .labelsHidden()
                }

                if httpProxyPort < 0 || httpProxyPort > 65535 {
                    Text("Port must be between 0 and 65535.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("SOCKS Proxy Port")
                    Spacer()
                    TextField("", value: $socksProxyPort, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    Stepper("", value: $socksProxyPort, in: 0...65535)
                        .labelsHidden()
                }

                if socksProxyPort < 0 || socksProxyPort > 65535 {
                    Text("Port must be between 0 and 65535.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            // Weaker isolation toggle
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Enable weaker network isolation", isOn: $enableWeakerNetworkIsolation)

                if enableWeakerNetworkIsolation {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text("Weaker isolation reduces network security protections.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    // MARK: - Actions

    private func buildSandboxJSON() -> [String: JSONValue] {
        var sandbox: [String: JSONValue] = [:]

        sandbox["failIfUnavailable"] = .bool(failIfUnavailable)
        sandbox["allowUnsandboxedCommands"] = .bool(allowUnsandboxedCommands)

        var network: [String: JSONValue] = [:]
        if !allowedDomains.isEmpty {
            network["allowedDomains"] = .array(allowedDomains.map { .string($0) })
        }
        if httpProxyPort > 0 {
            network["httpProxyPort"] = .number(Double(httpProxyPort))
        }
        if socksProxyPort > 0 {
            network["socksProxyPort"] = .number(Double(socksProxyPort))
        }
        if !network.isEmpty {
            sandbox["network"] = .object(network)
        }

        sandbox["enableWeakerNetworkIsolation"] = .bool(enableWeakerNetworkIsolation)

        return ["sandbox": .object(sandbox)]
    }

    private func performSave() async {
        isSaving = true
        let settings = buildSandboxJSON()
        await onSave(settings, targetScope)
        await MainActor.run {
            isSaving = false
            dismiss()
        }
    }
}

#Preview {
    SandboxConfigEditorView(
        currentSettings: [:],
        targetScope: .user,
        onSave: { _, _ in }
    )
}

import SwiftUI

/// Form-based editor for MCP server entries. Handles both adding new servers and editing existing ones.
/// Present as a sheet from the MCP stage view.
struct MCPServerEditorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var router: AppRouter

    /// Existing server entry being edited, or nil for a new server.
    let existingServer: ResolvedMcpServerEntry?
    /// The target scope this server will be saved to.
    let targetScope: ResolutionScope
    /// All server IDs currently defined in the target scope's file (for uniqueness validation).
    let existingServerIDs: Set<String>
    /// Called on save with the constructed server JSON and scope.
    let onSave: (String, JSONValue, ResolutionScope) async -> Void
    /// Called on delete (only for existing servers).
    let onDelete: ((String, ResolutionScope) async -> Void)?

    // MARK: - Form State

    @State private var serverID: String
    @State private var transportType: MCPTransportType = .stdio
    @State private var command: String = ""
    @State private var arguments: [String] = []
    @State private var newArgument: String = ""
    @State private var envVars: [EnvVarEntry] = []
    @State private var httpURL: String = ""
    @State private var isSaving: Bool = false
    @State private var showDeleteConfirmation: Bool = false

    init(
        existingServer: ResolvedMcpServerEntry?,
        targetScope: ResolutionScope,
        existingServerIDs: Set<String>,
        onSave: @escaping (String, JSONValue, ResolutionScope) async -> Void,
        onDelete: ((String, ResolutionScope) async -> Void)? = nil
    ) {
        self.existingServer = existingServer
        self.targetScope = targetScope
        self.existingServerIDs = existingServerIDs
        self.onSave = onSave
        self.onDelete = onDelete

        if let server = existingServer {
            _serverID = State(initialValue: server.serverID)
            // Parse existing config to populate fields
            if let config = server.resolvedConfig.effectiveValue,
               case .object(let obj) = config {
                let transport = obj["type"]?.stringValue ?? obj["transport"]?.stringValue ?? "stdio"
                _transportType = State(initialValue: transport == "http" ? .http : .stdio)
                _command = State(initialValue: obj["command"]?.stringValue ?? "")
                if let args = obj["args"]?.arrayValue {
                    _arguments = State(initialValue: args.compactMap { $0.stringValue })
                }
                if let env = obj["env"]?.objectValue {
                    _envVars = State(initialValue: env.sorted(by: { $0.key < $1.key }).map {
                        EnvVarEntry(key: $0.key, value: $0.value.stringValue ?? "")
                    })
                }
                _httpURL = State(initialValue: obj["url"]?.stringValue ?? "")
            } else {
                _serverID = State(initialValue: server.serverID)
            }
        } else {
            _serverID = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                serverIdentitySection
                transportSection

                if transportType == .stdio {
                    stdioFieldsSection
                } else {
                    httpFieldsSection
                }
            }
            .formStyle(.grouped)
            .navigationTitle(existingServer != nil ? "Edit MCP Server" : "Add MCP Server")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await performSave() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isFormValid)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if existingServer != nil, onDelete != nil {
                    deleteSection
                }
            }
            .alert("Delete Server", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task { await performDelete() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to remove \"\(serverID)\"? This cannot be undone.")
            }
        }
        .frame(minWidth: 440, minHeight: 400)
    }

    // MARK: - Sections

    private var serverIdentitySection: some View {
        Section("Server Identity") {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Server ID", text: $serverID)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .disabled(existingServer != nil)

                if let idError = serverIDValidationError {
                    Text(idError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            HStack(spacing: 8) {
                Text("Scope:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScopeColorScheme.scopeBadge(for: targetScope)
            }
        }
    }

    private var transportSection: some View {
        Section("Transport") {
            Picker("Type", selection: $transportType) {
                Text("stdio").tag(MCPTransportType.stdio)
                Text("http").tag(MCPTransportType.http)
            }
            .pickerStyle(.segmented)
        }
    }

    private var stdioFieldsSection: some View {
        Section("Command Configuration") {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Command", text: $command)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)

                if command.isEmpty {
                    Text("Required. Path or name of the executable.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Arguments")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(arguments.indices, id: \.self) { index in
                    HStack {
                        Text(arguments[index])
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Button(role: .destructive) {
                            arguments.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("New argument", text: $newArgument)
                        .font(.system(.caption, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                    Button {
                        guard !newArgument.isEmpty else { return }
                        arguments.append(newArgument)
                        newArgument = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(newArgument.isEmpty)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Environment Variables")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(envVars.indices, id: \.self) { index in
                    HStack(spacing: 8) {
                        TextField("Key", text: $envVars[index].key)
                            .font(.system(.caption, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 140)
                        Text("=")
                            .foregroundStyle(.secondary)
                        TextField("Value", text: $envVars[index].value)
                            .font(.system(.caption, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                        Button(role: .destructive) {
                            envVars.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    envVars.append(EnvVarEntry(key: "", value: ""))
                } label: {
                    Label("Add variable", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }
        }
    }

    private var httpFieldsSection: some View {
        Section("HTTP Configuration") {
            VStack(alignment: .leading, spacing: 4) {
                TextField("URL", text: $httpURL)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)

                if let urlError = httpURLValidationError {
                    Text(urlError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var deleteSection: some View {
        VStack {
            Divider()
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete Server", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .padding()
        }
        .background(.bar)
    }

    // MARK: - Validation

    private var serverIDValidationError: String? {
        if serverID.isEmpty {
            return "Server ID is required."
        }
        if serverID.contains(" ") {
            return "Server ID must not contain spaces."
        }
        if existingServer == nil && existingServerIDs.contains(serverID) {
            return "A server with this ID already exists in the current scope."
        }
        return nil
    }

    private var httpURLValidationError: String? {
        if httpURL.isEmpty {
            return "URL is required for HTTP transport."
        }
        guard let url = URL(string: httpURL),
              let scheme = url.scheme,
              (scheme == "http" || scheme == "https") else {
            return "Must be a valid URL with http:// or https:// scheme."
        }
        return nil
    }

    private var isFormValid: Bool {
        guard serverIDValidationError == nil else { return false }

        switch transportType {
        case .stdio:
            return !command.isEmpty
        case .http:
            return httpURLValidationError == nil
        case .unknown:
            return false
        }
    }

    // MARK: - Actions

    private func buildServerJSON() -> JSONValue {
        var obj: [String: JSONValue] = [:]

        switch transportType {
        case .stdio:
            obj["command"] = .string(command)
            if !arguments.isEmpty {
                obj["args"] = .array(arguments.map { .string($0) })
            }
            let validEnvVars = envVars.filter { !$0.key.isEmpty }
            if !validEnvVars.isEmpty {
                var envObj: [String: JSONValue] = [:]
                for entry in validEnvVars {
                    envObj[entry.key] = .string(entry.value)
                }
                obj["env"] = .object(envObj)
            }
        case .http:
            obj["type"] = .string("http")
            obj["url"] = .string(httpURL)
        case .unknown:
            break
        }

        return .object(obj)
    }

    private func performSave() async {
        isSaving = true
        let serverJSON = buildServerJSON()
        await onSave(serverID, serverJSON, targetScope)
        await MainActor.run {
            isSaving = false
            dismiss()
        }
    }

    private func performDelete() async {
        guard let onDelete else { return }
        await onDelete(serverID, targetScope)
        await MainActor.run {
            dismiss()
        }
    }
}

// MARK: - Supporting Types

struct EnvVarEntry: Identifiable {
    let id = UUID()
    var key: String
    var value: String
}

#Preview {
    MCPServerEditorView(
        existingServer: nil,
        targetScope: .user,
        existingServerIDs: ["filesystem", "memory"],
        onSave: { _, _, _ in },
        onDelete: nil
    )
}

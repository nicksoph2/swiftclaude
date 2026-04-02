import SwiftUI

/// Form-based editor for a single hook handler entry within a specific lifecycle event.
/// Presents as a sheet from the Hooks Lifecycle stage view.
struct HookHandlerEditorView: View {
    @Environment(\.dismiss) var dismiss

    /// Existing handler being edited, or nil for a new handler.
    let existingHandler: ResolvedHookHandler?
    /// The target scope for saving.
    let targetScope: ResolutionScope
    /// Pre-selected lifecycle event key (e.g. "PreToolUse").
    let preselectedEvent: String?
    /// Called on save with the constructed handler JSON, event key, and scope.
    let onSave: (String, JSONValue, ResolutionScope) async -> Void
    /// Called on delete for existing handlers.
    let onDelete: ((String, JSONValue, ResolutionScope) async -> Void)?

    // MARK: - Form State

    @State private var selectedEvent: String
    @State private var handlerType: HookHandlerType = .command
    @State private var timeout: Int = 30
    @State private var once: Bool = false
    @State private var shell: String = "bash"
    @State private var command: String = ""
    @State private var httpURL: String = ""
    @State private var httpMethod: String = "POST"
    @State private var template: String = ""
    @State private var agentID: String = ""
    @State private var isSaving: Bool = false
    @State private var showDeleteConfirmation: Bool = false

    init(
        existingHandler: ResolvedHookHandler?,
        targetScope: ResolutionScope,
        preselectedEvent: String?,
        onSave: @escaping (String, JSONValue, ResolutionScope) async -> Void,
        onDelete: ((String, JSONValue, ResolutionScope) async -> Void)? = nil
    ) {
        self.existingHandler = existingHandler
        self.targetScope = targetScope
        self.preselectedEvent = preselectedEvent
        self.onSave = onSave
        self.onDelete = onDelete

        _selectedEvent = State(initialValue: preselectedEvent ?? HookLifecycleTemplate.events.first?.eventKey ?? "PreToolUse")

        if let handler = existingHandler {
            _handlerType = State(initialValue: handler.handlerType ?? .command)
            _timeout = State(initialValue: handler.timeout ?? 30)
            _once = State(initialValue: handler.once ?? false)
            _shell = State(initialValue: handler.shell ?? "bash")
            _command = State(initialValue: handler.command ?? "")
            _httpURL = State(initialValue: handler.url ?? "")
            _httpMethod = State(initialValue: handler.method ?? "POST")
            _template = State(initialValue: handler.template ?? handler.prompt ?? "")
            _agentID = State(initialValue: handler.agentId ?? "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                eventSection
                handlerTypeSection
                handlerConfigSection
                optionsSection
            }
            .formStyle(.grouped)
            .navigationTitle(existingHandler != nil ? "Edit Hook Handler" : "Add Hook Handler")
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
                if existingHandler != nil, onDelete != nil {
                    deleteSection
                }
            }
            .alert("Delete Handler", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task { await performDelete() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to remove this handler?")
            }
        }
        .frame(minWidth: 440, minHeight: 400)
    }

    // MARK: - Sections

    private var eventSection: some View {
        Section("Lifecycle Event") {
            Picker("Event", selection: $selectedEvent) {
                ForEach(HookLifecycleTemplate.events) { event in
                    Text(event.displayName).tag(event.eventKey)
                }
            }
            .disabled(preselectedEvent != nil)

            if let event = HookLifecycleTemplate.events.first(where: { $0.eventKey == selectedEvent }) {
                Text(event.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text("Scope:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScopeColorScheme.scopeBadge(for: targetScope)
            }
        }
    }

    private var handlerTypeSection: some View {
        Section("Handler Type") {
            Picker("Type", selection: $handlerType) {
                Text("Command").tag(HookHandlerType.command)
                Text("HTTP").tag(HookHandlerType.http)
                Text("Prompt").tag(HookHandlerType.prompt)
                Text("Agent").tag(HookHandlerType.agent)
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var handlerConfigSection: some View {
        switch handlerType {
        case .command:
            commandConfigSection
        case .http:
            httpConfigSection
        case .prompt:
            promptConfigSection
        case .agent:
            agentConfigSection
        }
    }

    private var commandConfigSection: some View {
        Section("Command Configuration") {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Command", text: $command)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)

                if command.isEmpty {
                    Text("Required. The shell command to execute.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Picker("Shell", selection: $shell) {
                Text("bash").tag("bash")
                Text("powershell").tag("powershell")
            }
        }
    }

    private var httpConfigSection: some View {
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

            Picker("Method", selection: $httpMethod) {
                Text("POST").tag("POST")
                Text("GET").tag("GET")
            }
        }
    }

    private var promptConfigSection: some View {
        Section("Prompt Configuration") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Template")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $template)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.separator, lineWidth: 0.5)
                    )

                if template.isEmpty {
                    Text("Required. The prompt template to inject.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var agentConfigSection: some View {
        Section("Agent Configuration") {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Agent ID", text: $agentID)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)

                if agentID.isEmpty {
                    Text("Required. The agent identifier to invoke.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var optionsSection: some View {
        Section("Options") {
            HStack {
                Text("Timeout (seconds)")
                Spacer()
                TextField("", value: $timeout, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Stepper("", value: $timeout, in: 1...300)
                    .labelsHidden()
            }

            Toggle("Run only once", isOn: $once)

            if timeout < 1 || timeout > 300 {
                Text("Timeout must be between 1 and 300 seconds.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var deleteSection: some View {
        VStack {
            Divider()
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete Handler", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .padding()
        }
        .background(.bar)
    }

    // MARK: - Validation

    private var httpURLValidationError: String? {
        if httpURL.isEmpty {
            return "URL is required for HTTP handler."
        }
        guard let url = URL(string: httpURL),
              let scheme = url.scheme,
              (scheme == "http" || scheme == "https") else {
            return "Must be a valid URL with http:// or https:// scheme."
        }
        return nil
    }

    private var isFormValid: Bool {
        guard timeout >= 1 && timeout <= 300 else { return false }

        switch handlerType {
        case .command:
            return !command.isEmpty
        case .http:
            return httpURLValidationError == nil
        case .prompt:
            return !template.isEmpty
        case .agent:
            return !agentID.isEmpty
        }
    }

    // MARK: - Actions

    private func buildHandlerJSON() -> JSONValue {
        var obj: [String: JSONValue] = [:]
        obj["type"] = .string(handlerType.rawValue)
        obj["timeout"] = .number(Double(timeout))

        if once {
            obj["once"] = .bool(true)
        }

        switch handlerType {
        case .command:
            obj["command"] = .string(command)
            obj["shell"] = .string(shell)
        case .http:
            obj["url"] = .string(httpURL)
            obj["method"] = .string(httpMethod)
        case .prompt:
            obj["prompt"] = .string(template)
        case .agent:
            obj["agentId"] = .string(agentID)
        }

        return .object(obj)
    }

    private func performSave() async {
        isSaving = true
        let handlerJSON = buildHandlerJSON()
        await onSave(selectedEvent, handlerJSON, targetScope)
        await MainActor.run {
            isSaving = false
            dismiss()
        }
    }

    private func performDelete() async {
        guard let onDelete, let existing = existingHandler else { return }
        await onDelete(selectedEvent, existing.rawObject, targetScope)
        await MainActor.run {
            dismiss()
        }
    }
}

#Preview {
    HookHandlerEditorView(
        existingHandler: nil,
        targetScope: .user,
        preselectedEvent: "PreToolUse",
        onSave: { _, _, _ in },
        onDelete: nil
    )
}

import SwiftUI

/// Compact popover for editing a single setting
struct SettingEditorPopover: View {
    let keyPath: String
    let currentValue: JSONValue
    let winningSource: ResolutionSource?
    let recommendation: ScopeRecommendation
    let targetFileName: String
    let onSave: (JSONValue, ResolutionScope) async -> Void
    /// When provided, enables the "Preview Impact" button.
    /// Receives the proposed change and selected scope; returns a PreviewResult without writing.
    let onPreview: ((SettingsChange, ResolutionScope) async -> PreviewResult)?

    @State private var newValue: JSONValue
    @State private var selectedScope: ResolutionScope
    @State private var writeResult: WriteResult = .pending
    @State private var showError: Bool = false
    @State private var isLoadingPreview: Bool = false
    @State private var pendingPreviewResult: PreviewResult?
    @State private var showPreviewSheet: Bool = false
    @Environment(\.dismiss) var dismiss

    init(
        keyPath: String,
        currentValue: JSONValue,
        winningSource: ResolutionSource?,
        recommendation: ScopeRecommendation,
        targetFileName: String = "settings.json",
        onSave: @escaping (JSONValue, ResolutionScope) async -> Void,
        onPreview: ((SettingsChange, ResolutionScope) async -> PreviewResult)? = nil
    ) {
        self.keyPath = keyPath
        self.currentValue = currentValue
        self.winningSource = winningSource
        self.recommendation = recommendation
        self.targetFileName = targetFileName
        self.onSave = onSave
        self.onPreview = onPreview
        _newValue = State(initialValue: currentValue)
        _selectedScope = State(initialValue: recommendation.recommendedScope)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Key name
            Text(keyPath)
                .font(.system(.headline, design: .monospaced))
                .fontWeight(.bold)

            Divider()

            // Current value section
            VStack(alignment: .leading, spacing: 8) {
                Text("Current value:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                HStack {
                    Text(valueDisplayString(currentValue))
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(2)
                    Spacer()
                }
                .padding(8)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(4)

                if let source = winningSource {
                    HStack(spacing: 4) {
                        Text("Source:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Text(source.displayName ?? source.identifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let path = source.sourcePath {
                            Text("(\(path))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                }
            }

            Divider()

            // New value input
            VStack(alignment: .leading, spacing: 8) {
                Text("New value:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                valueInputField
            }

            Divider()

            // Scope picker
            SimplifiedScopePicker(
                selectedScope: $selectedScope,
                availableScopes: [.user, .project, .projectLocal],
                recommendedScope: recommendation.recommendedScope,
                rationale: recommendation.rationale
            )

            Divider()

            // Actions
            HStack(spacing: 12) {
                Button(action: loadPreview) {
                    if isLoadingPreview {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Loading…")
                        }
                    } else {
                        Label("Preview Impact", systemImage: "eye")
                    }
                }
                .disabled(onPreview == nil || isLoadingPreview)
                .help(onPreview == nil ? "Preview requires a pipeline connection" : "Preview the effect of this change before saving")

                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Save") {
                    Task {
                        await performSave()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(maxWidth: 400)
        .alert("Save Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            if case let .failure(error) = writeResult {
                Text(errorDescription(error))
            }
        }
        .sheet(isPresented: $showPreviewSheet) {
            if let result = pendingPreviewResult {
                PreSavePreviewView(
                    previewResult: result,
                    change: SettingsChange(keyPath: keyPath, newValue: newValue, operation: .set),
                    targetScope: selectedScope,
                    targetFileName: targetFileName,
                    onConfirmSave: {
                        await performSaveAndDismiss()
                    },
                    onChangeScope: {
                        showPreviewSheet = false
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var valueInputField: some View {
        switch currentValue {
        case .string:
            TextField("Value", text: Binding(
                get: { if case let .string(s) = newValue { return s } else { return "" } },
                set: { newValue = .string($0) }
            ))
            .textFieldStyle(.roundedBorder)

        case .bool:
            Toggle("Enabled", isOn: Binding(
                get: { if case let .bool(b) = newValue { return b } else { return false } },
                set: { newValue = .bool($0) }
            ))

        case .number:
            TextField("Value", value: Binding(
                get: { if case let .number(n) = newValue { return n } else { return 0 } },
                set: { newValue = .number($0) }
            ), format: .number)
            .textFieldStyle(.roundedBorder)

        case .array:
            Text("Array editing not yet supported")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .object:
            Text("Object editing not yet supported")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .null:
            Text("null")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func loadPreview() {
        guard let onPreview, !isLoadingPreview else { return }
        isLoadingPreview = true
        let change = SettingsChange(keyPath: keyPath, newValue: newValue, operation: .set)
        let scope = selectedScope
        Task {
            let result = await onPreview(change, scope)
            await MainActor.run {
                pendingPreviewResult = result
                isLoadingPreview = false
                showPreviewSheet = true
            }
        }
    }

    private func performSave() async {
        writeResult = .pending
        await onSave(newValue, selectedScope)
        writeResult = .success
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }

    /// Called from PreSavePreviewView confirm button — saves and dismisses the popover.
    private func performSaveAndDismiss() async {
        await onSave(newValue, selectedScope)
        await MainActor.run {
            showPreviewSheet = false
            dismiss()
        }
    }

    // MARK: - Helpers

    private func valueDisplayString(_ value: JSONValue) -> String {
        switch value {
        case let .string(s):
            return "\"\(s)\""
        case let .number(n):
            return String(n)
        case let .bool(b):
            return String(b)
        case .array:
            return "[Array]"
        case .object:
            return "{Object}"
        case .null:
            return "null"
        }
    }

    private func errorDescription(_ error: WriteError) -> String {
        switch error {
        case let .fileNotReadable(url):
            return "Cannot read file: \(url.lastPathComponent)"
        case let .parseFailure(_, issues):
            return "Parse error: \(issues.count) issue(s) found"
        case let .schemaValidationFailed(issues):
            return "Validation error: \(issues.count) issue(s) found"
        case let .serializationFailed(err):
            return "Serialization failed: \(err.localizedDescription)"
        case let .writeFailed(_, err):
            return "Write failed: \(err.localizedDescription)"
        case let .syncFailed(err):
            return "Sync failed: \(err.localizedDescription)"
        case let .renameFailed(_, err):
            return "Rename failed: \(err.localizedDescription)"
        case .postWriteValidationFailed:
            return "Post-write validation failed"
        case let .rolledBack(originalError):
            return "Rolled back: \(errorDescription(originalError))"
        }
    }
}

#Preview {
    @State var showPopover = true
    return VStack {
        if showPopover {
            SettingEditorPopover(
                keyPath: "temperature",
                currentValue: .number(0.7),
                winningSource: ResolutionSource(
                    scope: .user,
                    kind: .file,
                    identifier: "user-settings",
                    displayName: "User settings",
                    sourcePath: "~/.claude/settings.json"
                ),
                recommendation: ScopeRecommendation(
                    recommendedScope: .user,
                    rationale: "This is a personal preference.",
                    isEditable: true,
                    lockInfo: nil
                ),
                onSave: { _, _ in }
            )
        }
    }
}

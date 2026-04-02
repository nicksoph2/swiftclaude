import SwiftUI

// MARK: - PreSavePreviewView

/// Shows a structured diff of what will change before any write hits disk.
/// Presented as a sheet from `SettingEditorPopover` when the user taps "Preview Impact".
struct PreSavePreviewView: View {
    let previewResult: PreviewResult
    let change: SettingsChange
    let targetScope: ResolutionScope
    let targetFileName: String
    let onConfirmSave: () async -> Void
    let onChangeScope: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    @State private var showFilePreview = false

    // MARK: - Derived properties

    private var primaryDelta: KeyDelta? {
        previewResult.affectedKeys.first(where: { $0.keyPath == change.keyPath })
    }

    private var secondaryDeltas: [KeyDelta] {
        previewResult.affectedKeys.filter { $0.keyPath != change.keyPath }
    }

    /// Non-nil when a higher-precedence scope would override the proposed change.
    private var overrideConflict: (scope: ResolutionScope, value: JSONValue?)? {
        guard let delta = primaryDelta else { return nil }
        guard scopePrecedenceRank(delta.winningScope) < scopePrecedenceRank(targetScope) else { return nil }
        return (delta.winningScope, delta.after)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let conflict = overrideConflict {
                        overrideWarningBanner(conflict: conflict)
                    }
                    if let error = previewResult.error {
                        errorBanner(error: error)
                    }
                    if let delta = primaryDelta {
                        effectiveValueCard(delta: delta)
                    } else {
                        noChangeCard
                    }
                    if !secondaryDeltas.isEmpty {
                        otherAffectedKeysSection
                    }
                    filePreviewSection
                }
                .padding(20)
            }
            Divider()
            actionBar
        }
        .frame(minWidth: 500, minHeight: 440)
    }

    // MARK: - Sub-views

    private var header: some View {
        HStack {
            Text("Preview Impact")
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func overrideWarningBanner(conflict: (scope: ResolutionScope, value: JSONValue?)) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Label("This change may have no effect", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text(
                    "The \(scopeDisplayName(conflict.scope)) scope already sets \(change.keyPath) to " +
                    "\(valueString(conflict.value)) and takes precedence. " +
                    "Your change will be saved but will be overridden."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        }
        .backgroundStyle(Color.orange.opacity(0.08))
    }

    private func errorBanner(error: WriteError) -> some View {
        GroupBox {
            Label(errorDescription(error), systemImage: "xmark.circle.fill")
                .font(.callout)
                .foregroundStyle(.red)
        }
    }

    private func effectiveValueCard(delta: KeyDelta) -> some View {
        GroupBox(label: Text("Effective value after saving").font(.headline)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(delta.keyPath)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                    Spacer()
                    Text(scopeDisplayName(delta.winningScope))
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Before")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Text(valueString(delta.before))
                            .font(.system(.body, design: .monospaced))
                            .strikethrough(delta.before != delta.after)
                            .foregroundStyle(delta.before != delta.after ? .secondary : .primary)
                    }

                    if delta.before != delta.after {
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)
                            .padding(.top, 20)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("After")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Text(valueString(delta.after))
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.semibold)
                                .foregroundStyle(delta.before == nil ? .green : .orange)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var noChangeCard: some View {
        GroupBox(label: Text("Effective value after saving").font(.headline)) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text("No change to the resolved value of \(change.keyPath).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var otherAffectedKeysSection: some View {
        GroupBox(label: Text("Other affected keys (\(secondaryDeltas.count))").font(.headline)) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(secondaryDeltas.enumerated()), id: \.element.keyPath) { idx, delta in
                    HStack(spacing: 8) {
                        Text(delta.keyPath)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                        Spacer()
                        Group {
                            Text(valueString(delta.before))
                                .strikethrough()
                                .foregroundStyle(.secondary)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(valueString(delta.after))
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 5)
                    if idx < secondaryDeltas.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var filePreviewSection: some View {
        GroupBox {
            DisclosureGroup(
                isExpanded: $showFilePreview,
                content: {
                    ScrollView([.vertical, .horizontal]) {
                        Text(previewResult.targetFilePreview.isEmpty ? "(empty)" : previewResult.targetFilePreview)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(maxHeight: 180)
                    .background(Color(.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(.top, 4)
                },
                label: {
                    Text("What will be written to \(targetFileName)")
                        .font(.headline)
                }
            )
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            if overrideConflict != nil {
                Button("Change target scope") {
                    onChangeScope()
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if let error = previewResult.error {
                Text(errorDescription(error))
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            } else {
                let label = overrideConflict != nil
                    ? "Save anyway"
                    : "Confirm and Save to \(scopeDisplayName(targetScope))"

                Button(label) {
                    Task {
                        isSaving = true
                        await onConfirmSave()
                        isSaving = false
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)

                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Helpers

    /// Precedence rank: lower number = higher precedence = overrides others.
    private func scopePrecedenceRank(_ scope: ResolutionScope) -> Int {
        switch scope {
        case .managed: return 0
        case .cli: return 1
        case .projectLocal: return 2
        case .project: return 3
        case .user: return 4
        default: return 5
        }
    }

    private func scopeDisplayName(_ scope: ResolutionScope) -> String {
        switch scope {
        case .managed: return "Managed"
        case .user: return "User"
        case .project: return "Project"
        case .projectLocal: return "Project Local"
        case .session: return "Session"
        case .cli: return "CLI"
        case .imported: return "Imported"
        case .autoMemory: return "Auto Memory"
        case .synthetic: return "Synthetic"
        }
    }

    private func valueString(_ value: JSONValue?) -> String {
        guard let value else { return "\u{2014}" }
        switch value {
        case let .string(s): return "\"\(s)\""
        case let .number(n):
            return n.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(n)) : String(n)
        case let .bool(b): return b ? "true" : "false"
        case .array: return "[Array]"
        case .object: return "{Object}"
        case .null: return "null"
        }
    }

    private func errorDescription(_ error: WriteError) -> String {
        switch error {
        case let .fileNotReadable(url):
            return "Cannot read \(url.lastPathComponent)"
        case let .parseFailure(_, issues):
            return "Parse error: \(issues.count) issue(s)"
        case let .schemaValidationFailed(issues):
            return "Validation error: \(issues.count) issue(s)"
        case let .serializationFailed(err):
            return "Serialization failed: \(err.localizedDescription)"
        case let .writeFailed(_, err):
            return "Write failed: \(err.localizedDescription)"
        case let .syncFailed(err):
            return "Sync failed: \(err.localizedDescription)"
        case let .renameFailed(_, err):
            return "Rename failed: \(err.localizedDescription)"
        case .postWriteValidationFailed:
            return "Post-write value mismatch"
        case let .rolledBack(original):
            return "Rolled back: \(errorDescription(original))"
        }
    }
}

// MARK: - Preview

#Preview {
    let delta = KeyDelta(
        keyPath: "verboseOutput",
        before: .bool(false),
        after: .bool(true),
        winningScope: .user
    )
    let result = PreviewResult(
        proposedProjection: SessionProjection(),
        affectedKeys: [delta],
        targetFilePreview: "{\n  \"verboseOutput\" : true\n}",
        error: nil
    )
    let change = SettingsChange(keyPath: "verboseOutput", newValue: .bool(true), operation: .set)
    return PreSavePreviewView(
        previewResult: result,
        change: change,
        targetScope: .user,
        targetFileName: "settings.json",
        onConfirmSave: {},
        onChangeScope: {}
    )
}

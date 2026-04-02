import SwiftUI

struct SettingsChangeImpactView: View {
    @EnvironmentObject private var router: AppRouter

    @State private var selectedScope: ResolutionScope = .user
    @State private var selectedKeyPath: String = ""
    @State private var keySearchText: String = ""
    @State private var proposedValueText: String = ""
    @State private var previewResult: PreviewResult?
    @State private var isComputing: Bool = false
    @State private var showEditorPopover: Bool = false

    private let writableScopes: [ResolutionScope] = [.user, .project, .projectLocal]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    inputSection
                    if previewResult != nil {
                        impactSection
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 480, minHeight: 400)
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Test a settings change")
                .font(.headline.weight(.semibold))

            Text("Propose a hypothetical change and see its downstream effect without writing anything.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Scope selector
            VStack(alignment: .leading, spacing: 4) {
                Text("Target scope")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Picker("Scope", selection: $selectedScope) {
                    ForEach(writableScopes, id: \.rawValue) { scope in
                        Text(scope.rawValue.localizedCapitalized).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Key picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Setting key")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                TextField("Search keys...", text: $keySearchText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                if !filteredKeys.isEmpty {
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(filteredKeys, id: \.self) { key in
                                Button {
                                    selectedKeyPath = key
                                    keySearchText = key
                                } label: {
                                    HStack {
                                        Text(key)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(key == selectedKeyPath ? .primary : .secondary)
                                        Spacer()
                                        if key == selectedKeyPath {
                                            Image(systemName: "checkmark")
                                                .font(.caption2)
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(key == selectedKeyPath
                                        ? Color.blue.opacity(0.1)
                                        : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            // Value field
            VStack(alignment: .leading, spacing: 4) {
                Text("Proposed value (JSON)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                TextField("e.g. true, \"value\", [\"item1\"]", text: $proposedValueText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }

            // Compute button
            Button {
                Task { await computeImpact() }
            } label: {
                HStack(spacing: 6) {
                    if isComputing {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("Compute Impact")
                }
            }
            .disabled(selectedKeyPath.isEmpty || proposedValueText.isEmpty || isComputing)
        }
    }

    // MARK: - Impact Section

    @ViewBuilder
    private var impactSection: some View {
        if let result = previewResult {
            VStack(alignment: .leading, spacing: 16) {
                Divider()

                Text("Impact preview")
                    .font(.headline.weight(.semibold))

                // Before/after for the primary key
                if let primaryDelta = result.affectedKeys.first(where: { $0.keyPath == selectedKeyPath }) {
                    beforeAfterCard(delta: primaryDelta)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "equal.circle")
                            .foregroundStyle(.secondary)
                        Text("No change to effective value for \(selectedKeyPath)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                // Other affected keys
                let secondaryDeltas = result.affectedKeys.filter { $0.keyPath != selectedKeyPath }
                if !secondaryDeltas.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Other affected keys")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        ForEach(secondaryDeltas, id: \.keyPath) { delta in
                            beforeAfterCard(delta: delta)
                        }
                    }
                }

                // Override warning
                overrideWarning(for: result)

                // Apply button
                if result.error == nil {
                    Button {
                        showEditorPopover = true
                    } label: {
                        Label("Apply this change...", systemImage: "square.and.pencil")
                    }
                    .popover(isPresented: $showEditorPopover) {
                        if let projection = router.pipeline.projection,
                           let entry = projection.settings?.entries.first(where: { $0.keyPath == selectedKeyPath }) {
                            SettingEditorPopover(
                                keyPath: selectedKeyPath,
                                currentValue: entry.value.effectiveValue ?? .null,
                                winningSource: entry.value.winningSource,
                                recommendation: ScopeRecommendation(
                                    recommendedScope: selectedScope,
                                    rationale: "From What If inspector",
                                    isEditable: true,
                                    lockInfo: nil
                                ),
                                onSave: { _, _ in }
                            )
                        } else {
                            SettingEditorPopover(
                                keyPath: selectedKeyPath,
                                currentValue: parseJSONValue(from: proposedValueText) ?? .null,
                                winningSource: nil,
                                recommendation: ScopeRecommendation(
                                    recommendedScope: selectedScope,
                                    rationale: "From What If inspector",
                                    isEditable: true,
                                    lockInfo: nil
                                ),
                                onSave: { _, _ in }
                            )
                        }
                    }
                }

                // Error
                if let error = result.error {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("Error: \(String(describing: error))")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    // MARK: - Before/After Card

    private func beforeAfterCard(delta: KeyDelta) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(delta.keyPath)
                .font(.system(.caption, design: .monospaced).weight(.medium))

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Before")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(jsonDisplayString(delta.before))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.red.opacity(0.8))
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("After")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(jsonDisplayString(delta.after))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.8))
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            HStack(spacing: 4) {
                Text("Winning scope:")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                ScopeColorScheme.scopeBadge(for: delta.winningScope)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Override Warning

    @ViewBuilder
    private func overrideWarning(for result: PreviewResult) -> some View {
        if let primaryDelta = result.affectedKeys.first(where: { $0.keyPath == selectedKeyPath }) {
            let winningRank = scopePrecedenceRank(primaryDelta.winningScope)
            let targetRank = scopePrecedenceRank(selectedScope)

            if winningRank < targetRank {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("This change would be overridden")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                        Text("A higher-precedence scope (\(primaryDelta.winningScope.rawValue)) already defines this key and would take priority.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    // MARK: - Helpers

    private var allKeys: [String] {
        guard let settings = router.pipeline.projection?.settings else { return [] }
        return settings.entries.map(\.keyPath)
    }

    private var filteredKeys: [String] {
        let search = keySearchText.trimmingCharacters(in: .whitespaces).lowercased()
        if search.isEmpty { return allKeys }
        return allKeys.filter { $0.lowercased().contains(search) }
    }

    private func computeImpact() async {
        guard let newValue = parseJSONValue(from: proposedValueText) else { return }
        isComputing = true
        let change = SettingsChange(
            keyPath: selectedKeyPath,
            newValue: newValue,
            operation: .set
        )
        // Build a plausible file URL for the target scope.
        // The pipeline requires a file URL to read the current file content.
        let fileURL = settingsFileURL(for: selectedScope)
        let result = await router.pipeline.preview(change: change, at: selectedScope, fileURL: fileURL)
        previewResult = result
        isComputing = false
    }

    /// Returns the conventional settings.json path for a given scope.
    private func settingsFileURL(for scope: ResolutionScope) -> URL {
        switch scope {
        case .user:
            let home = FileManager.default.homeDirectoryForCurrentUser
            return home.appendingPathComponent(".claude/settings.json")
        case .project, .projectLocal:
            // Use the provenance to find a project-scoped source path
            if let provenance = router.pipeline.projection?.provenance {
                let projectSource = provenance.participatingSources.first(where: { $0.scope == .project })
                if let sourcePath = projectSource?.sourcePath {
                    let projectDir = URL(fileURLWithPath: sourcePath, isDirectory: true).deletingLastPathComponent()
                    let filename = scope == .projectLocal ? "settings.local.json" : "settings.json"
                    return projectDir.appendingPathComponent(filename)
                }
            }
            return URL(fileURLWithPath: ".claude/settings.json")
        default:
            return URL(fileURLWithPath: ".claude/settings.json")
        }
    }

    private func parseJSONValue(from text: String) -> JSONValue? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed == "true" { return .bool(true) }
        if trimmed == "false" { return .bool(false) }
        if trimmed == "null" { return .null }
        if let number = Double(trimmed) { return .number(number) }
        if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") {
            let inner = String(trimmed.dropFirst().dropLast())
            return .string(inner)
        }
        // Try JSON parsing for arrays/objects
        if let data = trimmed.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data),
           let jsonValue = jsonValueFromAny(parsed) {
            return jsonValue
        }
        // Fall back to treating as a plain string
        return .string(trimmed)
    }

    private func jsonValueFromAny(_ value: Any) -> JSONValue? {
        JSONValue.from(any: value)
    }

    private func jsonDisplayString(_ value: JSONValue?) -> String {
        guard let value else { return "(not set)" }
        switch value {
        case .string(let s): return "\"\(s)\""
        case .number(let n): return n.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(n))" : "\(n)"
        case .bool(let b): return b ? "true" : "false"
        case .null: return "null"
        case .array(let arr): return "[\(arr.count) items]"
        case .object(let obj): return "{\(obj.count) keys}"
        }
    }

    private func scopePrecedenceRank(_ scope: ResolutionScope) -> Int {
        switch scope {
        case .managed: return 0
        case .user: return 1
        case .project: return 2
        case .projectLocal: return 3
        case .session: return 4
        case .cli: return 5
        case .imported: return 6
        case .autoMemory: return 7
        case .synthetic: return 8
        }
    }
}

#Preview {
    SettingsChangeImpactView()
        .environmentObject(AppRouter())
}

import SwiftUI

/// Popover-based editor for a single permission rule pattern.
/// Used from PermissionsInspectorView when edit mode is active.
struct PermissionRuleEditorView: View {
    @Environment(\.dismiss) var dismiss

    /// Existing rule being edited, or nil for a new rule.
    let existingRule: PermissionRuleWithOrigin?
    /// Pre-selected outcome (deny/ask/allow) for new rules.
    let preselectedOutcome: PermissionRuleType?
    /// The scope to save to.
    let targetScope: ResolutionScope
    /// Called on save with the pattern, rule type, and scope.
    let onSave: (String, PermissionRuleType, ResolutionScope) async -> Void
    /// Called on delete for existing rules.
    let onDelete: ((PermissionRuleWithOrigin) async -> Void)?

    @State private var pattern: String
    @State private var outcome: PermissionRuleType
    @State private var showGlobTips: Bool = false
    @State private var showDeleteConfirmation: Bool = false

    init(
        existingRule: PermissionRuleWithOrigin?,
        preselectedOutcome: PermissionRuleType?,
        targetScope: ResolutionScope,
        onSave: @escaping (String, PermissionRuleType, ResolutionScope) async -> Void,
        onDelete: ((PermissionRuleWithOrigin) async -> Void)? = nil
    ) {
        self.existingRule = existingRule
        self.preselectedOutcome = preselectedOutcome
        self.targetScope = targetScope
        self.onSave = onSave
        self.onDelete = onDelete

        _pattern = State(initialValue: existingRule?.pattern ?? "")
        _outcome = State(initialValue: existingRule?.ruleType ?? preselectedOutcome ?? .ask)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(existingRule != nil ? "Edit Permission Rule" : "Add Permission Rule")
                .font(.headline)

            Divider()

            // Pattern field
            VStack(alignment: .leading, spacing: 4) {
                Text("Rule pattern")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("e.g. bash:git*", text: $pattern)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)

                if pattern.isEmpty {
                    Text("Required. Enter a glob pattern to match tool names.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            // Live preview
            if !pattern.isEmpty {
                matchPreview
            }

            // Outcome picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Outcome")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("Outcome", selection: $outcome) {
                    Label("Deny", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .tag(PermissionRuleType.deny)
                    Label("Ask", systemImage: "questionmark.circle.fill")
                        .foregroundStyle(.orange)
                        .tag(PermissionRuleType.ask)
                    Label("Allow", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .tag(PermissionRuleType.allow)
                }
                .pickerStyle(.segmented)
            }

            // Scope display
            HStack(spacing: 8) {
                Text("Saving to:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScopeColorScheme.scopeBadge(for: targetScope)
            }

            // Glob pattern tips
            DisclosureGroup("Glob pattern tips", isExpanded: $showGlobTips) {
                VStack(alignment: .leading, spacing: 6) {
                    tipRow(pattern: "bash:*", description: "Match all bash commands")
                    tipRow(pattern: "bash:git*", description: "Match all git commands in bash")
                    tipRow(pattern: "mcp__server__tool", description: "Match a specific MCP tool")
                    tipRow(pattern: "mcp__*", description: "Match all MCP tools")
                    tipRow(pattern: "read:*", description: "Match all file read operations")
                    tipRow(pattern: "write:/tmp/*", description: "Match writes under /tmp/")
                }
                .padding(.top, 4)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Divider()

            // Actions
            HStack(spacing: 12) {
                if existingRule != nil, onDelete != nil {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }

                Spacer()

                Button("Cancel") { dismiss() }

                Button("Save") {
                    Task {
                        await onSave(pattern, outcome, targetScope)
                        await MainActor.run { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(pattern.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 380)
        .alert("Delete Rule", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    if let rule = existingRule {
                        await onDelete?(rule)
                    }
                    await MainActor.run { dismiss() }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to remove this permission rule?")
        }
    }

    // MARK: - Match Preview

    private var matchPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preview")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)

            Text(matchPreviewText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    private var matchPreviewText: String {
        let p = pattern.trimmingCharacters(in: .whitespaces)

        if p.hasPrefix("bash:") {
            let suffix = String(p.dropFirst(5))
            if suffix == "*" {
                return "Matches all bash commands"
            } else if suffix.hasSuffix("*") {
                return "Matches bash commands starting with \"\(suffix.dropLast())\""
            } else {
                return "Matches the bash command \"\(suffix)\""
            }
        } else if p.hasPrefix("zsh:") {
            let suffix = String(p.dropFirst(4))
            if suffix == "*" {
                return "Matches all zsh commands"
            } else {
                return "Matches zsh command \"\(suffix)\""
            }
        } else if p.hasPrefix("mcp__") {
            let parts = p.split(separator: "_", omittingEmptySubsequences: false)
            if parts.count >= 5 {
                return "Matches MCP tool invocation"
            } else if p.hasSuffix("*") {
                return "Matches MCP tools matching \"\(p)\""
            } else {
                return "Matches specific MCP tool \"\(p)\""
            }
        } else if p.hasPrefix("read:") || p.hasPrefix("write:") || p.hasPrefix("edit:") {
            let colonIndex = p.firstIndex(of: ":")!
            let op = String(p[p.startIndex..<colonIndex])
            let path = String(p[p.index(after: colonIndex)...])
            if path == "*" {
                return "Matches all \(op) operations"
            } else {
                return "Matches \(op) operations on \"\(path)\""
            }
        } else if p == "*" {
            return "Matches everything (very broad rule)"
        } else {
            return "Matches tools matching \"\(p)\""
        }
    }

    private func tipRow(pattern: String, description: String) -> some View {
        HStack(spacing: 8) {
            Text(pattern)
                .font(.system(.caption2, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(description)
                .font(.caption2)
        }
    }
}

#Preview {
    PermissionRuleEditorView(
        existingRule: nil,
        preselectedOutcome: .allow,
        targetScope: .user,
        onSave: { _, _, _ in },
        onDelete: nil
    )
}

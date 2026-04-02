import SwiftUI

struct PermissionsInspectorView: View {
    @EnvironmentObject private var router: AppRouter
    @State private var selectedRuleID: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Section 1: Evaluation Order Diagram
                    evaluationOrderDiagram

                    Divider()
                        .padding(.vertical, 8)

                    // Section 2: Effective Rules Table
                    effectiveRulesSection

                    Divider()
                        .padding(.vertical, 8)

                    // Section 3: Permission Inheritance Tree
                    inheritanceTreeSection

                    Divider()
                        .padding(.vertical, 8)

                    // Section 4: Conflicts
                    conflictsSection
                }
                .padding(20)
            }
        }
        .navigationTitle("Permissions")
    }

    // MARK: - Section 1: Evaluation Order Diagram

    private var evaluationOrderDiagram: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How Claude decides if a tool is allowed:")
                .font(.headline.weight(.semibold))

            VStack(spacing: 0) {
                // Gate 1: Deny rules
                evaluationGateRow(
                    number: 1,
                    label: "Deny rules",
                    outcome: "First match = BLOCKED",
                    outcomeColor: .red
                )

                // Arrow down
                VStack(spacing: 4) {
                    HStack(spacing: 0) {
                        Text("No match")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "arrow.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                }
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

                // Gate 2: Ask rules
                evaluationGateRow(
                    number: 2,
                    label: "Ask rules",
                    outcome: "First match = ASK USER",
                    outcomeColor: .orange
                )

                // Arrow down
                VStack(spacing: 4) {
                    HStack(spacing: 0) {
                        Text("No match")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "arrow.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                }
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

                // Gate 3: Allow rules
                evaluationGateRow(
                    number: 3,
                    label: "Allow rules",
                    outcome: "First match = ALLOWED",
                    outcomeColor: .green
                )

                // Arrow down
                VStack(spacing: 4) {
                    HStack(spacing: 0) {
                        Text("No match")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "arrow.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                }
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

                // Default outcome
                HStack(spacing: 12) {
                    Text("Default")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("(usually: ask user)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.separator.opacity(0.2), lineWidth: 0.5)
            )
        }
    }

    private func evaluationGateRow(number: Int, label: String, outcome: String, outcomeColor: Color) -> some View {
        HStack(spacing: 12) {
            // Number badge
            Text("\(number)")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.gray)
                .clipShape(Circle())

            // Rule type label
            Text(label)
                .font(.body.weight(.medium))

            Spacer()

            // Outcome badge
            Text(outcome)
                .font(.caption.weight(.medium))
                .foregroundStyle(outcomeColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(outcomeColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Section 2: Effective Rules Table

    private var effectiveRulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Effective permission rules")
                .font(.headline.weight(.semibold))

            if let projection = router.pipeline.projection,
               let settings = projection.settings {
                let rules = extractPermissionRules(from: settings)

                if rules.isEmpty {
                    Text("No permission rules configured.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                } else {
                    let grouped = groupRulesByType(rules)

                    VStack(spacing: 16) {
                        ForEach(grouped.keys.sorted(), id: \.self) { groupKey in
                            rulesGroup(
                                title: groupKey,
                                rules: grouped[groupKey] ?? [],
                                semanticIssues: projection.issues
                            )
                        }
                    }
                }
            } else {
                Text("No configuration loaded.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            }
        }
    }

    private func extractPermissionRules(from snapshot: ResolvedSettingsSnapshot) -> [PermissionRuleWithOrigin] {
        var rules: [PermissionRuleWithOrigin] = []

        // Look for permissions.allow, permissions.deny, permissions.ask entries
        let permissionEntries = snapshot.entries.filter { entry in
            entry.keyPath.hasPrefix("permissions.") &&
            (entry.keyPath.hasSuffix(".allow") ||
             entry.keyPath.hasSuffix(".deny") ||
             entry.keyPath.hasSuffix(".ask"))
        }

        for entry in permissionEntries {
            if let jsonArray = entry.value.effectiveValue, case .array(let items) = jsonArray {
                let ruleType = extractRuleTypeFromKeyPath(entry.keyPath)
                let source = entry.value.winningSource

                for (index, item) in items.enumerated() {
                    if case .string(let pattern) = item {
                        rules.append(
                            PermissionRuleWithOrigin(
                                pattern: pattern,
                                ruleType: ruleType,
                                sourceScope: source?.scope ?? .session,
                                sourcePath: source?.sourcePath,
                                sourceKeyPath: entry.keyPath,
                                arrayIndex: index
                            )
                        )
                    }
                }
            }
        }

        return rules
    }

    private func extractRuleTypeFromKeyPath(_ keyPath: String) -> PermissionRuleType {
        if keyPath.contains(".deny") {
            return .deny
        } else if keyPath.contains(".ask") {
            return .ask
        } else {
            return .allow
        }
    }

    private func groupRulesByType(_ rules: [PermissionRuleWithOrigin]) -> [String: [PermissionRuleWithOrigin]] {
        var result: [String: [PermissionRuleWithOrigin]] = [:]

        for rule in rules {
            let groupKey = groupKeyForRule(rule)
            if result[groupKey] == nil {
                result[groupKey] = []
            }
            result[groupKey]?.append(rule)
        }

        return result
    }

    private func groupKeyForRule(_ rule: PermissionRuleWithOrigin) -> String {
        if rule.pattern.hasPrefix("read:") || rule.pattern.hasPrefix("write:") || rule.pattern.hasPrefix("edit:") {
            return "File operations"
        } else if rule.pattern.hasPrefix("bash:") || rule.pattern.hasPrefix("zsh:") {
            return "Shell commands"
        } else if rule.pattern.hasPrefix("mcp__") {
            return "MCP tools"
        } else {
            return "Other"
        }
    }

    private func rulesGroup(title: String, rules: [PermissionRuleWithOrigin], semanticIssues: [ResolutionIssue]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 6) {
                ForEach(rules, id: \.id) { rule in
                    ruleRow(rule, semanticIssues: semanticIssues)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func ruleRow(_ rule: PermissionRuleWithOrigin, semanticIssues: [ResolutionIssue]) -> some View {
        HStack(spacing: 12) {
            // Rule pattern (monospace)
            Text(rule.pattern)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)

            Spacer()

            // Outcome badge
            Text(rule.ruleType.rawValue.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(outcomeColor(for: rule.ruleType))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(outcomeColor(for: rule.ruleType).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 3))

            // Scope badge
            ScopeColorScheme.scopeBadge(for: rule.sourceScope)

            // Conflict indicator
            if hasConflictForRule(rule, in: semanticIssues) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .onTapGesture {
            selectedRuleID = rule.id
        }
    }

    private func hasConflictForRule(_ rule: PermissionRuleWithOrigin, in issues: [ResolutionIssue]) -> Bool {
        issues.contains { issue in
            issue.keyPath?.contains(rule.sourceKeyPath) == true
        }
    }

    private func outcomeColor(for ruleType: PermissionRuleType) -> Color {
        switch ruleType {
        case .deny:
            .red
        case .ask:
            .orange
        case .allow:
            .green
        }
    }

    // MARK: - Section 3: Permission Inheritance Tree

    private var inheritanceTreeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permission inheritance tree")
                .font(.headline.weight(.semibold))

            if let projection = router.pipeline.projection {
                inheritanceTree(for: projection)
            } else {
                Text("No configuration loaded.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            }
        }
    }

    @ViewBuilder
    private func inheritanceTree(for projection: SessionProjection) -> some View {
        if let settings = projection.settings {
            let scopeRules = groupRulesByScope(from: settings)
            let activeScopeCount = scopeRules.filter { !$0.value.isEmpty }.count

            if activeScopeCount == 1, let onlyScope = scopeRules.first(where: { !$0.value.isEmpty })?.key {
                // Single scope diagram
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ScopeColorScheme.scopeBadge(for: onlyScope)
                        Text("All rules come from \(onlyScope.rawValue.localizedCapitalized) scope")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("These rules are merged (all scopes combined)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .italic()
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            } else {
                // Multi-scope tree diagram
                VStack(alignment: .leading, spacing: 16) {
                    // Managed scope (top)
                    if !scopeRules[.managed]!.isEmpty {
                        scopeNode(.managed, ruleCount: scopeRules[.managed]!.count)
                        treeLine()
                    }

                    // User scope (middle)
                    if !scopeRules[.user]!.isEmpty {
                        scopeNode(.user, ruleCount: scopeRules[.user]!.count)
                        treeLine()
                    }

                    // Project scope (bottom)
                    if !scopeRules[.project]!.isEmpty {
                        scopeNode(.project, ruleCount: scopeRules[.project]!.count)
                    }

                    Text("These rules are merged (all scopes combined)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .italic()
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }

    private func groupRulesByScope(from snapshot: ResolvedSettingsSnapshot) -> [ResolutionScope: [PermissionRuleWithOrigin]] {
        var result: [ResolutionScope: [PermissionRuleWithOrigin]] = [:]
        let allScopes: [ResolutionScope] = [.managed, .user, .project, .projectLocal, .session]

        for scope in allScopes {
            result[scope] = []
        }

        let rules = extractPermissionRules(from: snapshot)
        for rule in rules {
            result[rule.sourceScope]?.append(rule)
        }

        return result
    }

    private func scopeNode(_ scope: ResolutionScope, ruleCount: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.fill")
                .foregroundStyle(ScopeColorScheme.color(for: scope))
                .font(.system(size: 8))

            ScopeColorScheme.scopeBadge(for: scope)

            Text("\(ruleCount) rule\(ruleCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func treeLine() -> some View {
        VStack(spacing: 4) {
            Divider()
                .frame(height: 12)
        }
        .padding(.leading, 6)
    }

    // MARK: - Section 4: Conflicts

    private var conflictsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permission conflicts")
                .font(.headline.weight(.semibold))

            if let projection = router.pipeline.projection {
                let conflictIssues = projection.issues.filter { issue in
                    issue.keyPath?.contains("permission") == true
                }

                if conflictIssues.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(.green)

                        Text("No conflicts detected")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                } else {
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(.orange)

                            Text("Conflicts detected")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.orange)
                        }

                        VStack(spacing: 8) {
                            ForEach(conflictIssues, id: \.id) { issue in
                                conflictRow(for: issue)
                            }
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            } else {
                Text("No configuration loaded.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            }
        }
    }

    private func conflictRow(for issue: ResolutionIssue) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(issue.message)
                .font(.caption)
                .foregroundStyle(.primary)

            if let keyPath = issue.keyPath {
                Text(keyPath)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                Text("Consider removing the less specific rule or adjusting its scope.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
        .padding(8)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Supporting Models

struct PermissionRuleWithOrigin: Identifiable, Equatable {
    let id: String
    let pattern: String
    let ruleType: PermissionRuleType
    let sourceScope: ResolutionScope
    let sourcePath: String?
    let sourceKeyPath: String
    let arrayIndex: Int

    init(
        pattern: String,
        ruleType: PermissionRuleType,
        sourceScope: ResolutionScope,
        sourcePath: String?,
        sourceKeyPath: String,
        arrayIndex: Int
    ) {
        self.id = UUID().uuidString
        self.pattern = pattern
        self.ruleType = ruleType
        self.sourceScope = sourceScope
        self.sourcePath = sourcePath
        self.sourceKeyPath = sourceKeyPath
        self.arrayIndex = arrayIndex
    }

    static func == (lhs: PermissionRuleWithOrigin, rhs: PermissionRuleWithOrigin) -> Bool {
        lhs.id == rhs.id
    }
}

#Preview {
    PermissionsInspectorView()
        .environmentObject(AppRouter())
}

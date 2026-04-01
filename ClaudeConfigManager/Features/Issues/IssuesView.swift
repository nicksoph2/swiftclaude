import SwiftUI

struct IssuesView: View {
    @EnvironmentObject private var router: AppRouter
    @State private var severityFilter: Set<ValidationSeverity> = [.error, .warning, .info]

    var body: some View {
        VStack(spacing: 0) {
            // Header with summary
            if router.pipeline.semanticIssues.isEmpty {
                emptyStateView
            } else {
                summaryHeader
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.secondary.opacity(0.1))
                    .border(Color.secondary.opacity(0.2), width: 1)

                // Filter bar
                filterBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                // Issues list
                issuesList
            }
        }
        .navigationTitle("Issues")
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("No issues found.")
                .font(.headline)

            Text("Your configuration looks clean.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var summaryHeader: some View {
        let issues = router.pipeline.semanticIssues
        let errorCount = issues.filter { $0.severity == .error }.count
        let warningCount = issues.filter { $0.severity == .warning }.count
        let infoCount = issues.filter { $0.severity == .info }.count

        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(issues.count) issue\(issues.count == 1 ? "" : "s")")
                    .font(.headline)
                Text("\(errorCount) error\(errorCount == 1 ? "" : "s"), \(warningCount) warning\(warningCount == 1 ? "" : "s"), \(infoCount) note\(infoCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach([ValidationSeverity.error, .warning, .info], id: \.self) { severity in
                let isSelected = severityFilter.contains(severity)
                Button {
                    if isSelected {
                        severityFilter.remove(severity)
                    } else {
                        severityFilter.insert(severity)
                    }
                } label: {
                    HStack(spacing: 4) {
                        severityIcon(severity)
                            .font(.system(size: 10))
                        Text(severity.rawValue.capitalized)
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .opacity(isSelected ? 1 : 0.5)
            }
            Spacer()
        }
    }

    private var issuesList: some View {
        let filtered = router.pipeline.semanticIssues
            .filter { severityFilter.contains($0.severity) }
            .sorted { lhs, rhs in
                let severityOrder: [ValidationSeverity] = [.error, .warning, .info]
                let lhsIndex = severityOrder.firstIndex(of: lhs.severity) ?? Int.max
                let rhsIndex = severityOrder.firstIndex(of: rhs.severity) ?? Int.max
                if lhsIndex != rhsIndex {
                    return lhsIndex < rhsIndex
                }
                return lhs.id < rhs.id
            }

        return ScrollView {
            VStack(spacing: 0) {
                ForEach(filtered, id: \.id) { issue in
                    issueRow(issue)
                }
            }
        }
    }

    private func issueRow(_ issue: ValidationIssue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // Severity icon
                severityIcon(issue.severity)
                    .font(.system(size: 14))
                    .frame(width: 20, alignment: .center)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    // Issue message
                    Text(issue.message)
                        .font(.body)
                        .lineLimit(nil)

                    // Suggestion (if present)
                    if let suggestion = issue.code.suggestion {
                        Text("Suggestion: \(suggestion)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(nil)
                    }

                    // Source badge
                    sourceInfoView(issue)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
        }
    }

    private func sourceInfoView(_ issue: ValidationIssue) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let source = issue.source {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 10))
                    Text("\(source.identifier)")
                        .font(.caption)
                    if let scope = source.scope {
                        Text(scope.rawValue.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(scopeColor(scope).opacity(0.2))
                            .cornerRadius(3)
                    }
                }
                .foregroundStyle(.secondary)
            }
            if let keyPath = issue.keyPath {
                HStack(spacing: 6) {
                    Image(systemName: "key")
                        .font(.system(size: 10))
                    Text(keyPath)
                        .font(.system(.caption, design: .monospaced))
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    private func severityIcon(_ severity: ValidationSeverity) -> some View {
        Group {
            switch severity {
            case .error:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            case .warning:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            case .info:
                Image(systemName: "info.circle")
                    .foregroundStyle(.gray)
            }
        }
    }

    private func scopeColor(_ scope: ResolutionScope) -> Color {
        switch scope {
        case .managed:
            return .red
        case .user:
            return .blue
        case .project:
            return .purple
        case .projectLocal:
            return .purple
        default:
            return .gray
        }
    }
}

extension ValidationCode {
    var suggestion: String? {
        // Return suggestions for specific codes
        if rawValue.contains("denyRuleShadow") {
            return "Remove redundant rules or clarify intent."
        }
        if rawValue.contains("tokenBudget") {
            return "Consider splitting instructions into smaller blocks."
        }
        if rawValue.contains("redundant") {
            return "Remove duplicate rules."
        }
        if rawValue.contains("missingServer") {
            return "Configure the referenced MCP server or remove the reference."
        }
        if rawValue.contains("sandbox") {
            return "Add the domain to sandbox.allowedDomains or remove the hook."
        }
        return nil
    }
}

#if DEBUG
#Preview {
    IssuesView()
        .environmentObject(AppRouter())
}
#endif

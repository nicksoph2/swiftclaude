import SwiftUI

/// A card component representing a single parsed configuration file.
///
/// Shows file path, scope badge, parse health, summary line, and expandable
/// sections for recognized keys, unknown keys, issues, and raw content.
/// Used within `TreeParsingView` to display each `ParseResultRecord`.
struct ParsedFileCardView: View {

    let summary: ParsedFileSummary
    let onNavigateToResolution: ((String) -> Void)?

    @State private var showRecognizedKeys = false
    @State private var showUnknownKeys = false
    @State private var showIssues = false
    @State private var showRawContent = false

    init(summary: ParsedFileSummary, onNavigateToResolution: ((String) -> Void)? = nil) {
        self.summary = summary
        self.onNavigateToResolution = onNavigateToResolution
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: file path + scope badge + health indicator
            cardHeader

            // Summary line
            Text(summary.summaryLine)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Expandable sections
            if !summary.recognizedKeys.isEmpty {
                recognizedKeysSection
            }

            if !summary.unknownKeys.isEmpty {
                unknownKeysSection
            }

            if !summary.record.parseIssues.isEmpty {
                issuesSection
            }

            rawContentSection
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(healthBorderColor, lineWidth: 0.5)
        )
    }

    // MARK: - Header

    @ViewBuilder
    private var cardHeader: some View {
        HStack(spacing: 8) {
            // Health indicator
            healthIcon

            // File path
            Text(summary.record.sourceFile.lastPathComponent)
                .font(.callout.weight(.medium).monospaced())
                .lineLimit(1)

            // Scope badge
            ScopeColorScheme.scopeBadge(for: summary.record.scope)

            // File type badge
            Text(summary.record.fileType.rawValue)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.1))
                )

            Spacer()

            // Full path (truncated)
            Text(summary.record.sourceFile.path)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: 200, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var healthIcon: some View {
        switch summary.health {
        case .healthy:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.callout)
        case .warnings:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.callout)
        case .errors:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.callout)
        case .noData:
            Image(systemName: "circle.dashed")
                .foregroundStyle(.secondary)
                .font(.callout)
        }
    }

    private var healthBorderColor: Color {
        switch summary.health {
        case .healthy: return Color.gray.opacity(0.3)
        case .warnings: return .orange.opacity(0.3)
        case .errors: return .red.opacity(0.3)
        case .noData: return Color.gray.opacity(0.2)
        }
    }

    // MARK: - Recognized Keys Section

    @ViewBuilder
    private var recognizedKeysSection: some View {
        DisclosureGroup(
            isExpanded: $showRecognizedKeys
        ) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(summary.recognizedKeys, id: \.self) { key in
                    HStack(spacing: 6) {
                        Text(key)
                            .font(.system(.caption, design: .monospaced))

                        Spacer()

                        // "View Resolution" button for settings keys
                        if summary.record.fileType == .settings, let onNav = onNavigateToResolution {
                            Button {
                                onNav(key)
                            } label: {
                                HStack(spacing: 2) {
                                    Text("Resolution")
                                        .font(.caption2)
                                    Image(systemName: "arrow.right")
                                        .font(.caption2)
                                }
                                .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
            .padding(.top, 4)
        } label: {
            Label(
                "Recognized Keys (\(summary.recognizedKeyCount))",
                systemImage: "key"
            )
            .font(.caption.weight(.medium))
        }
    }

    // MARK: - Unknown Keys Section

    @ViewBuilder
    private var unknownKeysSection: some View {
        DisclosureGroup(
            isExpanded: $showUnknownKeys
        ) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(summary.unknownKeys, id: \.self) { key in
                    HStack(spacing: 6) {
                        Image(systemName: "questionmark.circle")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text(key)
                            .font(.system(.caption, design: .monospaced))
                    }
                    .padding(.vertical, 1)
                }
            }
            .padding(.top, 4)
        } label: {
            Label(
                "Unknown Keys (\(summary.unknownKeyCount))",
                systemImage: "questionmark.square.dashed"
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(.orange)
        }
    }

    // MARK: - Issues Section

    @ViewBuilder
    private var issuesSection: some View {
        DisclosureGroup(
            isExpanded: $showIssues
        ) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(summary.record.parseIssues) { issue in
                    HStack(alignment: .top, spacing: 6) {
                        issueIcon(for: issue.severity)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(issue.message)
                                .font(.caption)
                                .lineLimit(3)

                            if let keyPath = issue.keyPath {
                                Text(keyPath)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(.top, 4)
        } label: {
            let issueCount = summary.record.parseIssues.count
            Label(
                "Issues (\(issueCount))",
                systemImage: summary.errorCount > 0 ? "xmark.circle" : "exclamationmark.triangle"
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(summary.errorCount > 0 ? .red : .orange)
        }
    }

    @ViewBuilder
    private func issueIcon(for severity: IssueSeverity) -> some View {
        switch severity {
        case .error:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
        case .info:
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
                .font(.caption)
        }
    }

    // MARK: - Raw Content Section

    @ViewBuilder
    private var rawContentSection: some View {
        DisclosureGroup(
            isExpanded: $showRawContent
        ) {
            rawContentBody
                .padding(.top, 4)
        } label: {
            Label("Raw Content", systemImage: "doc.text")
                .font(.caption.weight(.medium))
        }
    }

    @ViewBuilder
    private var rawContentBody: some View {
        if let rawText = summary.record.rawTextContent {
            // Markdown / text content
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                Text(rawText)
                    .font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
        } else if let rawJSON = summary.record.rawContent {
            // JSON content
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                Text(formatJSONValue(rawJSON))
                    .font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
        } else {
            Text("No raw content available")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - JSON Formatting

    private func formatJSONValue(_ value: JSONValue, indent: Int = 0) -> String {
        let pad = String(repeating: "  ", count: indent)
        let padInner = String(repeating: "  ", count: indent + 1)

        switch value {
        case .null:
            return "null"
        case .bool(let b):
            return b ? "true" : "false"
        case .number(let n):
            if n == n.rounded() && abs(n) < 1e15 {
                return String(format: "%.0f", n)
            }
            return String(n)
        case .string(let s):
            return "\"\(s)\""
        case .array(let items):
            if items.isEmpty { return "[]" }
            let inner = items.map { "\(padInner)\(formatJSONValue($0, indent: indent + 1))" }
            return "[\n\(inner.joined(separator: ",\n"))\n\(pad)]"
        case .object(let dict):
            if dict.isEmpty { return "{}" }
            let lines = dict.keys.sorted().map { key in
                "\(padInner)\"\(key)\": \(formatJSONValue(dict[key]!, indent: indent + 1))"
            }
            return "{\n\(lines.joined(separator: ",\n"))\n\(pad)}"
        }
    }
}

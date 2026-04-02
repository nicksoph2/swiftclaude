import SwiftUI

/// Reusable waterfall visualization showing how a single setting key resolves
/// across scope tiers from highest precedence (Managed) to lowest.
///
/// Each tier shows its scope label, value, and status icon (★ winner, ✗ overridden,
/// + contributor, — absent). Connecting arrows flow between tiers.
/// For merge methods (append, appendUnique, etc.) an accumulated value is shown
/// after each contributing tier.
struct ResolutionWaterfallView: View {

    let keyPath: String
    let mergeMethodLabel: String
    let mergeMethod: MergeMethod
    let effectiveValue: String
    let nodes: [WaterfallNode]

    /// Optional callback when a scope tier row is tapped (for cross-stage navigation).
    var onScopeTapped: ((WaterfallNode) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            waterfallHeader

            Divider()
                .padding(.vertical, 8)

            // Scope tiers
            if nodes.isEmpty {
                Text("No resolution data available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                        if let onTap = onScopeTapped, node.sourcePath != nil {
                            Button {
                                onTap(node)
                            } label: {
                                waterfallTierRow(node: node)
                            }
                            .buttonStyle(.plain)
                        } else {
                            waterfallTierRow(node: node)
                        }

                        // Arrow between tiers
                        if index < nodes.count - 1 {
                            connectorArrow
                        }
                    }
                }
            }

            Divider()
                .padding(.vertical, 8)

            // Effective value footer
            effectiveValueRow
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
        )
    }

    // MARK: - Header

    @ViewBuilder
    private var waterfallHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(keyPath)
                .font(.headline.monospaced())

            HStack(spacing: 6) {
                Image(systemName: TreeResolutionViewModel.mergeMethodIcon(for: mergeMethod))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(mergeMethodLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .help(mergeMethod.rawValue)
        }
    }

    // MARK: - Tier Row

    @ViewBuilder
    private func waterfallTierRow(node: WaterfallNode) -> some View {
        HStack(alignment: .center, spacing: 10) {
            // Status icon
            statusIcon(for: node.status)
                .frame(width: 20)

            // Scope badge
            ScopeColorScheme.scopeBadge(for: node.scope)

            // Value
            VStack(alignment: .leading, spacing: 2) {
                if let value = node.value {
                    Text(value)
                        .font(.callout.monospaced())
                        .foregroundStyle(node.status == .overridden ? .secondary : .primary)
                        .strikethrough(node.status == .overridden)
                        .lineLimit(2)
                } else {
                    Text("[no value]")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .italic()
                }

                // Source path
                if let path = node.sourcePath {
                    Text(path)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(tierBackground(for: node.status))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(tierBorder(for: node.status), lineWidth: node.status == .winner ? 1.5 : 0.5)
        )
    }

    // MARK: - Connector Arrow

    @ViewBuilder
    private var connectorArrow: some View {
        HStack {
            Spacer().frame(width: 8)
            Image(systemName: "arrow.down")
                .font(.caption2)
                .foregroundStyle(.quaternary)
            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Effective Value Row

    @ViewBuilder
    private var effectiveValueRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .frame(width: 20)

            Text("EFFECTIVE VALUE")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            Text(effectiveValue)
                .font(.callout.monospaced().weight(.semibold))
                .lineLimit(3)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.green.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Status Helpers

    @ViewBuilder
    private func statusIcon(for status: WaterfallNodeStatus) -> some View {
        switch status {
        case .winner:
            Image(systemName: "star.fill")
                .font(.caption)
                .foregroundStyle(.yellow)
        case .overridden:
            Image(systemName: "xmark")
                .font(.caption)
                .foregroundStyle(.red.opacity(0.7))
        case .contributor:
            Image(systemName: "plus")
                .font(.caption)
                .foregroundStyle(.blue)
        case .absent:
            Image(systemName: "minus")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func tierBackground(for status: WaterfallNodeStatus) -> Color {
        switch status {
        case .winner:
            return Color.green.opacity(0.04)
        case .overridden:
            return Color.red.opacity(0.03)
        case .contributor:
            return Color.blue.opacity(0.03)
        case .absent:
            return Color.clear
        }
    }

    private func tierBorder(for status: WaterfallNodeStatus) -> Color {
        switch status {
        case .winner:
            return Color.green.opacity(0.4)
        case .overridden:
            return Color.red.opacity(0.2)
        case .contributor:
            return Color.blue.opacity(0.2)
        case .absent:
            return Color.gray.opacity(0.2)
        }
    }
}

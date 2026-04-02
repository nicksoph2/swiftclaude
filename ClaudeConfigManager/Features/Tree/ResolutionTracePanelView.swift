import SwiftUI

// MARK: - Participation Kind

/// Describes how a scope participated in the resolution of a single key.
enum ResolutionParticipationKind: Equatable, Sendable {
    case winning
    case overridden
    case merged
    case absent
}

// MARK: - Trace Scope Row Model

/// A single row in the provenance timeline, representing one scope's participation.
struct TraceScopeRow: Identifiable, Equatable, Sendable {
    let id: String
    let scope: ResolutionScope
    let participation: ResolutionParticipationKind
    let valueString: String?
    let sourcePath: String?

    init(
        scope: ResolutionScope,
        participation: ResolutionParticipationKind,
        valueString: String? = nil,
        sourcePath: String? = nil
    ) {
        self.scope = scope
        self.participation = participation
        self.valueString = valueString
        self.sourcePath = sourcePath
        self.id = "\(scope.rawValue)::\(participation)"
    }
}

// MARK: - Trace Panel View

/// A drill-down panel showing exactly where a resolved setting value came from:
/// the winning value, full provenance chain, merge method, and source navigation.
struct ResolutionTracePanelView: View {

    let entry: ResolvedSettingsEntry
    let onClose: () -> Void
    var onNavigate: ((TreeNavigationTarget) -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                Divider()
                winningValueSection
                Divider()
                provenanceTimeline
                if isArrayMerge {
                    Divider()
                    mergedContributionsSection
                }
            }
            .padding(16)
        }
        .frame(minWidth: 340, idealWidth: 420, maxWidth: 560)
        .frame(minHeight: 300, idealHeight: 480)
    }

    // MARK: - Computed Properties

    private var resolved: ResolvedValue<JSONValue> { entry.value }
    private var mergeMethod: MergeMethod { resolved.mergeMethod }

    private var isArrayMerge: Bool {
        [.append, .appendUnique, .setUnion].contains(mergeMethod)
    }

    private var scopeRows: [TraceScopeRow] {
        Self.buildScopeRows(from: resolved)
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.keyPath)
                    .font(.headline.monospaced().weight(.bold))
                    .textSelection(.enabled)

                HStack(spacing: 5) {
                    Image(systemName: TreeResolutionViewModel.mergeMethodIcon(for: mergeMethod))
                        .font(.caption)
                    Text(TreeResolutionViewModel.mergeMethodLabel(for: mergeMethod))
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.secondary.opacity(0.08))
                )
            }

            Spacer()

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Winning Value

    @ViewBuilder
    private var winningValueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Effective value")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            effectiveValueContent

            if let winnerScope = resolved.winningSource?.scope {
                ScopeColorScheme.scopeBadge(for: winnerScope)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var effectiveValueContent: some View {
        if let value = resolved.effectiveValue {
            switch value {
            case .bool(let b):
                HStack(spacing: 6) {
                    Image(systemName: b ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(b ? .green : .red)
                    Text(b ? "true" : "false")
                        .font(.callout.monospaced())
                }

            case .array(let items):
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 6) {
                            Circle()
                                .fill(contributorColor(for: item))
                                .frame(width: 7, height: 7)
                                .padding(.top, 5)
                            Text(TreeResolutionViewModel.formatJSONValue(item, compact: false))
                                .font(.callout.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                }

            case .object(let dict):
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(dict.keys.sorted(), id: \.self) { key in
                        HStack(alignment: .top, spacing: 4) {
                            Text(key + ":")
                                .font(.callout.monospaced().weight(.medium))
                            Text(TreeResolutionViewModel.formatJSONValue(dict[key]!))
                                .font(.callout.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .textSelection(.enabled)
                    }
                }

            default:
                Text(TreeResolutionViewModel.formatJSONValue(value))
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
            }
        } else {
            Text("[no value]")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .italic()
        }
    }

    // MARK: - Provenance Timeline

    @ViewBuilder
    private var provenanceTimeline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Provenance")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(scopeRows.enumerated()), id: \.element.id) { index, row in
                    provenanceRow(for: row)

                    if index < scopeRows.count - 1 {
                        HStack {
                            Spacer().frame(width: 9)
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: 1, height: 12)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func provenanceRow(for row: TraceScopeRow) -> some View {
        HStack(alignment: .center, spacing: 8) {
            // Participation icon
            participationIcon(for: row.participation)
                .frame(width: 18)

            // Scope badge
            ScopeColorScheme.scopeBadge(for: row.scope)

            // Value
            VStack(alignment: .leading, spacing: 2) {
                if let value = row.valueString {
                    Text(value)
                        .font(.caption.monospaced())
                        .foregroundStyle(row.participation == .overridden ? .secondary : .primary)
                        .strikethrough(row.participation == .overridden)
                        .lineLimit(2)
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // Source path (shown for winning row)
                if row.participation == .winning, let path = row.sourcePath {
                    Text(path)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            // "Go to source" for winning row
            if row.participation == .winning, let path = row.sourcePath {
                Button {
                    let url = URL(fileURLWithPath: path)
                    onNavigate?(.parsingFile(url))
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.right.circle")
                            .font(.caption2)
                        Text("Go to source")
                            .font(.caption2)
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(participationBackground(for: row.participation))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    participationBorder(for: row.participation),
                    lineWidth: row.participation == .winning ? 1.5 : 0.5
                )
        )
    }

    // MARK: - Merged Contributions (Array Merge)

    @ViewBuilder
    private var mergedContributionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Merged contributions")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if case .array(let items) = resolved.effectiveValue {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(contributorColor(for: item))
                                .frame(width: 7, height: 7)
                            Text(TreeResolutionViewModel.formatJSONValue(item, compact: false))
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func participationIcon(for kind: ResolutionParticipationKind) -> some View {
        switch kind {
        case .winning:
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(.green)
        case .overridden:
            Image(systemName: "xmark")
                .font(.caption)
                .foregroundStyle(.red.opacity(0.7))
        case .merged:
            Image(systemName: "plus")
                .font(.caption)
                .foregroundStyle(.blue)
        case .absent:
            Image(systemName: "minus")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func participationBackground(for kind: ResolutionParticipationKind) -> Color {
        switch kind {
        case .winning: Color.green.opacity(0.04)
        case .overridden: Color.red.opacity(0.03)
        case .merged: Color.blue.opacity(0.03)
        case .absent: Color.clear
        }
    }

    private func participationBorder(for kind: ResolutionParticipationKind) -> Color {
        switch kind {
        case .winning: Color.green.opacity(0.4)
        case .overridden: Color.red.opacity(0.2)
        case .merged: Color.blue.opacity(0.2)
        case .absent: Color.gray.opacity(0.2)
        }
    }

    /// For array-merge keys, attempts to find which scope contributed a given item.
    /// Falls back to the winning scope color if no match is found.
    private func contributorColor(for item: JSONValue) -> Color {
        // Best-effort: color by the first contributor scope
        if let winnerScope = resolved.winningSource?.scope {
            return ScopeColorScheme.color(for: winnerScope)
        }
        return .secondary
    }

    // MARK: - Static Row Builder

    /// Builds scope rows from a resolved value, in canonical precedence order.
    static func buildScopeRows(from resolved: ResolvedValue<JSONValue>) -> [TraceScopeRow] {
        let scopeOrder: [ResolutionScope] = [
            .managed, .cli, .projectLocal, .project, .user, .session, .imported, .autoMemory, .synthetic
        ]

        let participantsByScope = Dictionary(
            grouping: resolved.trace.participants,
            by: { $0.scope }
        )
        let overriddenByScope = Dictionary(
            grouping: resolved.trace.overridden,
            by: { $0.scope }
        )
        let winnerScope = resolved.winningSource?.scope

        let isMerge = [.append, .appendUnique, .setUnion, .deepMergeObject, .keyedByIdentifier]
            .contains(resolved.mergeMethod)

        // Show all scopes that participated or were overridden, plus absent scopes
        // between the highest and lowest participating scope for context.
        let activeScopeSet = Set(
            (resolved.trace.participants.map(\.scope)) +
            (resolved.trace.overridden.map(\.scope))
        )

        // Only show scopes that actively participated or were overridden
        let relevantScopes = scopeOrder.filter { activeScopeSet.contains($0) }

        // If no relevant scopes but we have a winner, show just the winner
        if relevantScopes.isEmpty, let winnerScope {
            return [
                TraceScopeRow(
                    scope: winnerScope,
                    participation: .winning,
                    valueString: formatEffectiveValue(resolved.effectiveValue),
                    sourcePath: resolved.winningSource?.sourcePath
                )
            ]
        }

        return relevantScopes.map { scope in
            let isWinner = scope == winnerScope
            let isOverridden = overriddenByScope[scope] != nil
            let source = participantsByScope[scope]?.first ?? overriddenByScope[scope]?.first

            let participation: ResolutionParticipationKind
            if isMerge && !isOverridden {
                participation = isWinner ? .winning : .merged
            } else if isWinner {
                participation = .winning
            } else if isOverridden {
                participation = .overridden
            } else {
                participation = .absent
            }

            let valueString = source?.displayName ?? source?.identifier

            return TraceScopeRow(
                scope: scope,
                participation: participation,
                valueString: valueString,
                sourcePath: source?.sourcePath
            )
        }
    }

    private static func formatEffectiveValue(_ value: JSONValue?) -> String? {
        guard let value else { return nil }
        return TreeResolutionViewModel.formatJSONValue(value)
    }
}

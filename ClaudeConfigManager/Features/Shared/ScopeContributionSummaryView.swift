import SwiftUI

// MARK: - Scope Contribution Models

struct ScopeContributionData {
    /// Settings entries where this scope's value is the effective winner.
    let wins: [ResolvedSettingsEntry]
    /// Settings entries where this scope contributed items to a merged result
    /// but did not exclusively win.
    let contributions: [ResolvedSettingsEntry]
    /// Settings entries where this scope had a value that was overridden.
    let losses: [ResolvedSettingsEntry]

    static func compute(
        from projection: SessionProjection?,
        scope targetScope: ResolutionScope
    ) -> ScopeContributionData {
        guard let entries = projection?.settings?.entries else {
            return ScopeContributionData(wins: [], contributions: [], losses: [])
        }

        let mergeMethods: Set<MergeMethod> = [
            .append, .appendUnique, .setUnion, .deepMergeObject, .keyedByIdentifier
        ]

        var wins: [ResolvedSettingsEntry] = []
        var contributions: [ResolvedSettingsEntry] = []
        var losses: [ResolvedSettingsEntry] = []

        for entry in entries {
            let value = entry.value
            let isWinner = value.winningSource?.scope == targetScope
            let isMerge = mergeMethods.contains(value.mergeMethod)
            let participates = value.trace.participants.contains { $0.scope == targetScope }
            let wasOverridden = value.trace.overridden.contains { $0.scope == targetScope }

            if isWinner {
                wins.append(entry)
            }
            if isMerge && participates && !isWinner {
                contributions.append(entry)
            }
            if wasOverridden {
                losses.append(entry)
            }
        }

        return ScopeContributionData(wins: wins, contributions: contributions, losses: losses)
    }
}

// MARK: - Scope Contribution Summary View

/// Three collapsible panels showing a scope's wins, contributions, and losses
/// in the resolved settings. Tap any row to open its Resolution Trace panel.
@MainActor
struct ScopeContributionSummaryView: View {
    @EnvironmentObject private var pipeline: ConfigurationPipeline

    let targetScope: ResolutionScope

    @State private var winsExpanded = false
    @State private var contributionsExpanded = false
    @State private var lossesExpanded = false
    @State private var selectedEntry: ContributionEntry?

    private struct ContributionEntry: Identifiable {
        let entry: ResolvedSettingsEntry
        var id: String { entry.keyPath }
    }

    private var data: ScopeContributionData {
        ScopeContributionData.compute(from: pipeline.projection, scope: targetScope)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader

            DisclosureGroup(isExpanded: $winsExpanded) {
                entryList(data.wins, kind: .wins)
            } label: {
                panelLabel("Settings this scope wins", count: data.wins.count, color: .green, icon: "checkmark.circle.fill")
            }
            .disclosureGroupStyle(ContributionDisclosureStyle())

            DisclosureGroup(isExpanded: $contributionsExpanded) {
                entryList(data.contributions, kind: .contributions)
            } label: {
                panelLabel("Settings this scope contributes to", count: data.contributions.count, color: .blue, icon: "plus.circle.fill")
            }
            .disclosureGroupStyle(ContributionDisclosureStyle())

            DisclosureGroup(isExpanded: $lossesExpanded) {
                entryList(data.losses, kind: .losses)
            } label: {
                panelLabel("Settings this scope loses", count: data.losses.count, color: .orange, icon: "xmark.circle.fill")
            }
            .disclosureGroupStyle(ContributionDisclosureStyle())
        }
        .sheet(item: $selectedEntry) { wrapper in
            ResolutionTracePanelView(entry: wrapper.entry, onClose: { selectedEntry = nil })
                .padding()
        }
    }

    private var sectionHeader: some View {
        HStack {
            ScopeColorScheme.scopeBadge(for: targetScope)
            Text("Scope Contributions")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if pipeline.projection == nil {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func panelLabel(_ title: String, count: Int, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.callout)
            Text(title)
                .font(.callout.weight(.medium))
            Spacer()
            Text("\(count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(count > 0 ? color : Color.secondary, in: Capsule())
        }
    }

    @ViewBuilder
    private func entryList(_ entries: [ResolvedSettingsEntry], kind: ContributionKind) -> some View {
        if entries.isEmpty {
            Text("None")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.vertical, 4)
                .padding(.leading, 24)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.keyPath) { _, entry in
                    entryRow(entry, kind: kind)
                    if entry.keyPath != entries.last?.keyPath {
                        Divider().padding(.leading, 24)
                    }
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.secondary.opacity(0.1))
            )
        }
    }

    private func entryRow(_ entry: ResolvedSettingsEntry, kind: ContributionKind) -> some View {
        Button {
            selectedEntry = ContributionEntry(entry: entry)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.keyPath)
                        .font(.caption.monospaced().weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if kind == .losses {
                        // Show this scope's overridden value with strikethrough, plus winner
                        let overriddenSource = entry.value.trace.overridden.first { $0.scope == targetScope }
                        let winnerScope = entry.value.winningSource?.scope
                        HStack(spacing: 4) {
                            if let winVal = entry.value.effectiveValue {
                                Text(formatValue(winVal))
                                    .font(.caption2.monospaced())
                                    .strikethrough()
                                    .foregroundStyle(.secondary)
                            }
                            if let ws = winnerScope {
                                Text("→")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                ScopeColorScheme.scopeBadge(for: ws)
                            } else if let id = overriddenSource?.identifier {
                                Text(id)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                    } else if kind == .contributions {
                        Text("Contributed to merged value")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        if let val = entry.value.effectiveValue {
                            Text(formatValue(val))
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func formatValue(_ value: JSONValue) -> String {
        DashboardDataHelpers.formatValue(value)
    }
}

// MARK: - Supporting Types

private enum ContributionKind {
    case wins, contributions, losses
}

private struct ContributionDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack {
                    configuration.label
                    Image(systemName: configuration.isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(10)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))

            if configuration.isExpanded {
                configuration.content
                    .padding(.leading, 4)
            }
        }
    }
}

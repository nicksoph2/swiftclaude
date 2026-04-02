import SwiftUI

/// View C: The Flow Strip.
///
/// A vertical scroll through the phases of a Claude exchange, showing real
/// content from each source side-by-side, merge logic between phases, and
/// the context budget at the end.
struct FlowStripView: View {

    @EnvironmentObject private var pipeline: ConfigurationPipeline
    @StateObject private var viewModel = FlowStripViewModel()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            scrollContent
        }
        .onAppear {
            Task { @MainActor in
                viewModel.bind(to: pipeline)
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.doc")
                .foregroundStyle(.secondary)
            Text("Flow Strip")
                .font(.headline)

            Text("How your configuration becomes Claude's behaviour")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()

            Picker("Detail", selection: $viewModel.detailLevel) {
                ForEach(FlowStripViewModel.DetailLevel.allCases, id: \.self) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Scroll content

    private var scrollContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.phases) { phase in
                    phaseView(phase)
                }

                if viewModel.phases.isEmpty {
                    emptyState
                }
            }
        }
    }

    // MARK: - Phase view

    private func phaseView(_ phase: FlowPhase) -> some View {
        VStack(spacing: 0) {
            // Phase header
            phaseHeader(phase)

            // Source cards (horizontal scroll)
            if !phase.sourceCards.isEmpty {
                sourceCardStrip(phase.sourceCards)
            }

            // Merge strip (if merge info exists)
            if let mergeInfo = phase.mergeInfo {
                mergeStripView(mergeInfo, color: phase.color)
            }

            // Budget bar (for assembly phase)
            if let budgetInfo = phase.budgetInfo {
                budgetBarView(budgetInfo)
            }
        }
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func phaseHeader(_ phase: FlowPhase) -> some View {
        HStack(spacing: 10) {
            // Phase number circle
            Text("\(phase.number)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(phase.color)
                .frame(width: 22, height: 22)
                .overlay(
                    Circle().strokeBorder(phase.color, lineWidth: 1.5)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(phase.title)
                    .font(.system(size: 12, weight: .semibold))
                Text(phase.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(phase.summary)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar.opacity(0.5))
        .overlay(alignment: .bottom) { Divider().opacity(0.5) }
    }

    // MARK: - Source card strip

    private func sourceCardStrip(_ cards: [FlowSourceCard]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(cards) { card in
                    sourceCardView(card)
                }
            }
            .padding(12)
        }
    }

    private func sourceCardView(_ card: FlowSourceCard) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card header
            HStack(spacing: 6) {
                Circle()
                    .fill(ScopeColorScheme.color(for: card.scope))
                    .frame(width: 7, height: 7)
                Text(card.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                ScopeChipView(scope: card.scope, label: "", status: .neutral)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar.opacity(0.3))
            .overlay(alignment: .bottom) { Divider().opacity(0.5) }

            // Card entries
            VStack(alignment: .leading, spacing: 0) {
                let maxEntries = viewModel.detailLevel == .glance ? 4 :
                    (viewModel.detailLevel == .scan ? 8 : card.entries.count)

                ForEach(Array(card.entries.prefix(maxEntries))) { entry in
                    sourceEntryRow(entry)
                }

                if card.entries.count > maxEntries {
                    Text("… +\(card.entries.count - maxEntries) more")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(minWidth: 220, maxWidth: 280)
        .background(.quaternary.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.quaternary.opacity(0.3), lineWidth: 1)
        )
    }

    private func sourceEntryRow(_ entry: FlowSourceEntry) -> some View {
        HStack(spacing: 6) {
            Text(entry.key)
                .font(.system(size: 10, design: entry.status == .info ? .default : .monospaced))
                .foregroundStyle(entryKeyColor(entry.status))
                .lineLimit(1)

            Spacer()

            if !entry.value.isEmpty {
                Text(entry.value)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            entryStatusBadge(entry.status)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.2).padding(.leading, 12)
        }
    }

    private func entryKeyColor(_ status: FlowSourceEntry.EntryStatus) -> Color {
        switch status {
        case .found, .winner: .primary
        case .absent: .secondary.opacity(0.4)
        case .overridden: .secondary.opacity(0.5)
        case .contributor: .orange
        case .info: .secondary
        }
    }

    @ViewBuilder
    private func entryStatusBadge(_ status: FlowSourceEntry.EntryStatus) -> some View {
        switch status {
        case .found:
            Text("found")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.green)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        case .absent:
            Text("absent")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.quaternary.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        case .winner:
            Text("✓")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.green)
        case .overridden:
            Text("✗")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.red.opacity(0.6))
        case .contributor:
            Text("⊕")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.orange)
        case .info:
            EmptyView()
        }
    }

    // MARK: - Merge strip

    private func mergeStripView(_ info: FlowMergeInfo, color: Color) -> some View {
        HStack(spacing: 8) {
            // Merge arrow
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 9, weight: .semibold))
                Text(info.description)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(color)

            // Method badges
            ForEach(info.methods, id: \.self) { method in
                Text(method)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }

            Spacer()

            // Resolved chips
            ForEach(info.resolvedChips, id: \.self) { chip in
                Text(chip)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Color.green.opacity(0.15), lineWidth: 0.8)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar.opacity(0.3))
        .overlay(alignment: .top) { Divider().opacity(0.5) }
        .overlay(alignment: .bottom) { Divider().opacity(0.5) }
    }

    // MARK: - Budget bar

    private func budgetBarView(_ info: FlowBudgetInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Bar
            GeometryReader { geo in
                let totalWidth = geo.size.width
                HStack(spacing: 0) {
                    ForEach(info.segments) { segment in
                        let fraction = CGFloat(segment.tokens) / CGFloat(info.contextWindow)
                        Rectangle()
                            .fill(segment.color.opacity(0.3))
                            .frame(width: max(totalWidth * fraction, 2))
                            .overlay {
                                if totalWidth * fraction > 50 {
                                    Text(segment.label)
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                }
                            }
                    }

                    // Available space
                    Rectangle()
                        .fill(.quaternary.opacity(0.1))
                }
            }
            .frame(height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.quaternary.opacity(0.3), lineWidth: 1)
            )

            // Summary text
            HStack(spacing: 16) {
                ForEach(info.segments) { segment in
                    HStack(spacing: 4) {
                        Circle().fill(segment.color.opacity(0.5)).frame(width: 5, height: 5)
                        Text("\(segment.label) \(formatTokenCount(segment.tokens))")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text("\(formatTokenCount(info.usedTokens)) used of \(formatTokenCount(info.contextWindow))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1000 {
            return "\(count / 1000)K"
        }
        return "\(count)"
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 28))
                .foregroundStyle(.secondary.opacity(0.4))
            Text("No configuration loaded")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("Select a Claude root directory to see the flow")
                .font(.system(size: 11))
                .foregroundStyle(.secondary.opacity(0.6))
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}

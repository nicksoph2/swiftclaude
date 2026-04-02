import SwiftUI

// MARK: - Composite Stage Mini-Diagram

/// Shown inside the zoomed detail area when the user taps a composite group
/// in simplified mode. Renders the constituent stages as a mini-diagram so
/// the user can tap one to zoom into its full detail.
struct CompositeStageMiniDiagram: View {

    let group: CompositeStageGroup
    @Binding var selectedStage: PipelineStage?
    @ObservedObject var viewModel: TreePipelineViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(group.title)
                .font(.title2.weight(.semibold))
                .padding(.bottom, 4)

            Text("Tap a stage to explore its detail.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                ForEach(group.constituentStages) { stage in
                    constituentCard(for: stage)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func constituentCard(for stage: PipelineStage) -> some View {
        let health = viewModel.stageHealth(for: stage)

        VStack(spacing: 8) {
            Image(systemName: stage.icon)
                .font(.system(size: 22))
                .foregroundStyle(Color.accentColor)

            Text(stage.title)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            healthIndicator(for: health)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(healthColor(for: health).opacity(0.5), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                selectedStage = stage
            }
        }
        .accessibilityLabel("\(stage.title). Tap to view detail.")
    }

    @ViewBuilder
    private func healthIndicator(for health: StageHealth) -> some View {
        switch health {
        case .healthy:
            Label("Healthy", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .warnings(let n):
            Label("\(n) warning\(n == 1 ? "" : "s")", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        case .errors(let n):
            Label("\(n) error\(n == 1 ? "" : "s")", systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        case .noData:
            Label("No data", systemImage: "circle.dashed")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func healthColor(for health: StageHealth) -> Color {
        switch health {
        case .healthy:   .green
        case .warnings:  .orange
        case .errors:    .red
        case .noData:    .secondary
        }
    }
}

// MARK: - Simplified Diagram View

/// Three composite node cards for new users. Tapping a card zooms in to
/// show the constituent stages as a mini-diagram rather than jumping to
/// a single stage's detail directly.
struct PipelineSimplifiedView: View {

    @Binding var selectedStage: PipelineStage?
    /// Which composite group is currently expanded (showing its mini-diagram).
    @Binding var selectedGroup: CompositeStageGroup?
    @ObservedObject var viewModel: TreePipelineViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Composite node row
            HStack(spacing: 12) {
                ForEach(CompositeStageGroup.allCases) { group in
                    compositeCard(for: group)
                }
            }
            .padding(16)

            // Mini-diagram area (visible when a group is tapped)
            if let group = selectedGroup {
                Divider()
                ScrollView {
                    CompositeStageMiniDiagram(
                        group: group,
                        selectedStage: $selectedStage,
                        viewModel: viewModel
                    )
                    .padding(.top, 8)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedGroup)
        .frame(minHeight: 160, idealHeight: selectedGroup == nil ? 180 : 380)
    }

    // MARK: - Composite Card

    @ViewBuilder
    private func compositeCard(for group: CompositeStageGroup) -> some View {
        let isSelected = selectedGroup == group
        let worstHealth = worstHealth(for: group)

        VStack(spacing: 8) {
            Image(systemName: group.icon)
                .font(.system(size: 24))
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)

            Text(group.title)
                .font(.system(size: 13, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            compositeMetric(for: group)

            healthDot(for: worstHealth)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isSelected ? healthColor(for: worstHealth) : Color.clear,
                    lineWidth: 2
                )
        )
        .shadow(color: .black.opacity(isSelected ? 0.14 : 0.06),
                radius: isSelected ? 6 : 3,
                y: isSelected ? 3 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                selectedGroup = isSelected ? nil : group
            }
        }
        .accessibilityLabel("\(group.title). Tap to explore constituent stages.")
    }

    // MARK: - Composite Metric Label

    @ViewBuilder
    private func compositeMetric(for group: CompositeStageGroup) -> some View {
        let stages = group.constituentStages
        let count = stages.count
        Text("\(count) stage\(count == 1 ? "" : "s")")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
    }

    // MARK: - Health Helpers

    @ViewBuilder
    private func healthDot(for health: StageHealth) -> some View {
        Circle()
            .fill(healthColor(for: health))
            .frame(width: 8, height: 8)
    }

    private func worstHealth(for group: CompositeStageGroup) -> StageHealth {
        let healths = group.constituentStages.map { viewModel.stageHealth(for: $0) }
        if healths.contains(where: { if case .errors = $0 { return true } else { return false } }) {
            let count = healths.reduce(0) { acc, h in
                if case .errors(let n) = h { return acc + n }
                return acc
            }
            return .errors(count)
        }
        if healths.contains(where: { if case .warnings = $0 { return true } else { return false } }) {
            let count = healths.reduce(0) { acc, h in
                if case .warnings(let n) = h { return acc + n }
                return acc
            }
            return .warnings(count)
        }
        if healths.allSatisfy({ $0 == .healthy }) { return .healthy }
        return .noData
    }

    private func healthColor(for health: StageHealth) -> Color {
        switch health {
        case .healthy:   .green
        case .warnings:  .orange
        case .errors:    .red
        case .noData:    .secondary
        }
    }
}

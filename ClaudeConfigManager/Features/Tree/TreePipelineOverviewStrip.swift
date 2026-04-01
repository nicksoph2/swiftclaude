import SwiftUI

/// Compact horizontal strip showing all 8 pipeline stages as connected nodes.
///
/// Each node displays the stage's SF Symbol icon, caption-sized name, and a
/// health badge (colored circle). Nodes are connected by chevron arrows.
/// Tapping a node updates `selectedStage` which the parent view uses to
/// scroll the detail region via `ScrollViewReader`.
struct TreePipelineOverviewStrip: View {

    @Binding var selectedStage: PipelineStage?
    @ObservedObject var viewModel: TreePipelineViewModel

    /// Closure invoked when the user taps a stage node.
    /// The parent should use this to trigger a `ScrollViewReader.scrollTo`.
    var onStageSelected: ((PipelineStage) -> Void)?

    private let stages = PipelineStage.allCases.sorted { $0.sortOrder < $1.sortOrder }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(stages.enumerated()), id: \.element) { index, stage in
                    if index > 0 {
                        connectorArrow
                    }

                    stageNode(for: stage)
                        .onTapGesture {
                            selectedStage = stage
                            onStageSelected?(stage)
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func stageNode(for stage: PipelineStage) -> some View {
        let isSelected = selectedStage == stage
        let health = viewModel.stageHealth(for: stage)

        VStack(spacing: 4) {
            Image(systemName: stage.icon)
                .font(.system(size: 16))
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)

            Text(stage.title)
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(isSelected ? Color.accentColor : .primary)

            healthBadge(for: health)
        }
        .frame(minWidth: 72)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func healthBadge(for health: StageHealth) -> some View {
        switch health {
        case .healthy:
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
        case .warnings(let count):
            HStack(spacing: 2) {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                Text("\(count)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.orange)
            }
        case .errors(let count):
            HStack(spacing: 2) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Text("\(count)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.red)
            }
        case .noData:
            Circle()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 8, height: 8)
        }
    }

    private var connectorArrow: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.quaternary)
    }
}

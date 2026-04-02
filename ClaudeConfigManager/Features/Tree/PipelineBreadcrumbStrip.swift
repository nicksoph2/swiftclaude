import SwiftUI

/// A compact horizontal breadcrumb strip displayed when a stage is zoomed in.
///
/// Shows all eight stages as icon-only nodes. The currently selected stage is
/// highlighted with its health-colour border. Tapping the selected stage (or
/// the back button) returns to the overview. Tapping any other stage switches
/// the zoom to that stage.
struct PipelineBreadcrumbStrip: View {

    @Binding var selectedStage: PipelineStage?
    @ObservedObject var viewModel: TreePipelineViewModel
    var namespace: Namespace.ID

    private let stages = PipelineStage.allCases.sorted { $0.sortOrder < $1.sortOrder }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // Back button
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedStage = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Pipeline")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to Pipeline overview")

                Divider()
                    .frame(height: 24)
                    .padding(.horizontal, 2)

                ForEach(stages) { stage in
                    breadcrumbNode(for: stage)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    // MARK: - Breadcrumb Node

    @ViewBuilder
    private func breadcrumbNode(for stage: PipelineStage) -> some View {
        let isSelected = selectedStage == stage
        let health = viewModel.stageHealth(for: stage)
        let borderColor = healthColor(for: health)

        VStack(spacing: 3) {
            Image(systemName: stage.icon)
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)

            healthDot(for: health)
        }
        .frame(width: 36, height: 42)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(
                    isSelected ? borderColor : Color.secondary.opacity(0.2),
                    lineWidth: isSelected ? 2 : 0.5
                )
        )
        // matchedGeometryEffect ties this node to its diagram counterpart
        .matchedGeometryEffect(id: stage, in: namespace)
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelected {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    selectedStage = nil
                }
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    selectedStage = stage
                }
            }
        }
        .accessibilityLabel(accessibilityLabel(for: stage, health: health, isSelected: isSelected))
    }

    // MARK: - Health Dot

    @ViewBuilder
    private func healthDot(for health: StageHealth) -> some View {
        Circle()
            .fill(healthColor(for: health))
            .frame(width: 6, height: 6)
    }

    // MARK: - Helpers

    private func healthColor(for health: StageHealth) -> Color {
        switch health {
        case .healthy:   .green
        case .warnings:  .orange
        case .errors:    .red
        case .noData:    .secondary
        }
    }

    private func accessibilityLabel(for stage: PipelineStage, health: StageHealth, isSelected: Bool) -> String {
        let healthDesc: String
        switch health {
        case .healthy:           healthDesc = "healthy"
        case .warnings(let n):   healthDesc = "\(n) warning\(n == 1 ? "" : "s")"
        case .errors(let n):     healthDesc = "\(n) error\(n == 1 ? "" : "s")"
        case .noData:            healthDesc = "no data"
        }

        if isSelected {
            return "\(stage.title) stage, currently showing detail. Tap to return to overview."
        } else {
            return "\(stage.title) stage. \(healthDesc). Tap to switch."
        }
    }
}

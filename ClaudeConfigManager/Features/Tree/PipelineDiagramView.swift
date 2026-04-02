import SwiftUI

// MARK: - Stage Status (mock-friendly model)

/// Snapshot of a single pipeline stage for the diagram.
struct PipelineStageStatus: Identifiable, Sendable {
    let id: String
    let stage: PipelineStage
    let health: StageHealth
    let metricLabel: String            // e.g. "9 files", "3 issues"
    let activeScopes: [ResolutionScope]

    init(
        stage: PipelineStage,
        health: StageHealth = .noData,
        metricLabel: String = "",
        activeScopes: [ResolutionScope] = []
    ) {
        self.id = stage.rawValue
        self.stage = stage
        self.health = health
        self.metricLabel = metricLabel
        self.activeScopes = activeScopes
    }

    // MARK: Preview Data

    /// Realistic mock data covering all eight stages.
    static var preview: [PipelineStageStatus] {
        [
            PipelineStageStatus(
                stage: .discovery,
                health: .healthy,
                metricLabel: "9 files",
                activeScopes: [.managed, .user, .project, .projectLocal]
            ),
            PipelineStageStatus(
                stage: .parsing,
                health: .warnings(2),
                metricLabel: "7 parsed",
                activeScopes: [.managed, .user, .project]
            ),
            PipelineStageStatus(
                stage: .resolution,
                health: .errors(1),
                metricLabel: "3 issues",
                activeScopes: [.managed, .user, .project, .cli]
            ),
            PipelineStageStatus(
                stage: .promptAssembly,
                health: .healthy,
                metricLabel: "18K tokens",
                activeScopes: [.user, .project]
            ),
            PipelineStageStatus(
                stage: .toolExecution,
                health: .healthy,
                metricLabel: "12 tools",
                activeScopes: [.project, .user]
            ),
            PipelineStageStatus(
                stage: .hooksLifecycle,
                health: .warnings(1),
                metricLabel: "4 hooks",
                activeScopes: [.project]
            ),
            PipelineStageStatus(
                stage: .mcpServers,
                health: .healthy,
                metricLabel: "3 servers",
                activeScopes: [.project, .user]
            ),
            PipelineStageStatus(
                stage: .contextBudget,
                health: .noData,
                metricLabel: "—",
                activeScopes: []
            ),
        ]
    }
}

// MARK: - Pipeline Diagram View

/// The unified interactive pipeline diagram — a Canvas-backed view showing
/// all eight stages as connected node cards in a single, non-scrolling layout.
struct PipelineDiagramView: View {

    @Binding var selectedStage: PipelineStage?
    @ObservedObject var viewModel: TreePipelineViewModel

    /// Namespace shared with the breadcrumb strip so `matchedGeometryEffect` can
    /// animate nodes between diagram positions and breadcrumb positions.
    var namespace: Namespace.ID

    /// Closure invoked when the user taps a stage node.
    var onStageSelected: ((PipelineStage) -> Void)?

    // MARK: - Arrow Interaction State

    /// The currently tapped arrow edge (for flow panel presentation).
    @State private var selectedEdge: DiagramEdge?

    /// The currently tapped warning dot (for propagation panel presentation).
    @State private var selectedWarningEdge: EdgeHealthState?

    /// Whether the flow panel is shown as a sheet (narrow window).
    @State private var showFlowSheet = false

    /// Whether the warning panel is shown as a sheet (narrow window).
    @State private var showWarningSheet = false

    /// The hovered arrow edge id (for hit-test hover highlight).
    @State private var hoveredEdgeID: String?

    @State private var hoveredStage: PipelineStage?

    // MARK: - Computed Properties

    /// Stage statuses built from the view model.
    private var stageStatuses: [PipelineStage: PipelineStageStatus] {
        var map = [PipelineStage: PipelineStageStatus]()
        for entry in viewModel.stageHealthEntries {
            map[entry.stage] = PipelineStageStatus(
                stage: entry.stage,
                health: entry.health
            )
        }
        return map
    }

    /// Per-edge health propagation states.
    private var edgeHealthStates: [String: EdgeHealthState] {
        var healthMap = [PipelineStage: StageHealth]()
        for entry in viewModel.stageHealthEntries {
            healthMap[entry.stage] = entry.health
        }
        return EdgeHealthPropagator.compute(stageHealthMap: healthMap)
    }

    var body: some View {
        GeometryReader { geo in
            let scale = DiagramLayout.scaleFactor(for: geo.size)

            ZStack {
                // Arrow layer (behind cards)
                arrowLayer(scale: scale)

                // Node cards
                ForEach(PipelineStage.allCases.sorted(by: { $0.sortOrder < $1.sortOrder })) { stage in
                    if let centre = DiagramLayout.nodePositions[stage] {
                        let status = stageStatuses[stage] ?? PipelineStageStatus(stage: stage)
                        nodeCard(for: status)
                            // matchedGeometryEffect ties each diagram card to the
                            // corresponding breadcrumb node for the zoom animation.
                            .matchedGeometryEffect(id: stage, in: namespace)
                            .position(centre)
                    }
                }
            }
            .frame(width: DiagramLayout.designSize.width,
                   height: DiagramLayout.designSize.height)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
        .frame(minHeight: 200, idealHeight: 340, maxHeight: 400)
        // Flow panel sheet (narrow window)
        .sheet(isPresented: $showFlowSheet) {
            if let edge = selectedEdge {
                FlowPanelView(
                    edge: edge,
                    sourceMetric: metricLabel(for: edge.from),
                    destMetric: edge.from != edge.to ? metricLabel(for: edge.to) : nil,
                    onNavigateToStage: { stage in
                        showFlowSheet = false
                        selectedStage = stage
                        onStageSelected?(stage)
                    },
                    onDismiss: { showFlowSheet = false }
                )
            }
        }
        // Warning panel sheet (narrow window)
        .sheet(isPresented: $showWarningSheet) {
            if let state = selectedWarningEdge {
                EdgeWarningPanelView(
                    edgeHealth: state,
                    onShowSource: { stage in
                        showWarningSheet = false
                        selectedStage = stage
                        onStageSelected?(stage)
                    },
                    onDismiss: { showWarningSheet = false }
                )
            }
        }
    }

    // MARK: - Arrow Layer

    /// Renders:
    ///  - Invisible wide stroke as tap target (20pt)
    ///  - Visible narrow stroke (1.5pt)
    ///  - Health warning dots at midpoints
    @ViewBuilder
    private func arrowLayer(scale: CGFloat) -> some View {
        ZStack {
            // Visible canvas arrows (not tappable)
            Canvas { context, _ in
                for conn in DiagramLayout.connections {
                    let edgeID = "\(conn.from.rawValue)→\(conn.to.rawValue)"
                    let isHovered = hoveredEdgeID == edgeID
                    let linePath = DiagramLayout.arrowPath(from: conn.from, to: conn.to)

                    // Hover highlight
                    if isHovered {
                        context.stroke(
                            linePath,
                            with: .color(Color.accentColor.opacity(0.3)),
                            lineWidth: 4
                        )
                    }

                    context.stroke(
                        linePath,
                        with: .color(.secondary.opacity(isHovered ? 0.85 : 0.5)),
                        lineWidth: 1.5
                    )

                    let headPath = DiagramLayout.arrowheadPath(from: conn.from, to: conn.to)
                    context.fill(headPath, with: .color(.secondary.opacity(isHovered ? 0.85 : 0.5)))
                }
            }
            .frame(width: DiagramLayout.designSize.width,
                   height: DiagramLayout.designSize.height)
            .allowsHitTesting(false)

            // Invisible wide-stroke tap targets (one per edge)
            ForEach(DiagramEdge.all.filter { $0.from != $0.to }, id: \.id) { edge in
                let path = DiagramLayout.arrowPath(from: edge.from, to: edge.to)
                ArrowTapTarget(
                    edge: edge,
                    path: path,
                    hoveredEdgeID: $hoveredEdgeID,
                    onTap: { tappedEdge in
                        selectedEdge = tappedEdge
                        showFlowSheet = true
                    }
                )
            }

            // Health warning dots
            ForEach(DiagramEdge.all.filter { $0.from != $0.to }, id: \.id) { edge in
                if let state = edgeHealthStates[edge.id],
                   state.hasPropagatedIssue,
                   let midPt = DiagramLayout.arrowMidpoint(from: edge.from, to: edge.to) {
                    let color: Color = state.worstSeverity == .error ? .red : .orange
                    HealthDotButton(
                        state: state,
                        color: color,
                        position: midPt,
                        onTap: {
                            selectedWarningEdge = state
                            showWarningSheet = true
                        }
                    )
                }
            }
        }
    }

    // MARK: - Node Card

    @ViewBuilder
    private func nodeCard(for status: PipelineStageStatus) -> some View {
        let isSelected = selectedStage == status.stage
        let isHovered  = hoveredStage == status.stage

        VStack(spacing: 6) {
            // Icon
            Image(systemName: status.stage.icon)
                .font(.system(size: 20))
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)

            // Stage name
            Text(status.stage.title)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // Health indicator + metric on same row
            HStack(spacing: 6) {
                healthDot(for: status.health)
                if !status.metricLabel.isEmpty {
                    Text(status.metricLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // Scope contribution dots
            if !status.activeScopes.isEmpty {
                HStack(spacing: 3) {
                    ForEach(status.activeScopes, id: \.rawValue) { scope in
                        Circle()
                            .fill(ScopeColorScheme.color(for: scope))
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
        .frame(width: DiagramLayout.nodeSize.width,
               height: DiagramLayout.nodeSize.height)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isSelected ? cardBorderColor(for: status.health) : Color.clear,
                    lineWidth: 2
                )
        )
        .shadow(color: .black.opacity(isHovered ? 0.18 : 0.06),
                radius: isHovered ? 8 : 3,
                y: isHovered ? 4 : 1)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredStage = hovering ? status.stage : nil
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedStage = status.stage
            onStageSelected?(status.stage)
        }
        .accessibilityLabel(accessibilityLabel(for: status))
        .accessibilityHint("Tap to expand")
        .accessibilityAddTraits(.isButton)
    }

    private func accessibilityLabel(for status: PipelineStageStatus) -> String {
        let healthLabel: String
        switch status.health {
        case .healthy:
            healthLabel = "healthy"
        case .warnings(let count):
            healthLabel = "\(count) warning\(count == 1 ? "" : "s")"
        case .errors(let count):
            healthLabel = "\(count) error\(count == 1 ? "" : "s")"
        case .noData:
            healthLabel = "no data"
        }
        return "\(status.stage.title) stage, \(healthLabel), tap to expand"
    }

    // MARK: - Health Dot

    @ViewBuilder
    private func healthDot(for health: StageHealth) -> some View {
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

    // MARK: - Helpers

    private func cardBorderColor(for health: StageHealth) -> Color {
        switch health {
        case .healthy:       .green
        case .warnings:      .orange
        case .errors:        .red
        case .noData:        .secondary
        }
    }

    private func metricLabel(for stage: PipelineStage) -> String? {
        let status = stageStatuses[stage]
        guard let label = status?.metricLabel, !label.isEmpty, label != "—" else { return nil }
        return label
    }
}

// MARK: - Arrow Tap Target

/// An invisible wide-stroke overlay that provides the tap area for a single arrow.
private struct ArrowTapTarget: View {

    let edge: DiagramEdge
    let path: Path
    @Binding var hoveredEdgeID: String?
    var onTap: (DiagramEdge) -> Void

    var body: some View {
        path
            .stroke(Color.clear, lineWidth: 20)
            .contentShape(path.strokedPath(StrokeStyle(lineWidth: 20)))
            .onHover { hovering in
                hoveredEdgeID = hovering ? edge.id : nil
            }
            .onTapGesture {
                onTap(edge)
            }
    }
}

// MARK: - Health Dot Button

/// A small tappable dot rendered at the midpoint of an arrow to indicate propagated issues.
private struct HealthDotButton: View {

    let state: EdgeHealthState
    let color: Color
    let position: CGPoint
    var onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        ZStack {
            // Glow / hover ring
            if isHovered {
                Circle()
                    .fill(color.opacity(0.25))
                    .frame(width: 22, height: 22)
            }

            // Dot
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.8), lineWidth: 1.5)
                )

            // Count badge (if > 1)
            if state.propagatedIssues.count > 1 {
                Text("\(state.propagatedIssues.count)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .position(position)
        .contentShape(Circle().size(CGSize(width: 24, height: 24)).offset(
            x: position.x - 12, y: position.y - 12
        ))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onTap()
        }
        .help(helpText)
    }

    private var helpText: String {
        let count = state.propagatedIssues.count
        let severity = state.worstSeverity == .error ? "error" : "warning"
        return "\(count) upstream \(severity)\(count == 1 ? "" : "s") affecting this stage"
    }
}

// MARK: - Preview

#Preview("Pipeline Diagram") {
    PipelineDiagramPreviewWrapper()
        .frame(width: 920, height: 400)
        .padding()
}

#Preview("Pipeline Diagram — Mock Data") {
    PipelineDiagramMockPreview()
        .frame(width: 920, height: 400)
        .padding()
}

/// Preview wrapper that owns the @Namespace.
private struct PipelineDiagramPreviewWrapper: View {
    @Namespace private var ns
    @State private var selected: PipelineStage? = .discovery

    var body: some View {
        PipelineDiagramView(
            selectedStage: $selected,
            viewModel: TreePipelineViewModel(),
            namespace: ns,
            onStageSelected: { _ in }
        )
    }
}

/// Helper view that renders the diagram with mock data for fast iteration.
private struct PipelineDiagramMockPreview: View {
    @Namespace private var ns
    @State private var selected: PipelineStage? = .resolution

    var body: some View {
        PipelineDiagramView(
            selectedStage: $selected,
            viewModel: TreePipelineViewModel(),
            namespace: ns,
            onStageSelected: { _ in }
        )
    }
}

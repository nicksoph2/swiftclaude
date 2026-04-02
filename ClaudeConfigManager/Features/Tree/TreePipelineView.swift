import SwiftUI

/// Root view for the Pipeline (Tree) destination.
///
/// Supports two top-level display modes:
/// - **Advanced** (8 nodes): full `PipelineDiagramView` + scrollable stage sections.
/// - **Simplified** (3 composite nodes): `PipelineSimplifiedView` for new users.
///
/// In advanced mode, tapping a node zooms in: the diagram is replaced by
/// `PipelineZoomedView` (breadcrumb strip + full detail). A `matchedGeometryEffect`
/// namespace shared between `PipelineDiagramView` and `PipelineBreadcrumbStrip`
/// drives the spring animation.
///
/// Mode preference is stored in `AppStorage`. First-run defaults to `.simplified`.
struct TreePipelineView: View {

    @EnvironmentObject private var pipeline: ConfigurationPipeline
    @StateObject private var viewModel = TreePipelineViewModel()

    // MARK: - Mode Persistence

    /// Whether the user has ever activated advanced mode. Used for first-run default.
    @AppStorage("hasActivatedAdvancedMode") private var hasActivatedAdvancedMode: Bool = false

    /// The stored raw value for diagram mode.
    @AppStorage("diagramMode") private var diagramModeRaw: String = DiagramMode.simplified.rawValue

    private var diagramMode: DiagramMode {
        DiagramMode(rawValue: diagramModeRaw) ?? .simplified
    }

    private func setDiagramMode(_ mode: DiagramMode) {
        diagramModeRaw = mode.rawValue
        if mode == .advanced {
            hasActivatedAdvancedMode = true
        }
    }

    // MARK: - Zoom State (advanced mode)

    /// Namespace shared between PipelineDiagramView and PipelineBreadcrumbStrip.
    @Namespace private var diagramNamespace

    // MARK: - Simplified Mode State

    /// Which composite group is tapped in simplified mode (nil = none).
    @State private var selectedGroup: CompositeStageGroup? = nil

    // MARK: - Scroll / Navigation (advanced overview)

    @State private var scrollTarget: PipelineStage?

    /// Cross-stage navigation target. When set, the view expands the target stage,
    /// updates the strip selection, and scrolls to the target's anchor.
    @State private var navigationTarget: TreeNavigationTarget?

    // MARK: - Collapse State Persistence

    /// Persisted set of collapsed stage raw values, encoded as comma-separated string.
    @SceneStorage("treeCollapsedStages") private var collapsedStagesStorage: String = ""

    private var collapsedStages: Set<String> {
        Set(collapsedStagesStorage.split(separator: ",").map(String.init))
    }

    private func setCollapsed(_ collapsed: Bool, for stage: PipelineStage) {
        var current = collapsedStages
        if collapsed {
            current.insert(stage.rawValue)
        } else {
            current.remove(stage.rawValue)
        }
        collapsedStagesStorage = current.sorted().joined(separator: ",")
    }

    private func isExpanded(for stage: PipelineStage) -> Binding<Bool> {
        Binding<Bool>(
            get: { !collapsedStages.contains(stage.rawValue) },
            set: { newValue in setCollapsed(!newValue, for: stage) }
        )
    }

    // MARK: - Stages

    private let stages = PipelineStage.allCases.sorted { $0.sortOrder < $1.sortOrder }

    // MARK: - Body

    var body: some View {
        Group {
            if diagramMode == .simplified {
                simplifiedLayout
            } else {
                advancedLayout
            }
        }
        .navigationTitle("Pipeline")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                modeToggleButton
            }
        }
        .onAppear {
            viewModel.bind(to: pipeline)
        }
        // Escape key returns to overview when a stage is zoomed
        .onKeyPress(.escape) {
            if viewModel.selectedStage != nil {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    viewModel.selectedStage = nil
                }
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - Mode Toggle Button

    private var modeToggleButton: some View {
        Button {
            let newMode: DiagramMode = (diagramMode == .simplified) ? .advanced : .simplified
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                setDiagramMode(newMode)
                // Reset zoom / group selection when switching modes
                viewModel.selectedStage = nil
                selectedGroup = nil
            }
        } label: {
            Text(diagramMode == .simplified ? "Advanced" : "Overview")
                .font(.subheadline.weight(.medium))
        }
        .help(diagramMode == .simplified
              ? "Switch to Advanced mode — shows all eight pipeline stages"
              : "Switch to Overview mode — shows three plain-English groups")
    }

    // MARK: - Simplified Layout

    private var simplifiedLayout: some View {
        VStack(spacing: 0) {
            PipelineSimplifiedView(
                selectedStage: Binding(
                    get: { viewModel.selectedStage },
                    set: { viewModel.selectedStage = $0 }
                ),
                selectedGroup: $selectedGroup,
                viewModel: viewModel
            )

            Divider()

            // When a constituent stage is selected via the mini-diagram,
            // show its full detail in a zoomed view.
            if viewModel.selectedStage != nil {
                PipelineZoomedView(
                    selectedStage: Binding(
                        get: { viewModel.selectedStage },
                        set: { viewModel.selectedStage = $0 }
                    ),
                    viewModel: viewModel,
                    namespace: diagramNamespace,
                    onNavigate: { target in
                        navigationTarget = target
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.selectedStage)
    }

    // MARK: - Advanced Layout

    private var advancedLayout: some View {
        VStack(spacing: 0) {
            if viewModel.selectedStage != nil {
                // Zoomed mode: breadcrumb + detail
                PipelineZoomedView(
                    selectedStage: Binding(
                        get: { viewModel.selectedStage },
                        set: { viewModel.selectedStage = $0 }
                    ),
                    viewModel: viewModel,
                    namespace: diagramNamespace,
                    onNavigate: { target in
                        navigationTarget = target
                    }
                )
                .transition(.opacity)
            } else {
                // Overview mode: diagram + scrollable sections
                PipelineDiagramView(
                    selectedStage: Binding(
                        get: { viewModel.selectedStage },
                        set: { viewModel.selectedStage = $0 }
                    ),
                    viewModel: viewModel,
                    namespace: diagramNamespace,
                    onStageSelected: { stage in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            viewModel.selectedStage = stage
                        }
                    }
                )
                .transition(.opacity)

                Divider()

                // Scrollable stage sections
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(stages) { stage in
                                stageSection(for: stage)
                                    .id(stage)
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: scrollTarget) { _, target in
                        guard let target else { return }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(target, anchor: .top)
                        }
                        scrollTarget = nil
                    }
                    .onChange(of: navigationTarget) { _, target in
                        guard let target else { return }
                        handleNavigation(target, proxy: proxy)
                        navigationTarget = nil
                    }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.selectedStage)
    }

    // MARK: - Stage Section

    @ViewBuilder
    private func stageSection(for stage: PipelineStage) -> some View {
        DisclosureGroup(
            isExpanded: isExpanded(for: stage)
        ) {
            stageContent(for: stage)
                .padding(.top, 8)
        } label: {
            stageHeader(for: stage)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func stageHeader(for stage: PipelineStage) -> some View {
        HStack(spacing: 8) {
            Image(systemName: stage.icon)
                .font(.title3)
                .foregroundStyle(viewModel.selectedStage == stage ? Color.accentColor : .secondary)
                .frame(width: 24)

            Text(stage.title)
                .font(.headline)

            Spacer()

            healthBadgeLabel(for: viewModel.stageHealth(for: stage))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedStage = stage
        }
    }

    @ViewBuilder
    private func healthBadgeLabel(for health: StageHealth) -> some View {
        switch health {
        case .healthy:
            Label("Healthy", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .warnings(let count):
            Label("\(count) warning\(count == 1 ? "" : "s")", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        case .errors(let count):
            Label("\(count) error\(count == 1 ? "" : "s")", systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        case .noData:
            Label("No data", systemImage: "circle.dashed")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Content for each stage.
    @ViewBuilder
    private func stageContent(for stage: PipelineStage) -> some View {
        switch stage {
        case .discovery:
            TreeDiscoveryView(onNavigate: { target in
                navigationTarget = target
            })
        case .parsing:
            TreeParsingView(onNavigate: { target in
                navigationTarget = target
            })
        case .resolution:
            TreeResolutionView(onNavigate: { target in
                navigationTarget = target
            })
        case .promptAssembly:
            TreePromptAssemblyView(onNavigate: { target in
                navigationTarget = target
            })
        case .toolExecution:
            TreeToolExecutionView(onNavigate: { target in
                navigationTarget = target
            })
        case .hooksLifecycle:
            TreeHooksLifecycleView(onNavigate: { target in
                navigationTarget = target
            })
        case .mcpServers:
            TreeMCPView(onNavigate: { target in
                navigationTarget = target
            })
        case .contextBudget:
            TreeContextBudgetView(onNavigate: { target in
                navigationTarget = target
            })
        }
    }

    // MARK: - Cross-Stage Navigation

    /// Handles a cross-stage navigation request by expanding the target stage,
    /// updating the strip selection, and scrolling to the anchor.
    private func handleNavigation(_ target: TreeNavigationTarget, proxy: ScrollViewProxy) {
        let targetStage = target.targetStage

        // 1. Ensure target stage is expanded
        setCollapsed(false, for: targetStage)

        // 2. Update strip selection
        viewModel.selectedStage = targetStage

        // 3. First scroll to the stage section, then to the specific anchor
        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(targetStage, anchor: .top)
        }

        // Small delay to allow DisclosureGroup to expand before scrolling to anchor
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(target.anchorID, anchor: .top)
            }
        }
    }
}

import SwiftUI

/// Root view for the Pipeline (Tree) destination.
///
/// Layout:
/// - **Top**: `TreePipelineOverviewStrip` — fixed, non-scrollable horizontal strip
/// - **Bottom**: `ScrollViewReader` wrapping a `LazyVStack` of stage sections,
///   each as a `DisclosureGroup` with stub content (replaced by later packets).
///
/// Collapse state is persisted via `@SceneStorage`.
struct TreePipelineView: View {

    @EnvironmentObject private var pipeline: ConfigurationPipeline
    @StateObject private var viewModel = TreePipelineViewModel()

    @State private var selectedStage: PipelineStage? = .discovery

    /// Cross-stage navigation target. When set, the view expands the target stage,
    /// updates the strip selection, and scrolls to the target's anchor.
    @State private var navigationTarget: TreeNavigationTarget?

    // MARK: - Collapse State Persistence

    /// Persisted set of collapsed stage raw values, encoded as comma-separated string.
    @SceneStorage("treeCollapsedStages") private var collapsedStagesStorage: String = ""

    private var collapsedStages: Set<String> {
        get {
            Set(collapsedStagesStorage.split(separator: ",").map(String.init))
        }
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
        VStack(spacing: 0) {
            // Fixed overview strip at the top
            TreePipelineOverviewStrip(
                selectedStage: $selectedStage,
                viewModel: viewModel,
                onStageSelected: { stage in
                    scrollTarget = stage
                }
            )

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
        .navigationTitle("Pipeline")
        .onAppear {
            viewModel.bind(to: pipeline)
        }
    }

    @State private var scrollTarget: PipelineStage?

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
                .foregroundStyle(selectedStage == stage ? Color.accentColor : .secondary)
                .frame(width: 24)

            Text(stage.title)
                .font(.headline)

            Spacer()

            healthBadgeLabel(for: viewModel.stageHealth(for: stage))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedStage = stage
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

    /// Content for each stage. Stages 1–3 are live; others are placeholders.
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

    @ViewBuilder
    private func stagePlaceholder(stage: PipelineStage, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stage \(number): \(stage.title)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text("Detail view will be implemented in a future packet.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    // MARK: - Cross-Stage Navigation

    /// Handles a cross-stage navigation request by expanding the target stage,
    /// updating the strip selection, and scrolling to the anchor.
    private func handleNavigation(_ target: TreeNavigationTarget, proxy: ScrollViewProxy) {
        let targetStage = target.targetStage

        // 1. Ensure target stage is expanded
        setCollapsed(false, for: targetStage)

        // 2. Update strip selection
        selectedStage = targetStage

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

import SwiftUI

/// Shown when a stage node is tapped — displays the breadcrumb strip at the top
/// and the selected stage's full detail view below, with content fading in after
/// the node expansion animation completes.
struct PipelineZoomedView: View {

    @Binding var selectedStage: PipelineStage?
    @ObservedObject var viewModel: TreePipelineViewModel
    var namespace: Namespace.ID

    /// Cross-stage navigation callback forwarded from the detail views.
    var onNavigate: ((TreeNavigationTarget) -> Void)?

    @State private var contentVisible = false

    var body: some View {
        VStack(spacing: 0) {
            // Breadcrumb strip
            PipelineBreadcrumbStrip(
                selectedStage: $selectedStage,
                viewModel: viewModel,
                namespace: namespace
            )

            Divider()

            // Detail area
            if let stage = selectedStage {
                ScrollView {
                    stageDetailContent(for: stage)
                        .padding(16)
                }
                .opacity(contentVisible ? 1 : 0)
                .onAppear {
                    // Fade content in after the node-expansion spring settles (~0.4s)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation(.easeIn(duration: 0.2)) {
                            contentVisible = true
                        }
                    }
                }
                .onChange(of: stage) { _, _ in
                    // Brief fade when switching stages via breadcrumb
                    contentVisible = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeIn(duration: 0.15)) {
                            contentVisible = true
                        }
                    }
                }
                .id(stage) // force re-mount on stage switch
            }
        }
        .onDisappear {
            contentVisible = false
        }
    }

    // MARK: - Stage Detail Content

    @ViewBuilder
    private func stageDetailContent(for stage: PipelineStage) -> some View {
        switch stage {
        case .discovery:
            TreeDiscoveryView(onNavigate: onNavigate)
        case .parsing:
            TreeParsingView(onNavigate: onNavigate)
        case .resolution:
            TreeResolutionView(onNavigate: onNavigate)
        case .promptAssembly:
            TreePromptAssemblyView(onNavigate: onNavigate)
        case .toolExecution:
            TreeToolExecutionView(onNavigate: onNavigate)
        case .hooksLifecycle:
            TreeHooksLifecycleView(onNavigate: onNavigate)
        case .mcpServers:
            TreeMCPView(onNavigate: onNavigate)
        case .contextBudget:
            TreeContextBudgetView(onNavigate: onNavigate)
        }
    }
}

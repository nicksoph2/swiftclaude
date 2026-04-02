import SwiftUI

/// Stage 2 — Parsing detail view.
///
/// Displays a vertical stack of file cards, one per parsed file from the
/// configuration pipeline. Cards are ordered by scope (managed → user → project → local)
/// and each shows parse health, recognized/unknown keys, issues, and raw content.
///
/// Supports cross-stage navigation:
/// - Tapping a recognized key offers "View Resolution" → navigates to Resolution stage
/// - Card anchors allow scrolling from Discovery stage
struct TreeParsingView: View {

    @EnvironmentObject private var pipeline: ConfigurationPipeline
    @StateObject private var viewModel = TreeParsingViewModel()

    /// Optional binding for cross-stage navigation.
    /// Set by `TreePipelineView` to coordinate stage changes and scrolling.
    var onNavigate: ((TreeNavigationTarget) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StageExplanationView(stage: .parsing)

            if viewModel.fileSummaries.isEmpty {
                noDataPlaceholder
            } else {
                summaryBanner
                fileCardStack
            }
        }
        .onAppear {
            Task { @MainActor in viewModel.bind(to: pipeline) }
        }
    }

    // MARK: - No Data

    @ViewBuilder
    private var noDataPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No parsed files available")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Run the pipeline to parse discovered configuration files.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    // MARK: - Summary Banner

    @ViewBuilder
    private var summaryBanner: some View {
        let total = viewModel.fileSummaries.count
        let withErrors = viewModel.fileSummaries.filter { $0.errorCount > 0 }.count
        let withWarnings = viewModel.fileSummaries.filter { $0.warningCount > 0 && $0.errorCount == 0 }.count

        HStack(spacing: 16) {
            Label("\(total) file\(total == 1 ? "" : "s") parsed", systemImage: "doc.text")
                .font(.caption)
                .foregroundStyle(.secondary)

            if withErrors > 0 {
                Label(
                    "\(withErrors) with errors",
                    systemImage: "xmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(.red)
            }

            if withWarnings > 0 {
                Label(
                    "\(withWarnings) with warnings",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - File Card Stack

    @ViewBuilder
    private var fileCardStack: some View {
        LazyVStack(alignment: .leading, spacing: 10) {
            ForEach(viewModel.fileSummaries) { summary in
                ParsedFileCardView(
                    summary: summary,
                    onNavigateToResolution: { keyPath in
                        onNavigate?(.resolutionKey(keyPath))
                    }
                )
                .id("parsing-file-\(summary.record.sourceFile.absoluteString)")
            }
        }
    }
}

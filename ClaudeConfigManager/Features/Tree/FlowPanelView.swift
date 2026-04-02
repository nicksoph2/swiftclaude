import SwiftUI

// MARK: - Flow Panel View

/// Sheet / popover that explains what data flows along a pipeline edge.
///
/// Presented when the user taps an arrow in the diagram. Shows a written
/// explanation of the data flow, dynamic counts where available, and links
/// to the source and destination stages.
struct FlowPanelView: View {

    let edge: DiagramEdge

    /// Optional live metric for the source stage (e.g. "9 files").
    var sourceMetric: String?

    /// Optional live metric for the destination stage.
    var destMetric: String?

    /// Invoked when the user taps "View <Stage> stage →".
    var onNavigateToStage: ((PipelineStage) -> Void)?

    /// Dismiss callback (used when presented as a sheet).
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerBar

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Flow explanation
                    Text(edge.flowExplanation)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)

                    // Dynamic counts
                    if sourceMetric != nil || destMetric != nil {
                        dynamicCountsSection
                    }

                    Divider()

                    // Stage links
                    stageLinksSection
                }
                .padding(20)
            }
        }
        .frame(minWidth: 320, idealWidth: 380, maxWidth: 480,
               minHeight: 240, idealHeight: 320)
    }

    // MARK: - Header Bar

    @ViewBuilder
    private var headerBar: some View {
        HStack {
            Label(edge.flowTitle, systemImage: "arrow.right.circle")
                .font(.headline)
            Spacer()
            if let dismiss = onDismiss {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Dynamic Counts

    @ViewBuilder
    private var dynamicCountsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live data")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 16) {
                if let source = sourceMetric {
                    countChip(
                        label: edge.from.title,
                        value: source,
                        icon: edge.from.icon
                    )
                }
                if let dest = destMetric {
                    countChip(
                        label: edge.to.title,
                        value: dest,
                        icon: edge.to.icon
                    )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    @ViewBuilder
    private func countChip(label: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Stage Links

    @ViewBuilder
    private var stageLinksSection: some View {
        // Only show links for non-terminal edges
        if edge.from != edge.to {
            VStack(alignment: .leading, spacing: 8) {
                stageLink(stage: edge.from, label: "View \(edge.from.title) stage")
                stageLink(stage: edge.to, label: "View \(edge.to.title) stage")
            }
        }
    }

    @ViewBuilder
    private func stageLink(stage: PipelineStage, label: String) -> some View {
        Button {
            onNavigateToStage?(stage)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: stage.icon)
                    .font(.caption)
                Text(label)
                    .font(.callout)
                Image(systemName: "arrow.right")
                    .font(.caption2)
            }
            .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Propagated Warning Panel

/// Mini-panel shown when the user taps a health-propagation dot on an edge.
struct EdgeWarningPanelView: View {

    let edgeHealth: EdgeHealthState

    /// Invoked when "Show source" is tapped for a specific issue's source stage.
    var onShowSource: ((PipelineStage) -> Void)?

    /// Dismiss callback.
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    issueCountLine
                    issueList
                }
                .padding(16)
            }
        }
        .frame(minWidth: 280, idealWidth: 340, maxWidth: 420,
               minHeight: 180, idealHeight: 240)
    }

    // MARK: - Header

    @ViewBuilder
    private var headerBar: some View {
        HStack {
            let count = edgeHealth.propagatedIssues.count
            Label(
                "\(count) upstream issue\(count == 1 ? "" : "s") affecting this stage",
                systemImage: "exclamationmark.triangle"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(severityColor)
            Spacer()
            if let dismiss = onDismiss {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var issueCountLine: some View {
        let count = edgeHealth.propagatedIssues.count
        Text("\(count) upstream issue\(count == 1 ? " is" : "s are") affecting this stage")
            .font(.callout)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var issueList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(edgeHealth.propagatedIssues) { issue in
                HStack(spacing: 10) {
                    Circle()
                        .fill(issue.severity == .error ? Color.red : Color.orange)
                        .frame(width: 7, height: 7)

                    Text(issue.title)
                        .font(.callout)
                        .foregroundStyle(.primary)

                    Spacer()

                    Button("Show source") {
                        onShowSource?(issue.sourceStage)
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    // MARK: - Helpers

    private var severityColor: Color {
        switch edgeHealth.worstSeverity {
        case .error:   .red
        case .warning: .orange
        case nil:      .secondary
        }
    }
}

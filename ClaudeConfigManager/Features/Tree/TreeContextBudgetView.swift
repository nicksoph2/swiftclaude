import SwiftUI

/// Stage 8 — Context Budget detail view.
///
/// Displays a stacked bar visualization showing how the 200K context window
/// is allocated across system prompt, tool definitions, CLAUDE.md instructions,
/// auto-memory, and baseline overhead — with the remaining conversation budget
/// prominently highlighted.
struct TreeContextBudgetView: View {

    @EnvironmentObject private var pipeline: ConfigurationPipeline
    @StateObject private var viewModel = TreeContextBudgetViewModel()

    /// Optional callback for cross-stage navigation.
    var onNavigate: ((TreeNavigationTarget) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StageExplanationView(stage: .contextBudget)

                Spacer()

                displayModeToggle
            }

            if viewModel.segments.isEmpty {
                noDataPlaceholder
            } else {
                teachingCallout
                budgetBar
                breakdownList
                compactionNote
            }
        }
        .onAppear {
            viewModel.bind(to: pipeline)
        }
    }

    // MARK: - Display Mode Toggle

    private var displayModeToggle: some View {
        HStack(spacing: 6) {
            // Live indicator dot
            if viewModel.displayMode == .live && viewModel.liveSessionAvailable {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                    .modifier(PulsingDotModifier())
            } else {
                Circle()
                    .fill(.gray.opacity(0.4))
                    .frame(width: 8, height: 8)
            }

            Picker("Mode", selection: $viewModel.displayMode) {
                ForEach(BudgetDisplayMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
            .disabled(!viewModel.liveSessionAvailable && viewModel.displayMode != .live)
            .help(viewModel.liveSessionAvailable
                ? "Switch between estimated and live token usage"
                : "No active session detected")
        }
    }

    // MARK: - No Data

    private var noDataPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No context budget data available")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Run the pipeline to see how your configuration affects the available context window.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    // MARK: - Teaching Callout

    private var teachingCallout: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
                .font(.callout)

            Text("A large CLAUDE.md file directly reduces your conversation budget. Every token spent on configuration overhead is a token unavailable for conversation history and responses. Keep instructions concise to maximize the context available for your work.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.yellow.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.yellow.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Budget Bar

    private var budgetBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("Context Window Allocation")
                    .font(.subheadline.weight(.medium))

                Spacer()

                Text("\(TreePromptAssemblyView.formatTokenCount(PromptLayerConstants.contextWindowSize)) total")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            // Stacked bar
            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                let contextWindow = PromptLayerConstants.contextWindowSize

                HStack(spacing: 1) {
                    // Overhead segments
                    ForEach(viewModel.segments) { segment in
                        let fraction = Double(segment.estimatedTokens) / Double(contextWindow)
                        let segmentWidth = max(2, totalWidth * fraction)

                        Rectangle()
                            .fill(segmentColor(segment.color))
                            .frame(width: segmentWidth)
                            .help("\(segment.layer): ~\(TreePromptAssemblyView.formatTokenCount(segment.estimatedTokens))")
                            .onTapGesture {
                                onNavigate?(.promptLayer(layerIDForSegment(segment)))
                            }
                    }

                    // Remaining space
                    Rectangle()
                        .fill(Color.green.opacity(0.3))
                        .help("Remaining: ~\(TreePromptAssemblyView.formatTokenCount(viewModel.remainingTokens))")
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.separator.opacity(0.3), lineWidth: 0.5)
                )
            }
            .frame(height: 28)

            // Legend
            HStack(spacing: 12) {
                ForEach(viewModel.segments) { segment in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(segmentColor(segment.color))
                            .frame(width: 8, height: 8)
                        Text(segment.layer)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 8, height: 8)
                    Text("Remaining")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Breakdown List

    private var breakdownList: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Overhead segments
            ForEach(viewModel.segments) { segment in
                breakdownRow(segment: segment)
            }

            Divider()
                .padding(.vertical, 4)

            // Total overhead
            HStack {
                Image(systemName: "sum")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                Text("Total Overhead")
                    .font(.caption.weight(.semibold))

                Spacer()

                Text(TreePromptAssemblyView.formatTokenCount(viewModel.totalOverheadTokens))
                    .font(.caption.weight(.semibold).monospacedDigit())

                Text("(\(String(format: "%.1f%%", viewModel.overheadPercentage)))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)

            // Remaining for conversation (prominent)
            HStack {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .frame(width: 16)

                Text("Remaining for Conversation")
                    .font(.caption.weight(.semibold))

                Spacer()

                Text(TreePromptAssemblyView.formatTokenCount(viewModel.remainingTokens))
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(viewModel.remainingTokens > 0 ? .green : .red)

                let remainingPct = 100.0 - viewModel.overheadPercentage
                Text("(\(String(format: "%.1f%%", remainingPct)))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.green.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.green.opacity(0.2), lineWidth: 0.5)
            )
        }
    }

    private func breakdownRow(segment: ContextBudgetSegment) -> some View {
        HStack {
            Circle()
                .fill(segmentColor(segment.color))
                .frame(width: 8, height: 8)

            Text(segment.layer)
                .font(.caption)

            if segment.isConfigurable {
                Image(systemName: "wrench.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .help("You can affect this through configuration")
            }

            Spacer()

            Text(TreePromptAssemblyView.formatTokenCount(segment.estimatedTokens))
                .font(.caption.monospacedDigit())

            let pct = Double(segment.estimatedTokens) / Double(PromptLayerConstants.contextWindowSize) * 100.0
            Text("(\(String(format: "%.1f%%", pct)))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture {
            onNavigate?(.promptLayer(layerIDForSegment(segment)))
        }
        .id("budget-\(segment.id)")
    }

    // MARK: - Compaction Note

    private var compactionNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Auto-compaction activates at approximately 95% context usage, summarizing earlier conversation turns to free space. Token estimates are approximate (based on ~4 bytes per token).")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    /// Maps a segment's color string to a SwiftUI `Color`.
    private func segmentColor(_ name: String) -> Color {
        switch name {
        case "gray": return .gray
        case "purple": return .purple
        case "green": return .green
        case "indigo": return .indigo
        case "orange": return .orange
        case "blue": return .blue
        case "red": return .red
        case "teal": return .teal
        default: return .secondary
        }
    }

    /// Maps a budget segment back to the corresponding prompt layer ID for cross-nav.
    private func layerIDForSegment(_ segment: ContextBudgetSegment) -> String {
        switch segment.id {
        case "budget-system-prompt": return "layer-system-prompt"
        case "budget-tool-definitions": return "layer-tool-definitions"
        case "budget-instructions": return "layer-instructions"
        case "budget-auto-memory": return "layer-auto-memory"
        default: return segment.id
        }
    }
}

// MARK: - Pulsing Dot Modifier

/// Animates a pulsing opacity effect on a view, used for the live indicator dot.
struct PulsingDotModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.4 : 1.0)
            .animation(
                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

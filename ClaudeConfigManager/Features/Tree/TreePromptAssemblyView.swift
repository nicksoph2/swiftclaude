import SwiftUI

/// Stage 4 — Prompt Assembly detail view.
///
/// Displays the "layer cake" visualization showing what Claude actually sees
/// when a session starts. The 6 layers represent the assembled context window
/// in order: System Prompt → Tool Definitions → CLAUDE.md Instructions →
/// Auto-Memory → Conversation History → Your Message.
///
/// Each layer is an expandable `DisclosureGroup` showing token estimates,
/// configurability indicators, and detailed content where available.
struct TreePromptAssemblyView: View {

    @EnvironmentObject private var pipeline: ConfigurationPipeline
    @StateObject private var viewModel = TreePromptAssemblyViewModel()

    /// Optional callback for cross-stage navigation.
    var onNavigate: ((TreeNavigationTarget) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StageExplanationView(stage: .promptAssembly)

            if viewModel.layers.isEmpty {
                noDataPlaceholder
            } else {
                teachingCallout
                layerStack

                if let instructions = pipeline.projection?.instructions,
                   !instructions.orderedBlocks.isEmpty {
                    Divider()
                        .padding(.vertical, 4)
                    InstructionTreeView(snapshot: instructions)
                }

                overheadFooter
            }
        }
        .onAppear {
            Task { @MainActor in viewModel.bind(to: pipeline) }
        }
    }

    // MARK: - No Data

    private var noDataPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "square.stack.3d.up")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No prompt assembly data available")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Run the pipeline to see how Claude assembles your configuration into its context window.")
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

            Text("Files loaded later in the sequence have more influence on Claude's behavior. This is because language models attend more to content appearing later in their context window. Your project CLAUDE.md effectively \"overrides\" your user CLAUDE.md not by replacing it, but by being positioned after it.")
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

    // MARK: - Layer Stack

    private var layerStack: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(viewModel.layers.enumerated()), id: \.element.id) { index, layer in
                layerRow(layer, index: index + 1)
                    .id("prompt-\(layer.id)")
            }
        }
    }

    private func layerRow(_ layer: PromptLayer, index: Int) -> some View {
        DisclosureGroup {
            layerContent(layer)
                .padding(.top, 4)
        } label: {
            layerLabel(layer, index: index)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(layer.isPresent
                    ? Color(nsColor: .controlBackgroundColor)
                    : Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.separator.opacity(0.3), lineWidth: 0.5)
        )
    }

    private func layerLabel(_ layer: PromptLayer, index: Int) -> some View {
        HStack(spacing: 8) {
            Text("\(index)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(layer.isPresent ? Color.accentColor : Color.secondary))

            Text(layer.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(layer.isPresent ? .primary : .secondary)

            if layer.isConfigurable {
                Image(systemName: "wrench.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .help("You can affect this layer through configuration")
            }

            if !layer.isPresent {
                Text("absent")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.1))
                    )
            }

            Spacer()

            if let tokens = layer.estimatedTokens {
                PromptTokenBadge(tokens: tokens)
            }
        }
    }

    private func layerContent(_ layer: PromptLayer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(layer.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !layer.children.isEmpty {
                PromptChildLayerList(
                    children: layer.children,
                    parentID: layer.id,
                    onNavigate: onNavigate
                )
            }

            if let content = layer.expandedContent, !content.isEmpty {
                PromptContentPreviewBlock(content: content)
            }
        }
    }

    // MARK: - Overhead Footer

    private var overheadFooter: some View {
        let overhead = viewModel.totalOverheadTokens
        let remaining = PromptLayerConstants.contextWindowSize - overhead

        return VStack(alignment: .leading, spacing: 6) {
            Divider()

            HStack {
                Image(systemName: "sum")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Total overhead before conversation:")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(Self.formatTokenCount(overhead))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.primary)

                Text("of \(Self.formatTokenCount(PromptLayerConstants.contextWindowSize))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            HStack {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Remaining for conversation:")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(Self.formatTokenCount(remaining))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(remaining > 0 ? .green : .red)
            }

            Text("Token estimates are approximate (based on ~4 bytes per token).")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    static func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        }
        return "\(count)"
    }
}

// MARK: - Extracted Subviews (break recursive type cycles)

/// Displays a list of child prompt layers with recursive nesting support.
struct PromptChildLayerList: View {
    let children: [PromptLayer]
    let parentID: String
    var onNavigate: ((TreeNavigationTarget) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(children) { child in
                PromptChildLayerRow(
                    child: child,
                    parentID: parentID,
                    onNavigate: onNavigate
                )
            }
        }
    }
}

/// A single child layer row — either a simple leaf or an expandable group.
struct PromptChildLayerRow: View {
    let child: PromptLayer
    let parentID: String
    var onNavigate: ((TreeNavigationTarget) -> Void)?

    var body: some View {
        if child.children.isEmpty && child.expandedContent == nil {
            HStack(spacing: 6) {
                PromptChildLabel(
                    child: child,
                    parentID: parentID,
                    onNavigate: onNavigate
                )
                Spacer()
            }
            .padding(.vertical, 2)
        } else {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 6) {
                    if !child.description.isEmpty {
                        Text(child.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let content = child.expandedContent, !content.isEmpty {
                        PromptContentPreviewBlock(content: content)
                    }

                    if !child.children.isEmpty {
                        PromptChildLayerList(
                            children: child.children,
                            parentID: child.id,
                            onNavigate: onNavigate
                        )
                        .padding(.leading, 8)
                    }
                }
                .padding(.top, 2)
            } label: {
                PromptChildLabel(
                    child: child,
                    parentID: parentID,
                    onNavigate: onNavigate
                )
            }
            .padding(.vertical, 2)
        }
    }
}

/// Label for a child prompt layer, including scope badge and navigation link.
struct PromptChildLabel: View {
    let child: PromptLayer
    let parentID: String
    var onNavigate: ((TreeNavigationTarget) -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            // Load order badge for instructions
            if child.id.hasPrefix("instruction-"),
               parentID == "layer-instructions" {
                let instructionIndex = self.getInstructionIndex()
                Text("\(instructionIndex)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.blue))
                    .help("Load order — files loaded later have stronger influence")
            }

            if child.id.hasPrefix("instruction-"),
               let scope = Self.extractScope(from: child.description) {
                ScopeColorScheme.scopeBadge(for: scope)
            }

            if child.id.hasPrefix("instruction-"),
               parentID == "layer-instructions" {
                Button {
                    let blockID = String(child.id.dropFirst("instruction-".count))
                    onNavigate?(.parsingFile(URL(fileURLWithPath: blockID)))
                } label: {
                    Text(child.name)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            } else {
                Text(child.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(child.isPresent ? .primary : .secondary)
            }

            if !child.isPresent {
                Image(systemName: "slash.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let tokens = child.estimatedTokens {
                PromptTokenBadge(tokens: tokens)
            }
        }
    }

    /// Returns the load order index for this instruction (1-based).
    /// This would normally come from parent context, but for now uses a placeholder.
    private func getInstructionIndex() -> Int {
        // In a real implementation, this would be passed via parent state or
        // computed from the parent's children enumeration. For now, we return a placeholder
        // that would be replaced by actual load order tracking.
        1
    }

    /// Attempts to extract a `ResolutionScope` from a description string like "[User] — /path".
    static func extractScope(from description: String) -> ResolutionScope? {
        guard description.hasPrefix("["),
              let closeBracket = description.firstIndex(of: "]") else {
            return nil
        }
        let scopeText = String(
            description[description.index(after: description.startIndex)..<closeBracket]
        ).lowercased()

        switch scopeText {
        case "managed": return .managed
        case "user": return .user
        case "project": return .project
        case "projectlocal": return .projectLocal
        case "session": return .session
        case "cli": return .cli
        case "imported": return .imported
        case "automemory": return .autoMemory
        case "synthetic": return .synthetic
        default: return nil
        }
    }
}

/// Monospaced content preview block.
struct PromptContentPreviewBlock: View {
    let content: String

    var body: some View {
        Text(content)
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(5)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.5))
            )
    }
}

/// Token count badge.
struct PromptTokenBadge: View {
    let tokens: Int

    var body: some View {
        let display = tokens >= 1_000
            ? String(format: "~%.1fK tk", Double(tokens) / 1_000.0)
            : "~\(tokens) tk"

        Text(display)
            .font(.caption2.weight(.medium).monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.1))
            )
    }
}

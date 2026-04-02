import SwiftUI
import Combine

// MARK: - Subagent Node Model

/// A node in the subagent session tree, representing either the parent session
/// or a child subagent session.
struct SubagentNode: Identifiable, Equatable {
    let id: String
    let sessionId: String
    let agentId: String?
    let isParent: Bool
    let taskSummary: String
    let inputTokens: Int
    let outputTokens: Int
    let status: SubagentSessionStatus
    let transcriptPath: String
    let children: [SubagentNode]

    var totalTokens: Int {
        inputTokens + outputTokens
    }
}

/// Status of a subagent session.
enum SubagentSessionStatus: String, Equatable, Sendable {
    case active
    case complete
    case truncated

    var label: String {
        switch self {
        case .active: "Active"
        case .complete: "Complete"
        case .truncated: "Truncated"
        }
    }

    var icon: String {
        switch self {
        case .active: "circle.fill"
        case .complete: "checkmark.circle.fill"
        case .truncated: "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .active: .green
        case .complete: .blue
        case .truncated: .orange
        }
    }
}

// MARK: - View Model

/// Builds the subagent tree from transcript scanner data.
@MainActor
final class SubagentTreeViewModel: ObservableObject {

    @Published private(set) var rootNode: SubagentNode?
    @Published private(set) var totalTokensIncludingSubagents: Int = 0
    @Published private(set) var hasSubagents: Bool = false

    func build(
        parentMetadata: TranscriptMetadata,
        parentEntries: [TranscriptEntry],
        subagentMetadataList: [TranscriptMetadata],
        subagentEntriesByPath: [String: [TranscriptEntry]]
    ) {
        let parentInputTokens = parentMetadata.totalTokensIn ?? 0
        let parentOutputTokens = parentMetadata.totalTokensOut ?? 0
        let parentSummary = extractFirstUserTurn(from: parentEntries)
        let parentStatus = determineSessionStatus(metadata: parentMetadata, entries: parentEntries)

        var childNodes: [SubagentNode] = []

        for subMeta in subagentMetadataList.sorted(by: { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }) {
            let subEntries = subagentEntriesByPath[subMeta.transcriptPath] ?? []
            let subSummary = extractFirstUserTurn(from: subEntries)
            let subStatus = determineSessionStatus(metadata: subMeta, entries: subEntries)
            let subInputTokens = subMeta.totalTokensIn ?? 0
            let subOutputTokens = subMeta.totalTokensOut ?? 0

            childNodes.append(SubagentNode(
                id: subMeta.id,
                sessionId: subMeta.sessionId ?? subMeta.agentId ?? "unknown",
                agentId: subMeta.agentId,
                isParent: false,
                taskSummary: subSummary,
                inputTokens: subInputTokens,
                outputTokens: subOutputTokens,
                status: subStatus,
                transcriptPath: subMeta.transcriptPath,
                children: []
            ))
        }

        let root = SubagentNode(
            id: parentMetadata.id,
            sessionId: parentMetadata.sessionId ?? "unknown",
            agentId: nil,
            isParent: true,
            taskSummary: parentSummary,
            inputTokens: parentInputTokens,
            outputTokens: parentOutputTokens,
            status: parentStatus,
            transcriptPath: parentMetadata.transcriptPath,
            children: childNodes
        )

        rootNode = root
        hasSubagents = !childNodes.isEmpty

        let childTokens = childNodes.reduce(0) { $0 + $1.totalTokens }
        totalTokensIncludingSubagents = root.totalTokens + childTokens
    }

    // MARK: - Helpers

    private func extractFirstUserTurn(from entries: [TranscriptEntry]) -> String {
        let userTurn = entries.first(where: {
            $0.type == "human" || $0.type == "user" || $0.role == "user"
        })

        if let preview = userTurn?.contentPreview, !preview.isEmpty {
            let trimmed = preview.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 120 {
                return String(trimmed.prefix(120)) + "..."
            }
            return trimmed
        }

        return "Session"
    }

    private func determineSessionStatus(
        metadata: TranscriptMetadata,
        entries: [TranscriptEntry]
    ) -> SubagentSessionStatus {
        // If the file was modified recently, consider it active
        if Date.now.timeIntervalSince(metadata.modifiedAt) < 5 * 60 {
            return .active
        }

        // Check if the last entry suggests completion
        if let lastEntry = entries.last {
            if lastEntry.type == "result" || lastEntry.type == "end" {
                return .complete
            }
        }

        // If the file has content and is not recent, assume complete
        if metadata.lineCount > 0 {
            return .complete
        }

        return .truncated
    }
}

// MARK: - Subagent Tree View

/// Displays a tree visualization of parent-subagent session hierarchies.
///
/// Root: parent session node (session ID, token usage, status)
/// Children: each subagent session node (agent task summary, token usage, status)
/// Lines connecting parent to subagents.
/// Each node is tappable to open the full transcript.
struct SubagentTreeView: View {

    @StateObject private var viewModel = SubagentTreeViewModel()

    let parentMetadata: TranscriptMetadata
    let parentEntries: [TranscriptEntry]
    let subagentMetadataList: [TranscriptMetadata]
    let subagentEntriesByPath: [String: [TranscriptEntry]]

    /// Callback when user taps a node to open its transcript.
    var onOpenTranscript: ((String) -> Void)?

    var body: some View {
        Group {
            if let root = viewModel.rootNode, viewModel.hasSubagents {
                VStack(alignment: .leading, spacing: 12) {
                    tokenSummaryHeader

                    treeContent(root: root)
                }
            } else if viewModel.rootNode != nil {
                EmptyView()
            }
        }
        .onAppear {
            viewModel.build(
                parentMetadata: parentMetadata,
                parentEntries: parentEntries,
                subagentMetadataList: subagentMetadataList,
                subagentEntriesByPath: subagentEntriesByPath
            )
        }
    }

    // MARK: - Token Summary Header

    private var tokenSummaryHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.2.circle")
                .font(.subheadline)
                .foregroundStyle(.purple)

            Text("Subagent Sessions")
                .font(.subheadline.weight(.medium))

            Spacer()

            Text("Total: \(formatTokenCount(viewModel.totalTokensIncludingSubagents)) tokens")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Tree Content

    private func treeContent(root: SubagentNode) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Parent node
            sessionNodeView(node: root, indentLevel: 0)

            // Children with connecting lines
            ForEach(Array(root.children.enumerated()), id: \.element.id) { index, child in
                HStack(alignment: .top, spacing: 0) {
                    // Connecting line
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 1)
                            .frame(height: 8)

                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 1)
                                .frame(height: index < root.children.count - 1 ? .infinity : 14)

                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(height: 1)
                                .frame(width: 16)
                        }

                        if index < root.children.count - 1 {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 1)
                        }
                    }
                    .frame(width: 24)
                    .padding(.leading, 12)

                    sessionNodeView(node: child, indentLevel: 1)
                        .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Session Node

    private func sessionNodeView(node: SubagentNode, indentLevel: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: status dot + session ID
            HStack(spacing: 6) {
                Image(systemName: node.status.icon)
                    .font(.caption2)
                    .foregroundStyle(node.status.color)

                if node.isParent {
                    Image(systemName: "person.circle")
                        .font(.caption)
                        .foregroundStyle(.primary)
                } else {
                    Image(systemName: "person.2")
                        .font(.caption)
                        .foregroundStyle(.purple)
                }

                Text(node.isParent ? "Parent: \(truncateID(node.sessionId))" : "Agent: \(truncateID(node.agentId ?? node.sessionId))")
                    .font(.caption.weight(.medium))
                    .lineLimit(1)

                Spacer()

                Text(node.status.label)
                    .font(.caption2)
                    .foregroundStyle(node.status.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(node.status.color.opacity(0.1))
                    .clipShape(Capsule())
            }

            // Task summary
            Text(node.taskSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            // Token usage
            HStack(spacing: 12) {
                Label("\(formatTokenCount(node.inputTokens)) in", systemImage: "arrow.down.circle")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)

                Label("\(formatTokenCount(node.outputTokens)) out", systemImage: "arrow.up.circle")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)

                Label("\(formatTokenCount(node.totalTokens)) total", systemImage: "sum")
                    .font(.caption2.monospacedDigit().weight(.medium))
                    .foregroundStyle(.primary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(node.isParent
                    ? Color(nsColor: .controlBackgroundColor)
                    : Color.purple.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    node.isParent
                        ? Color.secondary.opacity(0.3)
                        : Color.purple.opacity(0.2),
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onOpenTranscript?(node.transcriptPath)
        }
        .help("Tap to open transcript")
    }

    // MARK: - Helpers

    private func truncateID(_ id: String) -> String {
        if id.count > 24 {
            return String(id.prefix(12)) + "..." + String(id.suffix(8))
        }
        return id
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

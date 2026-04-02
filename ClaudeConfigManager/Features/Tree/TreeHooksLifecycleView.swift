import SwiftUI

/// Stage 6 — Hooks Lifecycle detail view.
///
/// Displays a session timeline swim-lane showing all canonical lifecycle events
/// from `HookLifecycleTemplate`, merged with actual configured hook handlers
/// from the resolved projection.
///
/// The "user turn" section (UserPromptSubmit → PreToolUse → PostToolUse →
/// Notification → Stop → SubagentStart → SubagentStop) is visually grouped
/// in a repeating loop bracket. Events with no hooks still appear with
/// placeholder text. A global suppression banner overlays the entire timeline
/// when `disableAllHooks` is active.
struct TreeHooksLifecycleView: View {

    @EnvironmentObject private var pipeline: ConfigurationPipeline
    @StateObject private var viewModel = TreeHooksLifecycleViewModel()

    /// Optional callback for cross-stage navigation.
    var onNavigate: ((TreeNavigationTarget) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StageExplanationView(stage: .hooksLifecycle)

            if viewModel.lifecycleEvents.isEmpty {
                noDataPlaceholder
            } else {
                teachingCallout

                if viewModel.globalSuppressionActive {
                    globalSuppressionBanner
                }

                timelineView
            }
        }
        .onAppear {
            Task { @MainActor in viewModel.bind(to: pipeline) }
        }
    }

    // MARK: - No Data

    private var noDataPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "arrow.triangle.capsulepath")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No hooks lifecycle data available")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Run the pipeline to see how hooks attach to session lifecycle events.")
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

            Text("Hooks let you run custom commands at key moments in a Claude Code session. Events in the repeating loop fire on every user turn; one-time events fire only at session boundaries.")
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

    // MARK: - Global Suppression Banner

    private var globalSuppressionBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.callout)

            VStack(alignment: .leading, spacing: 2) {
                Text("All hooks disabled")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)

                if let reason = viewModel.suppressionReason {
                    Text(reason)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Timeline View

    private var timelineView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(viewModel.lifecycleEvents.enumerated()), id: \.element.id) { index, event in
                let templateEvent = HookLifecycleTemplate.events.first(where: {
                    $0.eventKey == event.eventType
                })
                let isRepeating = templateEvent?.isRepeating ?? false
                let isFirstRepeating = isRepeating && !isPreviousRepeating(at: index)
                let isLastRepeating = isRepeating && !isNextRepeating(at: index)

                // Repeating loop bracket start
                if isFirstRepeating {
                    repeatingLoopHeader
                }

                eventNode(event, template: templateEvent, isRepeating: isRepeating)
                    .id(TreeNavigationTarget.hooksEvent(event.eventType).anchorID)
                    .padding(.leading, isRepeating ? 16 : 0)

                // Connector arrow between events
                if index < viewModel.lifecycleEvents.count - 1 {
                    timelineConnector(isRepeating: isRepeating)
                        .padding(.leading, isRepeating ? 16 : 0)
                }

                // Repeating loop bracket end
                if isLastRepeating {
                    repeatingLoopFooter
                }
            }
        }
    }

    // MARK: - Repeating Loop Bracket

    private var repeatingLoopHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "repeat")
                .font(.caption2)
                .foregroundStyle(.orange)

            Text("User Turn Loop")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.orange)

            Rectangle()
                .fill(Color.orange.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    private var repeatingLoopFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.turn.up.left")
                .font(.caption2)
                .foregroundStyle(.orange.opacity(0.6))

            Text("Repeats each turn")
                .font(.caption2)
                .foregroundStyle(.orange.opacity(0.6))
                .italic()

            Rectangle()
                .fill(Color.orange.opacity(0.2))
                .frame(height: 1)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }

    // MARK: - Event Node

    private func eventNode(
        _ event: LifecycleEventNode,
        template: HookLifecycleTemplate.Event?,
        isRepeating: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Event header
            HStack(spacing: 8) {
                // Timeline dot
                Circle()
                    .fill(eventDotColor(for: event))
                    .frame(width: 10, height: 10)

                Text(event.displayName)
                    .font(.subheadline.weight(.medium))
                    .strikethrough(event.isSuppressed)

                if !event.handlers.isEmpty {
                    Text("\(event.handlers.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(event.isSuppressed ? Color.red.opacity(0.6) : Color.accentColor))
                }

                if isRepeating {
                    Image(systemName: "repeat")
                        .font(.caption2)
                        .foregroundStyle(.orange.opacity(0.6))
                }

                Spacer()
            }

            // Event description
            if let desc = template?.description {
                Text(desc)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 18)
            }

            // Suppression notice
            if event.isSuppressed, let reason = event.suppressionReason {
                HStack(spacing: 4) {
                    Image(systemName: "nosign")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Text(reason)
                        .font(.caption2)
                        .foregroundStyle(.red.opacity(0.8))
                }
                .padding(.leading, 18)
            }

            // Handler list
            if !event.handlers.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(event.handlers.enumerated()), id: \.offset) { _, handler in
                        handlerRow(handler)
                    }
                }
                .padding(.leading, 18)
            } else if !event.isSuppressed {
                Text("No hooks configured")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
                    .padding(.leading, 18)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(eventBorderColor(for: event), lineWidth: event.isSuppressed ? 1 : 0.5)
        )
        .opacity(event.isSuppressed ? 0.7 : 1.0)
    }

    // MARK: - Handler Row

    private func handlerRow(_ handler: ResolvedHookHandler) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                // Handler type icon
                Image(systemName: viewModel.handlerIcon(for: handler))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                // Type badge
                Text(viewModel.handlerTypeLabel(for: handler))
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.12))
                    )

                // Command / URL / prompt preview
                Text(viewModel.handlerLabel(for: handler))
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(2)

                Spacer()

                // Async indicator
                if handler.isAsync == true {
                    Text("async")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.purple.opacity(0.1))
                        )
                }

                // Source scope badge
                if let source = handler.source {
                    ScopeColorScheme.scopeBadge(for: source.scope)
                }
            }

            // Detail line: timeout, condition, once, shell
            let detail = viewModel.handlerDetail(for: handler)
            if !detail.isEmpty {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 22)
            }

            // Source file path
            if let sourcePath = handler.source?.sourcePath {
                Text(sourcePath)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.leading, 22)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.5))
        )
    }

    // MARK: - Timeline Connector

    private func timelineConnector(isRepeating: Bool) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isRepeating ? Color.orange.opacity(0.3) : Color.secondary.opacity(0.3))
                .frame(width: 2, height: 8)
            Image(systemName: "chevron.down")
                .font(.system(size: 8))
                .foregroundStyle(isRepeating ? .orange.opacity(0.5) : .secondary.opacity(0.5))
            Rectangle()
                .fill(isRepeating ? Color.orange.opacity(0.3) : Color.secondary.opacity(0.3))
                .frame(width: 2, height: 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }

    // MARK: - Styling Helpers

    private func eventDotColor(for event: LifecycleEventNode) -> Color {
        if event.isSuppressed {
            return .red.opacity(0.6)
        } else if event.handlers.isEmpty {
            return .secondary.opacity(0.4)
        } else {
            return .green
        }
    }

    private func eventBorderColor(for event: LifecycleEventNode) -> Color {
        if event.isSuppressed {
            return .red.opacity(0.3)
        } else if !event.handlers.isEmpty {
            return .green.opacity(0.3)
        } else {
            return Color.secondary.opacity(0.2)
        }
    }

    // MARK: - Repeating Helpers

    /// Checks if the event before the given index is also repeating.
    private func isPreviousRepeating(at index: Int) -> Bool {
        guard index > 0 else { return false }
        let prevEvent = viewModel.lifecycleEvents[index - 1]
        return HookLifecycleTemplate.events.first(where: {
            $0.eventKey == prevEvent.eventType
        })?.isRepeating ?? false
    }

    /// Checks if the event after the given index is also repeating.
    private func isNextRepeating(at index: Int) -> Bool {
        guard index < viewModel.lifecycleEvents.count - 1 else { return false }
        let nextEvent = viewModel.lifecycleEvents[index + 1]
        return HookLifecycleTemplate.events.first(where: {
            $0.eventKey == nextEvent.eventType
        })?.isRepeating ?? false
    }
}

import Foundation
import SwiftUI
import Combine

// MARK: - View Model

/// Transforms `SessionProjection.hooks` into a hooks lifecycle timeline visualization.
///
/// Merges the canonical `HookLifecycleTemplate` event order with actual resolved
/// hook handlers from the pipeline projection, producing an array of
/// `LifecycleEventNode` items ready for timeline rendering.
@MainActor
final class TreeHooksLifecycleViewModel: ObservableObject {

    // MARK: - Published State

    /// Lifecycle events in canonical timeline order, merged with actual hook data.
    @Published private(set) var lifecycleEvents: [LifecycleEventNode] = []

    /// Whether all hooks are globally disabled (e.g., via `disableAllHooks` setting).
    @Published private(set) var globalSuppressionActive: Bool = false

    /// The human-readable reason for global suppression, if active.
    @Published private(set) var suppressionReason: String?

    /// Aggregate stage health.
    @Published private(set) var stageHealth: StageHealth = .noData

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private weak var pipeline: ConfigurationPipeline?

    // MARK: - Binding

    /// Binds to the pipeline and recomputes whenever projection changes.
    func bind(to pipeline: ConfigurationPipeline) {
        self.pipeline = pipeline
        cancellables.removeAll()

        pipeline.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.rebuild()
                }
            }
            .store(in: &cancellables)

        rebuild()
    }

    // MARK: - Private Rebuild

    private func rebuild() {
        guard let projection = pipeline?.projection else {
            lifecycleEvents = []
            globalSuppressionActive = false
            suppressionReason = nil
            stageHealth = .noData
            return
        }

        // Extract global suppression state
        let policyEffects = projection.hooks?.policyEffects ?? []
        globalSuppressionActive = policyEffects.contains(where: { $0.reason == .disableAllHooks })
        suppressionReason = policyEffects.first(where: { $0.reason == .disableAllHooks })?.message

        // Build lifecycle events
        lifecycleEvents = buildLifecycleEvents(from: projection)

        // Compute health
        stageHealth = computeHealth(from: projection)
    }

    // MARK: - Lifecycle Event Building

    /// Merges the canonical template with actual resolved hook data.
    private func buildLifecycleEvents(from projection: SessionProjection) -> [LifecycleEventNode] {
        let hooks = projection.hooks

        return HookLifecycleTemplate.events.map { templateEvent in
            // Find matching resolved event entries (case-insensitive on canonical name)
            let matchingEntries = hooks?.events.filter { entry in
                entry.eventType.canonicalName.lowercased() == templateEvent.eventKey.lowercased()
            } ?? []

            // Collect all resolved handlers across matching entries
            let handlers = matchingEntries.flatMap { $0.resolvedHandlers }

            // Determine suppression: per-event suppression takes priority, then global
            let perEventSuppression = matchingEntries.first(where: { $0.suppression != nil })?.suppression
            let isSuppressed = perEventSuppression != nil || globalSuppressionActive

            let reason: String?
            if let perEvent = perEventSuppression {
                reason = perEvent.message
            } else if globalSuppressionActive {
                reason = suppressionReason ?? "All hooks disabled"
            } else {
                reason = nil
            }

            return LifecycleEventNode(
                id: "hooks-\(templateEvent.eventKey)",
                eventType: templateEvent.eventKey,
                displayName: templateEvent.displayName,
                handlers: handlers,
                isSuppressed: isSuppressed,
                suppressionReason: reason
            )
        }
    }

    // MARK: - Health

    private func computeHealth(from projection: SessionProjection) -> StageHealth {
        guard projection.hooks != nil else {
            return .noData
        }

        var warningCount = 0
        var errorCount = 0

        if globalSuppressionActive {
            warningCount += 1
        }

        if let hooks = projection.hooks {
            for issue in hooks.issues {
                switch issue.severity {
                case .error: errorCount += 1
                case .warning: warningCount += 1
                case .info: break
                }
            }
        }

        if errorCount > 0 { return .errors(errorCount) }
        if warningCount > 0 { return .warnings(warningCount) }
        return .healthy
    }

    // MARK: - Handler Helpers

    /// Returns a display label for a handler based on its type.
    func handlerLabel(for handler: ResolvedHookHandler) -> String {
        switch handler.handlerType {
        case .command:
            return handler.command ?? "command (unknown)"
        case .http:
            return handler.url ?? "HTTP hook"
        case .prompt:
            let preview = handler.prompt.map { String($0.prefix(80)) } ?? "prompt hook"
            return preview
        case .agent:
            return handler.model ?? "agent hook"
        case nil:
            return handler.rawType ?? "unknown hook type"
        }
    }

    /// Returns a detail string summarizing handler configuration.
    func handlerDetail(for handler: ResolvedHookHandler) -> String {
        var parts: [String] = []

        if let timeout = handler.timeout {
            parts.append("Timeout: \(timeout)ms")
        }

        if let condition = handler.condition {
            parts.append("Condition: \(condition)")
        }

        if handler.isAsync == true {
            parts.append("Async")
        }

        if handler.once == true {
            parts.append("Once only")
        }

        if let shell = handler.shell {
            parts.append("Shell: \(shell)")
        }

        return parts.joined(separator: " · ")
    }

    /// Returns an SF Symbol name for a handler type.
    func handlerIcon(for handler: ResolvedHookHandler) -> String {
        switch handler.handlerType {
        case .command: return "terminal"
        case .http: return "network"
        case .prompt: return "text.bubble"
        case .agent: return "person.2"
        case nil: return "questionmark.circle"
        }
    }

    /// Returns a human-readable label for a handler type.
    func handlerTypeLabel(for handler: ResolvedHookHandler) -> String {
        switch handler.handlerType {
        case .command: return "Command"
        case .http: return "HTTP"
        case .prompt: return "Prompt"
        case .agent: return "Agent"
        case nil: return handler.rawType ?? "Unknown"
        }
    }
}

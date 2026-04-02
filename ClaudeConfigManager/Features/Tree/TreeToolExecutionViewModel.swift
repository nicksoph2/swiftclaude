import Foundation
import SwiftUI
import Combine

// MARK: - View Model

/// Transforms `SessionProjection` data into a tool execution flowchart visualization.
///
/// Builds an array of `ExecutionGate` items representing the 4 gates a tool request
/// passes through: PreToolUse hooks → Permission rules → Execution → PostToolUse hooks.
@MainActor
final class TreeToolExecutionViewModel: ObservableObject {

    // MARK: - Published State

    /// The 4 execution gates in flow order.
    @Published private(set) var gates: [ExecutionGate] = []

    /// Permission rules grouped by type (deny, ask, allow).
    @Published private(set) var denyRules: [PermissionRuleDisplay] = []
    @Published private(set) var askRules: [PermissionRuleDisplay] = []
    @Published private(set) var allowRules: [PermissionRuleDisplay] = []

    /// Default permission mode from resolved settings.
    @Published private(set) var defaultPermissionMode: String = "ask"

    /// Whether all hooks are globally disabled.
    @Published private(set) var allHooksDisabled: Bool = false

    /// The suppression reason message, if hooks are disabled.
    @Published private(set) var hookSuppressionMessage: String?

    /// Aggregate stage health.
    @Published private(set) var stageHealth: StageHealth = .noData

    /// The name of the tool currently being executed in a live session, or `nil`.
    @Published private(set) var liveActiveToolName: String?

    /// The name of the hook event currently being executed in a live session, or `nil`.
    @Published private(set) var liveActiveHookEvent: String?

    /// Whether a live session is active.
    @Published private(set) var isLiveSession: Bool = false

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private weak var pipeline: ConfigurationPipeline?
    private weak var liveWatcher: LiveSessionWatcher?

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

    /// Binds to a live session watcher for active tool highlighting.
    func bindLiveWatcher(_ watcher: LiveSessionWatcher) {
        self.liveWatcher = watcher

        watcher.$activeSession
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.liveActiveToolName = state?.activeToolName
                self?.liveActiveHookEvent = state?.activeHookEvent
            }
            .store(in: &cancellables)

        watcher.$isLive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLive in
                self?.isLiveSession = isLive
                if !isLive {
                    self?.liveActiveToolName = nil
                    self?.liveActiveHookEvent = nil
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Private Rebuild

    private func rebuild() {
        guard let projection = pipeline?.projection else {
            gates = []
            denyRules = []
            askRules = []
            allowRules = []
            defaultPermissionMode = "ask"
            allHooksDisabled = false
            hookSuppressionMessage = nil
            stageHealth = .noData
            return
        }

        // Extract hook suppression state
        let policyEffects = projection.hooks?.policyEffects ?? []
        allHooksDisabled = policyEffects.contains(where: { $0.reason == .disableAllHooks })
        hookSuppressionMessage = policyEffects.first(where: { $0.reason == .disableAllHooks })?.message

        // Extract permission rules from resolved settings
        extractPermissionRules(from: projection)

        // Extract default permission mode
        extractDefaultPermissionMode(from: projection)

        // Build the 4 gates
        gates = buildGates(from: projection)

        // Compute health
        stageHealth = computeHealth(from: projection)
    }

    // MARK: - Permission Rule Extraction

    private func extractPermissionRules(from projection: SessionProjection) {
        guard let settings = projection.settings else {
            denyRules = []
            askRules = []
            allowRules = []
            return
        }

        var deny: [PermissionRuleDisplay] = []
        var ask: [PermissionRuleDisplay] = []
        var allow: [PermissionRuleDisplay] = []

        // Extract permissions.deny
        if let denyEntry = settings.entries.first(where: { $0.keyPath == "permissions.deny" }) {
            deny = extractRulesFromEntry(denyEntry, ruleType: .deny)
        }

        // Extract permissions.ask (if such a key exists)
        if let askEntry = settings.entries.first(where: { $0.keyPath == "permissions.ask" }) {
            ask = extractRulesFromEntry(askEntry, ruleType: .ask)
        }

        // Extract permissions.allow
        if let allowEntry = settings.entries.first(where: { $0.keyPath == "permissions.allow" }) {
            allow = extractRulesFromEntry(allowEntry, ruleType: .allow)
        }

        denyRules = deny
        askRules = ask
        allowRules = allow
    }

    /// Extracts individual rule patterns from a resolved settings entry whose value is a JSON array.
    private func extractRulesFromEntry(
        _ entry: ResolvedSettingsEntry,
        ruleType: PermissionRuleType
    ) -> [PermissionRuleDisplay] {
        guard let effectiveValue = entry.value.effectiveValue else { return [] }

        // The value should be a JSON array of strings
        let patterns: [String]
        switch effectiveValue {
        case .array(let items):
            patterns = items.compactMap { item -> String? in
                if case .string(let s) = item { return s }
                return nil
            }
        case .string(let s):
            patterns = [s]
        default:
            return []
        }

        let sourceScope = entry.value.winningSource?.scope ?? .user
        let sourcePath = entry.value.winningSource?.sourcePath

        return patterns.map { pattern in
            PermissionRuleDisplay(
                ruleType: ruleType,
                pattern: pattern,
                sourceScope: sourceScope,
                sourcePath: sourcePath
            )
        }
    }

    private func extractDefaultPermissionMode(from projection: SessionProjection) {
        guard let settings = projection.settings else {
            defaultPermissionMode = "ask"
            return
        }

        if let modeEntry = settings.entries.first(where: { $0.keyPath == "permissions.mode" }),
           let effective = modeEntry.value.effectiveValue,
           case .string(let mode) = effective {
            defaultPermissionMode = mode
        } else {
            defaultPermissionMode = "ask"
        }
    }

    // MARK: - Gate Building

    private func buildGates(from projection: SessionProjection) -> [ExecutionGate] {
        var result: [ExecutionGate] = []

        // Gate 1: PreToolUse Hooks
        result.append(buildHookGate(
            gateType: .preHook,
            eventKey: "PreToolUse",
            projection: projection
        ))

        // Gate 2: Permission Rules
        result.append(buildPermissionsGate())

        // Gate 3: Execution
        result.append(ExecutionGate(
            gateType: .execution,
            items: [ExecutionGateItem(
                label: "Tool runs with approved inputs",
                detail: "The tool executes after passing through hooks and permission checks."
            )],
            status: .active
        ))

        // Gate 4: PostToolUse Hooks
        result.append(buildHookGate(
            gateType: .postHook,
            eventKey: "PostToolUse",
            projection: projection
        ))

        return result
    }

    private func buildHookGate(
        gateType: ExecutionGateType,
        eventKey: String,
        projection: SessionProjection
    ) -> ExecutionGate {
        // Check global suppression
        if allHooksDisabled {
            return ExecutionGate(
                gateType: gateType,
                items: [],
                status: .suppressed(reason: hookSuppressionMessage ?? "All hooks disabled via disableAllHooks setting.")
            )
        }

        guard let hooks = projection.hooks else {
            return ExecutionGate(gateType: gateType, items: [], status: .empty)
        }

        // Find the matching event entry
        let matchingEntries = hooks.events.filter { entry in
            entry.eventType.canonicalName.lowercased() == eventKey.lowercased()
        }

        var items: [ExecutionGateItem] = []

        for entry in matchingEntries {
            // Check per-event suppression
            if let suppression = entry.suppression {
                return ExecutionGate(
                    gateType: gateType,
                    items: [],
                    status: .suppressed(reason: suppression.message)
                )
            }

            for handler in entry.resolvedHandlers {
                let label = handlerLabel(for: handler)
                let detail = handlerDetail(for: handler)
                let sourceScope = handler.source?.scope
                let sourcePath = handler.source?.sourcePath

                items.append(ExecutionGateItem(
                    label: label,
                    detail: detail,
                    sourceScope: sourceScope,
                    sourcePath: sourcePath
                ))
            }
        }

        if items.isEmpty {
            return ExecutionGate(gateType: gateType, items: [], status: .empty)
        }

        return ExecutionGate(gateType: gateType, items: items, status: .active)
    }

    private func buildPermissionsGate() -> ExecutionGate {
        let totalRules = denyRules.count + askRules.count + allowRules.count

        if totalRules == 0 {
            return ExecutionGate(
                gateType: .permissions,
                items: [ExecutionGateItem(
                    label: "Default mode: \(defaultPermissionMode)",
                    detail: "No explicit permission rules configured. All tool requests use the default mode."
                )],
                status: .active
            )
        }

        var items: [ExecutionGateItem] = []

        for rule in denyRules {
            items.append(ExecutionGateItem(
                label: "DENY: \(rule.pattern)",
                detail: nil,
                sourceScope: rule.sourceScope,
                sourcePath: rule.sourcePath
            ))
        }
        for rule in askRules {
            items.append(ExecutionGateItem(
                label: "ASK: \(rule.pattern)",
                detail: nil,
                sourceScope: rule.sourceScope,
                sourcePath: rule.sourcePath
            ))
        }
        for rule in allowRules {
            items.append(ExecutionGateItem(
                label: "ALLOW: \(rule.pattern)",
                detail: nil,
                sourceScope: rule.sourceScope,
                sourcePath: rule.sourcePath
            ))
        }

        return ExecutionGate(gateType: .permissions, items: items, status: .active)
    }

    // MARK: - Handler Helpers

    private func handlerLabel(for handler: ResolvedHookHandler) -> String {
        switch handler.handlerType {
        case .command:
            return handler.command ?? "command (unknown)"
        case .http:
            return handler.url ?? "HTTP hook"
        case .prompt:
            let preview = handler.prompt.map { String($0.prefix(60)) } ?? "prompt hook"
            return preview
        case .agent:
            return handler.model ?? "agent hook"
        case nil:
            return handler.rawType ?? "unknown hook type"
        }
    }

    private func handlerDetail(for handler: ResolvedHookHandler) -> String {
        var parts: [String] = []

        if let type = handler.handlerType {
            parts.append("Type: \(type.rawValue)")
        }

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

        return parts.isEmpty ? "" : parts.joined(separator: " · ")
    }

    // MARK: - Health

    private func computeHealth(from projection: SessionProjection) -> StageHealth {
        // If we have neither settings nor hooks data, no data
        guard projection.settings != nil || projection.hooks != nil else {
            return .noData
        }

        var warningCount = 0

        // Check for hook suppression as a warning
        if allHooksDisabled {
            warningCount += 1
        }

        // Check for permission issues
        if let settings = projection.settings {
            for issue in settings.issues {
                if issue.keyPath?.hasPrefix("permissions") == true {
                    switch issue.severity {
                    case .error: return .errors(1)
                    case .warning: warningCount += 1
                    case .info: break
                    }
                }
            }
        }

        if let hooks = projection.hooks {
            for issue in hooks.issues {
                switch issue.severity {
                case .error: return .errors(1)
                case .warning: warningCount += 1
                case .info: break
                }
            }
        }

        if warningCount > 0 { return .warnings(warningCount) }
        return .healthy
    }
}

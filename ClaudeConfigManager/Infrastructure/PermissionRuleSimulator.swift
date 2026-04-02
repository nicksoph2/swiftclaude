import Foundation

// MARK: - Simulation Result Types

/// Outcome of evaluating a tool invocation against the resolved permission rules.
enum PermissionOutcome: Equatable, Sendable {
    case blocked(by: String)
    case askUser(by: String)
    case allowed(by: String)
    case allowedByDefault
    case askedByDefault

    enum Gate: String, CaseIterable, Sendable {
        case deny
        case ask
        case allow
    }
}

/// A single step in the evaluation trace showing which rule was checked and the result.
struct EvaluationStep: Equatable, Sendable {
    let gate: PermissionOutcome.Gate
    let rule: String
    let scope: ResolutionScope?
    let matched: Bool
    let outcome: String
}

/// Describes a hook handler that would fire for the given tool invocation.
struct HookSimulationEntry: Equatable, Sendable {
    let event: String
    let handlerType: String
    let handlerSummary: String
}

/// Complete result of simulating a tool invocation against the resolved configuration.
struct SimulationResult: Equatable, Sendable {
    let outcome: PermissionOutcome
    let matchedRule: String?
    let matchedRuleScope: ResolutionScope?
    let matchedAt: PermissionOutcome.Gate
    let hooksTriggered: [HookSimulationEntry]
    let evaluationTrace: [EvaluationStep]
}

// MARK: - Permission Rule Simulator

/// Pure rule evaluator — no network, no file I/O, no code execution.
struct PermissionRuleSimulator {

    // MARK: - Public API

    func evaluate(
        toolInvocation: String,
        against projection: SessionProjection
    ) -> SimulationResult {
        let rules = extractPermissionRules(from: projection)
        var trace: [EvaluationStep] = []
        var matchedRule: String?
        var matchedScope: ResolutionScope?
        var matchedGate: PermissionOutcome.Gate?
        var outcome: PermissionOutcome?

        // Gate 1: Deny rules
        for rule in rules.deny {
            let matched = fnmatch(pattern: rule.pattern, against: toolInvocation)
            let stepOutcome = matched ? "Matched → BLOCKED" : "No match"
            trace.append(EvaluationStep(
                gate: .deny,
                rule: rule.pattern,
                scope: rule.scope,
                matched: matched,
                outcome: stepOutcome
            ))
            if matched, outcome == nil {
                outcome = .blocked(by: rule.pattern)
                matchedRule = rule.pattern
                matchedScope = rule.scope
                matchedGate = .deny
            }
        }

        // Gate 2: Ask rules (only if no deny matched)
        if outcome == nil {
            for rule in rules.ask {
                let matched = fnmatch(pattern: rule.pattern, against: toolInvocation)
                let stepOutcome = matched ? "Matched → ASK USER" : "No match"
                trace.append(EvaluationStep(
                    gate: .ask,
                    rule: rule.pattern,
                    scope: rule.scope,
                    matched: matched,
                    outcome: stepOutcome
                ))
                if matched, outcome == nil {
                    outcome = .askUser(by: rule.pattern)
                    matchedRule = rule.pattern
                    matchedScope = rule.scope
                    matchedGate = .ask
                }
            }
        }

        // Gate 3: Allow rules (only if no deny or ask matched)
        if outcome == nil {
            for rule in rules.allow {
                let matched = fnmatch(pattern: rule.pattern, against: toolInvocation)
                let stepOutcome = matched ? "Matched → ALLOWED" : "No match"
                trace.append(EvaluationStep(
                    gate: .allow,
                    rule: rule.pattern,
                    scope: rule.scope,
                    matched: matched,
                    outcome: stepOutcome
                ))
                if matched, outcome == nil {
                    outcome = .allowed(by: rule.pattern)
                    matchedRule = rule.pattern
                    matchedScope = rule.scope
                    matchedGate = .allow
                }
            }
        }

        // Default outcome
        let finalOutcome = outcome ?? .askedByDefault
        let finalGate = matchedGate ?? .ask

        // Hooks simulation
        let hooks = simulateHooks(toolInvocation: toolInvocation, projection: projection)

        return SimulationResult(
            outcome: finalOutcome,
            matchedRule: matchedRule,
            matchedRuleScope: matchedScope,
            matchedAt: finalGate,
            hooksTriggered: hooks,
            evaluationTrace: trace
        )
    }

    // MARK: - Pattern Matching

    /// Simple fnmatch-style pattern matching. `*` matches any sequence of characters.
    func fnmatch(pattern: String, against value: String) -> Bool {
        // Exact match fast path
        if pattern == value { return true }

        // No wildcard — must be exact
        guard pattern.contains("*") else {
            return pattern == value
        }

        // Split on `*` and match greedily
        let segments = pattern.components(separatedBy: "*")
        var searchStart = value.startIndex

        for (index, segment) in segments.enumerated() {
            if segment.isEmpty { continue }

            // First segment must match at the beginning if pattern doesn't start with *
            if index == 0, !pattern.hasPrefix("*") {
                guard value.hasPrefix(segment) else { return false }
                searchStart = value.index(value.startIndex, offsetBy: segment.count)
                continue
            }

            // Last segment must match at the end if pattern doesn't end with *
            if index == segments.count - 1, !pattern.hasSuffix("*") {
                let remaining = value[searchStart...]
                guard remaining.hasSuffix(segment) else { return false }
                continue
            }

            // Interior segment — find next occurrence
            let remaining = value[searchStart...]
            guard let range = remaining.range(of: segment) else { return false }
            searchStart = range.upperBound
        }

        return true
    }

    // MARK: - Rule Extraction

    private struct RuleEntry {
        let pattern: String
        let scope: ResolutionScope?
    }

    private struct ExtractedRules {
        let deny: [RuleEntry]
        let ask: [RuleEntry]
        let allow: [RuleEntry]
    }

    private func extractPermissionRules(from projection: SessionProjection) -> ExtractedRules {
        guard let settings = projection.settings else {
            return ExtractedRules(deny: [], ask: [], allow: [])
        }

        var denyRules: [RuleEntry] = []
        var askRules: [RuleEntry] = []
        var allowRules: [RuleEntry] = []

        for entry in settings.entries {
            guard entry.keyPath.hasPrefix("permissions.") else { continue }

            let ruleType: PermissionOutcome.Gate
            if entry.keyPath.hasSuffix(".deny") || entry.keyPath == "permissions.deny" {
                ruleType = .deny
            } else if entry.keyPath.hasSuffix(".ask") || entry.keyPath == "permissions.ask" {
                ruleType = .ask
            } else if entry.keyPath.hasSuffix(".allow") || entry.keyPath == "permissions.allow" {
                ruleType = .allow
            } else {
                continue
            }

            guard let jsonValue = entry.value.effectiveValue,
                  case .array(let items) = jsonValue else { continue }

            let scope = entry.value.winningSource?.scope

            for item in items {
                guard case .string(let pattern) = item else { continue }
                let ruleEntry = RuleEntry(pattern: pattern, scope: scope)
                switch ruleType {
                case .deny:
                    denyRules.append(ruleEntry)
                case .ask:
                    askRules.append(ruleEntry)
                case .allow:
                    allowRules.append(ruleEntry)
                }
            }
        }

        return ExtractedRules(deny: denyRules, ask: askRules, allow: allowRules)
    }

    // MARK: - Hooks Simulation

    private func simulateHooks(
        toolInvocation: String,
        projection: SessionProjection
    ) -> [HookSimulationEntry] {
        guard let hookSnapshot = projection.hooks else { return [] }

        var results: [HookSimulationEntry] = []

        for event in hookSnapshot.events {
            // Only consider PreToolUse and PostToolUse events
            guard event.eventType == .preToolUse || event.eventType == .postToolUse else {
                continue
            }

            // Skip suppressed events
            if event.suppression != nil { continue }

            // Check if the event has a matcher (tool filter)
            let eventMatches = doesEventMatch(event: event, toolInvocation: toolInvocation)
            guard eventMatches else { continue }

            // Each handler in the event fires
            for handler in event.resolvedHandlers {
                let typeName = handler.handlerType?.rawValue ?? handler.rawType ?? "unknown"
                let summary = handlerSummary(for: handler)
                results.append(HookSimulationEntry(
                    event: event.eventType == .preToolUse ? "PreToolUse" : "PostToolUse",
                    handlerType: typeName,
                    handlerSummary: summary
                ))
            }
        }

        return results
    }

    /// Check if a hook event matches the tool invocation.
    /// Events with no matcher match all invocations.
    /// Events with a matcher only match if the tool name matches.
    private func doesEventMatch(
        event: ResolvedHookEventEntry,
        toolInvocation: String
    ) -> Bool {
        // Check if the raw hooks value contains a matcher
        guard let effectiveValue = event.hooks.effectiveValue else { return false }

        // The hooks are stored as an array of handler objects.
        // The matcher is at the event level, not handler level.
        // We need to check the raw JSON structure for the "matcher" field.
        // Since ResolvedHookEventEntry doesn't expose matcher directly,
        // we check if the eventID contains tool-specific info, or
        // conservatively include events without matchers (they fire for all tools).

        // Look at the event's raw hooks value for matcher info.
        // Since we can't access the parent event object directly from the resolved
        // handlers, and the matcher is not stored on ResolvedHookEventEntry,
        // events without matchers fire for all tool invocations.
        // Events with matchers are identified from the eventID pattern.
        // For now, include all PreToolUse/PostToolUse handlers (conservative approach).
        return true
    }

    private func handlerSummary(for handler: ResolvedHookHandler) -> String {
        if let command = handler.command {
            let truncated = command.count > 60
                ? String(command.prefix(57)) + "..."
                : command
            return truncated
        }
        if let url = handler.url {
            let truncated = url.count > 60
                ? String(url.prefix(57)) + "..."
                : url
            return truncated
        }
        if let prompt = handler.prompt {
            let truncated = prompt.count > 60
                ? String(prompt.prefix(57)) + "..."
                : prompt
            return truncated
        }
        return handler.handlerType?.rawValue ?? "unknown handler"
    }
}

import SwiftUI
import Combine

/// View model for the Session Timeline — a chronological narrative of a Claude
/// exchange from config loading through prompt, reply, and agentic loop.
///
/// Unlike the Flow Strip (which organises by pipeline phase), this view
/// orders entries by *when* they happen and describes *what* is being
/// set, said or done — ignoring file types entirely.
@MainActor
final class SessionTimelineViewModel: ObservableObject {

    // MARK: - Published state

    @Published var moments: [TimelineMoment] = []
    @Published var expandedMomentIDs: Set<String> = []

    // MARK: - Pipeline binding

    private weak var pipeline: ConfigurationPipeline?
    private var cancellables = Set<AnyCancellable>()

    func bind(to pipeline: ConfigurationPipeline) {
        self.pipeline = pipeline

        pipeline.$projection
            .combineLatest(pipeline.$scanResult, pipeline.$parseResults)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] projection, scanResult, parseResults in
                self?.rebuild(projection: projection, scanResult: scanResult, parseResults: parseResults)
            }
            .store(in: &cancellables)
    }

    func toggleMoment(_ id: String) {
        if expandedMomentIDs.contains(id) {
            expandedMomentIDs.remove(id)
        } else {
            expandedMomentIDs.insert(id)
        }
    }

    func isExpanded(_ id: String) -> Bool {
        expandedMomentIDs.contains(id)
    }

    // MARK: - Rebuild

    private func rebuild(
        projection: SessionProjection?,
        scanResult: ScanResult?,
        parseResults: [ParseResultRecord]
    ) {
        var result: [TimelineMoment] = []

        // ── Act 1: Environment builds up (least sticky → stickiest) ──

        result.append(contentsOf: buildEnvironmentMoments(
            projection: projection, scanResult: scanResult
        ))

        // ── Act 2: Merged state — what Claude knows before you speak ──

        result.append(contentsOf: buildReadyStateMoments(projection: projection))

        // ── Act 3: You speak — prompt submission and hooks ──

        result.append(contentsOf: buildPromptMoments(projection: projection))

        // ── Act 4: Claude acts — API call, tool use, reply ──

        result.append(contentsOf: buildExchangeMoments(projection: projection))

        // ── Act 5: The loop — agentic continuation ──

        result.append(contentsOf: buildLoopMoments(projection: projection))

        moments = result
    }

    // MARK: - Act 1 — Environment

    private func buildEnvironmentMoments(
        projection: SessionProjection?,
        scanResult: ScanResult?
    ) -> [TimelineMoment] {
        var moments: [TimelineMoment] = []

        // Session / CLI overrides — least sticky, applied per-invocation
        if let settings = projection?.settings {
            let cliEntries = settings.entries.filter { entry in
                entry.value.trace.participants.contains { $0.scope == .cli }
            }
            if !cliEntries.isEmpty {
                let items = cliEntries.map { entry in
                    TimelineDetail(
                        text: describeSettingPurpose(entry.keyPath, value: entry.value.effectiveValue),
                        note: "Overrides everything for this invocation",
                        status: .active
                    )
                }
                moments.append(TimelineMoment(
                    id: "env-cli",
                    act: .environment,
                    ordinal: 0,
                    headline: "Command-line overrides applied",
                    narrative: "\(cliEntries.count) setting\(cliEntries.count == 1 ? "" : "s") passed as CLI flags — these override everything but are gone next run.",
                    icon: "terminal",
                    tint: .gray,
                    details: items
                ))
            }

            // Session-level settings
            let sessionEntries = settings.entries.filter { entry in
                entry.value.trace.participants.contains { $0.scope == .session }
            }
            if !sessionEntries.isEmpty {
                let items = sessionEntries.map { entry in
                    TimelineDetail(
                        text: describeSettingPurpose(entry.keyPath, value: entry.value.effectiveValue),
                        note: "Applies to this session only",
                        status: .active
                    )
                }
                moments.append(TimelineMoment(
                    id: "env-session",
                    act: .environment,
                    ordinal: 1,
                    headline: "Session-level settings",
                    narrative: "Temporary settings that last for this session only.",
                    icon: "clock.arrow.circlepath",
                    tint: .gray,
                    details: items
                ))
            }
        }

        // Project-local — personal, not committed
        if let settings = projection?.settings {
            let localEntries = settings.entries.filter { entry in
                entry.value.trace.participants.contains { $0.scope == .projectLocal }
            }
            if !localEntries.isEmpty {
                let items = localEntries.map { entry in
                    let isWinner = entry.value.winningSource?.scope == .projectLocal
                    return TimelineDetail(
                        text: describeSettingPurpose(entry.keyPath, value: entry.value.effectiveValue),
                        note: isWinner ? "Your personal preference — wins here" : "Defined but overridden by a higher scope",
                        status: isWinner ? .active : .overridden
                    )
                }
                moments.append(TimelineMoment(
                    id: "env-project-local",
                    act: .environment,
                    ordinal: 2,
                    headline: "Your personal project preferences",
                    narrative: "Settings you've set for this project that aren't shared with the team.",
                    icon: "person.crop.circle",
                    tint: ScopeColorScheme.color(for: .projectLocal),
                    details: items
                ))
            }
        }

        // Project — shared team settings
        if let settings = projection?.settings {
            let projectEntries = settings.entries.filter { entry in
                entry.value.trace.participants.contains { $0.scope == .project }
            }
            if !projectEntries.isEmpty {
                let items = projectEntries.map { entry in
                    let isWinner = entry.value.winningSource?.scope == .project
                    return TimelineDetail(
                        text: describeSettingPurpose(entry.keyPath, value: entry.value.effectiveValue),
                        note: isWinner ? "Team setting — applies to everyone on this project" : "Set by the team but overridden",
                        status: isWinner ? .active : .overridden
                    )
                }
                moments.append(TimelineMoment(
                    id: "env-project",
                    act: .environment,
                    ordinal: 3,
                    headline: "Team project configuration",
                    narrative: "Shared settings committed to the project — everyone on this repo gets these.",
                    icon: "folder.badge.gearshape",
                    tint: ScopeColorScheme.color(for: .project),
                    details: items
                ))
            }
        }

        // User — your global defaults
        if let settings = projection?.settings {
            let userEntries = settings.entries.filter { entry in
                entry.value.trace.participants.contains { $0.scope == .user }
            }
            if !userEntries.isEmpty {
                let items = userEntries.map { entry in
                    let isWinner = entry.value.winningSource?.scope == .user
                    return TimelineDetail(
                        text: describeSettingPurpose(entry.keyPath, value: entry.value.effectiveValue),
                        note: isWinner ? "Your global default" : "You set this, but a higher scope overrides it",
                        status: isWinner ? .active : .overridden
                    )
                }
                moments.append(TimelineMoment(
                    id: "env-user",
                    act: .environment,
                    ordinal: 4,
                    headline: "Your global defaults",
                    narrative: "Settings from your user profile — apply everywhere unless a project overrides them.",
                    icon: "person.fill",
                    tint: ScopeColorScheme.color(for: .user),
                    details: items
                ))
            }
        }

        // Managed — enterprise / organisational policy
        if let settings = projection?.settings {
            let managedEntries = settings.entries.filter { entry in
                entry.value.trace.participants.contains { $0.scope == .managed }
            }
            if !managedEntries.isEmpty {
                let items = managedEntries.map { entry in
                    TimelineDetail(
                        text: describeSettingPurpose(entry.keyPath, value: entry.value.effectiveValue),
                        note: "Organisation policy — cannot be overridden",
                        status: .enforced
                    )
                }
                moments.append(TimelineMoment(
                    id: "env-managed",
                    act: .environment,
                    ordinal: 5,
                    headline: "Organisation policy applied",
                    narrative: "Managed settings from your enterprise admin — these are final and cannot be overridden by any lower scope.",
                    icon: "building.2",
                    tint: ScopeColorScheme.color(for: .managed),
                    details: items
                ))
            }
        }

        return moments
    }

    // MARK: - Act 2 — Ready state

    private func buildReadyStateMoments(projection: SessionProjection?) -> [TimelineMoment] {
        guard let projection else { return [] }
        var moments: [TimelineMoment] = []

        // Instructions loaded
        if let instructions = projection.instructions {
            let blockCount = instructions.orderedBlocks.count
            var items: [TimelineDetail] = []

            for block in instructions.orderedBlocks {
                let scope = block.content.winningSource?.scope
                let scopeLabel = scope?.rawValue.localizedCapitalized ?? "Unknown"
                let tokenCount = block.content.effectiveValue.map { TokenEstimator.estimateTokenCount($0) } ?? 0

                // Extract first heading as a description
                let firstHeading = block.content.effectiveValue
                    .flatMap { extractFirstHeading($0) } ?? block.blockID

                items.append(TimelineDetail(
                    text: "From \(scopeLabel): \(firstHeading)",
                    note: "~\(tokenCount) tokens of instructions",
                    status: .active
                ))
            }

            let totalTokens = instructions.orderedBlocks.compactMap {
                $0.content.effectiveValue.map { TokenEstimator.estimateTokenCount($0) }
            }.reduce(0, +)

            moments.append(TimelineMoment(
                id: "ready-instructions",
                act: .readyState,
                ordinal: 10,
                headline: "Instructions assembled",
                narrative: "\(blockCount) CLAUDE.md layer\(blockCount == 1 ? "" : "s") loaded in order — together they tell Claude who it is and how to behave. ~\(totalTokens) tokens.",
                icon: "doc.text",
                tint: .green,
                details: items
            ))
        }

        // MCP servers ready
        if let mcp = projection.mcp {
            let activeServers = mcp.servers.filter { $0.effectiveState == .active }
            let disabledServers = mcp.servers.filter { $0.effectiveState != .active }

            var items: [TimelineDetail] = []
            for server in activeServers {
                items.append(TimelineDetail(
                    text: "\(server.serverID) is available",
                    note: server.stateExplanation.isEmpty ? "Ready to accept tool calls" : server.stateExplanation,
                    status: .active
                ))
            }
            for server in disabledServers {
                items.append(TimelineDetail(
                    text: "\(server.serverID) is \(server.effectiveState.rawValue)",
                    note: server.stateExplanation,
                    status: .inactive
                ))
            }

            if !mcp.servers.isEmpty {
                moments.append(TimelineMoment(
                    id: "ready-mcp",
                    act: .readyState,
                    ordinal: 11,
                    headline: "Tool servers connected",
                    narrative: "\(activeServers.count) MCP server\(activeServers.count == 1 ? "" : "s") active, \(disabledServers.count) disabled — these define what Claude can do beyond text.",
                    icon: "server.rack",
                    tint: .teal,
                    details: items
                ))
            }
        }

        // Permission rules summarised
        if let settings = projection.settings {
            let permEntries = settings.entries.filter { entry in
                entry.keyPath.hasPrefix("permissions")
            }
            if !permEntries.isEmpty {
                let items = permEntries.map { entry in
                    TimelineDetail(
                        text: describeSettingPurpose(entry.keyPath, value: entry.value.effectiveValue),
                        note: "From \(entry.value.winningSource?.scope.rawValue.localizedCapitalized ?? "unknown")",
                        status: .active
                    )
                }
                moments.append(TimelineMoment(
                    id: "ready-permissions",
                    act: .readyState,
                    ordinal: 12,
                    headline: "Permission boundaries set",
                    narrative: "Rules that govern what Claude may do without asking — file edits, shell commands, network access.",
                    icon: "lock.shield",
                    tint: .orange,
                    details: items
                ))
            }
        }

        // Context budget
        let systemTokens = PromptLayerConstants.systemPromptTokens
        let toolTokens = PromptLayerConstants.toolDefinitionTokens
        let contextWindow = PromptLayerConstants.contextWindowSize
        var instructionTokens = 0
        if let instructions = projection.instructions {
            for block in instructions.orderedBlocks {
                if let text = block.content.effectiveValue {
                    instructionTokens += TokenEstimator.estimateTokenCount(text)
                }
            }
        }
        let overhead = PromptLayerConstants.baselineOverhead
        let used = systemTokens + toolTokens + instructionTokens + overhead
        let available = contextWindow - used

        moments.append(TimelineMoment(
            id: "ready-budget",
            act: .readyState,
            ordinal: 13,
            headline: "Context window: \(available / 1000)K tokens available",
            narrative: "Of the \(contextWindow / 1000)K token window, \(used / 1000)K is already spoken for by system prompt, instructions, and tool definitions. The remaining \(available / 1000)K is yours for conversation.",
            icon: "gauge.with.needle",
            tint: .orange,
            details: [
                TimelineDetail(text: "System prompt", note: "\(systemTokens / 1000)K tokens", status: .active),
                TimelineDetail(text: "Your instructions", note: "\(instructionTokens / 1000)K tokens", status: .active),
                TimelineDetail(text: "Tool definitions", note: "\(toolTokens / 1000)K tokens", status: .active),
                TimelineDetail(text: "Overhead", note: "\(overhead / 1000)K tokens", status: .inactive),
            ]
        ))

        return moments
    }

    // MARK: - Act 3 — Prompt

    private func buildPromptMoments(projection: SessionProjection?) -> [TimelineMoment] {
        var moments: [TimelineMoment] = []

        // Hook: userPromptSubmit fires before anything else
        if let hooks = projection?.hooks {
            let promptHooks = hooks.events.filter { $0.eventType == .userPromptSubmit }
            if !promptHooks.isEmpty {
                let items = promptHooks.flatMap { event in
                    event.resolvedHandlers.map { handler in
                        TimelineDetail(
                            text: "Runs: \(handler.command ?? handler.url ?? handler.handlerType?.rawValue ?? "handler")",
                            note: "Fires before your prompt reaches Claude",
                            status: .active
                        )
                    }
                }
                moments.append(TimelineMoment(
                    id: "prompt-hook-submit",
                    act: .prompt,
                    ordinal: 20,
                    headline: "Pre-prompt hooks fire",
                    narrative: "Before your message is sent, these handlers run — they can validate, transform, or log the prompt.",
                    icon: "bolt.fill",
                    tint: .purple,
                    details: items
                ))
            }
        }

        moments.append(TimelineMoment(
            id: "prompt-user-message",
            act: .prompt,
            ordinal: 21,
            headline: "You send your message",
            narrative: "Your prompt is combined with the system prompt, instructions, tool definitions, and conversation history into a single API request.",
            icon: "bubble.right.fill",
            tint: .blue,
            details: []
        ))

        return moments
    }

    // MARK: - Act 4 — Exchange

    private func buildExchangeMoments(projection: SessionProjection?) -> [TimelineMoment] {
        var moments: [TimelineMoment] = []

        moments.append(TimelineMoment(
            id: "exchange-api-call",
            act: .exchange,
            ordinal: 30,
            headline: "Claude receives the assembled prompt",
            narrative: "The API request arrives at Claude. It sees: your system prompt, instructions from all CLAUDE.md layers, tool definitions for every active MCP server, and the conversation so far.",
            icon: "brain",
            tint: .indigo,
            details: []
        ))

        // Pre-tool-use hooks
        if let hooks = projection?.hooks {
            let preToolHooks = hooks.events.filter { $0.eventType == .preToolUse }
            if !preToolHooks.isEmpty {
                let items = preToolHooks.flatMap { event in
                    event.resolvedHandlers.map { handler in
                        TimelineDetail(
                            text: "Runs: \(handler.command ?? handler.url ?? handler.handlerType?.rawValue ?? "handler")",
                            note: "Can approve, deny, or modify each tool call",
                            status: .active
                        )
                    }
                }
                moments.append(TimelineMoment(
                    id: "exchange-hook-pretool",
                    act: .exchange,
                    ordinal: 31,
                    headline: "Pre-tool-use hooks fire",
                    narrative: "Before Claude executes any tool, these handlers get a chance to approve, deny, or modify the call.",
                    icon: "hand.raised.fill",
                    tint: .purple,
                    details: items
                ))
            }

            // Permission request hooks
            let permHooks = hooks.events.filter { $0.eventType == .permissionRequest }
            if !permHooks.isEmpty {
                let items = permHooks.flatMap { event in
                    event.resolvedHandlers.map { handler in
                        TimelineDetail(
                            text: "Runs: \(handler.command ?? handler.url ?? handler.handlerType?.rawValue ?? "handler")",
                            note: "Decides whether to grant permission",
                            status: .active
                        )
                    }
                }
                moments.append(TimelineMoment(
                    id: "exchange-hook-permission",
                    act: .exchange,
                    ordinal: 32,
                    headline: "Permission check",
                    narrative: "If Claude wants to do something that needs approval, permission hooks evaluate the request against your rules.",
                    icon: "checkmark.shield",
                    tint: .orange,
                    details: items
                ))
            }
        }

        moments.append(TimelineMoment(
            id: "exchange-tool-execution",
            act: .exchange,
            ordinal: 33,
            headline: "Claude uses tools",
            narrative: "Claude calls tools (file reads, shell commands, MCP servers) and receives their results. Each tool result is appended to the conversation.",
            icon: "wrench.and.screwdriver",
            tint: .teal,
            details: []
        ))

        // Post-tool-use hooks
        if let hooks = projection?.hooks {
            let postToolHooks = hooks.events.filter { $0.eventType == .postToolUse }
            let failureHooks = hooks.events.filter { $0.eventType == .postToolUseFailure }
            var items: [TimelineDetail] = []
            for event in postToolHooks {
                for handler in event.resolvedHandlers {
                    items.append(TimelineDetail(
                        text: "Runs: \(handler.command ?? handler.url ?? handler.handlerType?.rawValue ?? "handler")",
                        note: "After each successful tool call",
                        status: .active
                    ))
                }
            }
            for event in failureHooks {
                for handler in event.resolvedHandlers {
                    items.append(TimelineDetail(
                        text: "On failure: \(handler.command ?? handler.url ?? handler.handlerType?.rawValue ?? "handler")",
                        note: "Runs when a tool call fails",
                        status: .warning
                    ))
                }
            }
            if !items.isEmpty {
                moments.append(TimelineMoment(
                    id: "exchange-hook-posttool",
                    act: .exchange,
                    ordinal: 34,
                    headline: "Post-tool-use hooks fire",
                    narrative: "After each tool call completes (or fails), these handlers can log, validate, or take follow-up action.",
                    icon: "bolt.badge.checkmark",
                    tint: .purple,
                    details: items
                ))
            }
        }

        moments.append(TimelineMoment(
            id: "exchange-reply",
            act: .exchange,
            ordinal: 35,
            headline: "Claude replies",
            narrative: "Claude produces its text response, which may include reasoning about tool results. This is streamed back to you.",
            icon: "bubble.left.fill",
            tint: .green,
            details: []
        ))

        return moments
    }

    // MARK: - Act 5 — Loop

    private func buildLoopMoments(projection: SessionProjection?) -> [TimelineMoment] {
        var moments: [TimelineMoment] = []

        moments.append(TimelineMoment(
            id: "loop-decision",
            act: .loop,
            ordinal: 40,
            headline: "Continue or stop?",
            narrative: "If Claude's reply contains tool-use blocks, the loop continues — tool results feed back in and Claude responds again. This repeats until Claude produces a final text-only reply.",
            icon: "arrow.triangle.2.circlepath",
            tint: .indigo,
            details: []
        ))

        // Stop hooks
        if let hooks = projection?.hooks {
            let stopHooks = hooks.events.filter { $0.eventType == .stop }
            let stopFailHooks = hooks.events.filter { $0.eventType == .stopFailure }
            var items: [TimelineDetail] = []
            for event in stopHooks {
                for handler in event.resolvedHandlers {
                    items.append(TimelineDetail(
                        text: "Runs: \(handler.command ?? handler.url ?? handler.handlerType?.rawValue ?? "handler")",
                        note: "When the turn ends normally",
                        status: .active
                    ))
                }
            }
            for event in stopFailHooks {
                for handler in event.resolvedHandlers {
                    items.append(TimelineDetail(
                        text: "On failure: \(handler.command ?? handler.url ?? handler.handlerType?.rawValue ?? "handler")",
                        note: "When the turn ends with an error",
                        status: .warning
                    ))
                }
            }
            if !items.isEmpty {
                moments.append(TimelineMoment(
                    id: "loop-hook-stop",
                    act: .loop,
                    ordinal: 41,
                    headline: "Stop hooks fire",
                    narrative: "When Claude's turn ends, these handlers run — useful for logging, cleanup, or triggering follow-up actions.",
                    icon: "flag.checkered",
                    tint: .purple,
                    details: items
                ))
            }

            // Notification hooks
            let notifHooks = hooks.events.filter { $0.eventType == .notification }
            if !notifHooks.isEmpty {
                let items = notifHooks.flatMap { event in
                    event.resolvedHandlers.map { handler in
                        TimelineDetail(
                            text: "Notifies: \(handler.command ?? handler.url ?? handler.handlerType?.rawValue ?? "handler")",
                            note: "External notification sent",
                            status: .active
                        )
                    }
                }
                moments.append(TimelineMoment(
                    id: "loop-hook-notify",
                    act: .loop,
                    ordinal: 42,
                    headline: "Notifications sent",
                    narrative: "If configured, external notifications fire when Claude finishes its turn.",
                    icon: "bell.fill",
                    tint: .yellow,
                    details: items
                ))
            }
        }

        // Subagent hooks
        if let hooks = projection?.hooks {
            let subStart = hooks.events.filter { $0.eventType == .subagentStart }
            let subStop = hooks.events.filter { $0.eventType == .subagentStop }
            if !subStart.isEmpty || !subStop.isEmpty {
                var items: [TimelineDetail] = []
                for event in subStart {
                    for handler in event.resolvedHandlers {
                        items.append(TimelineDetail(
                            text: "On spawn: \(handler.command ?? handler.url ?? handler.handlerType?.rawValue ?? "handler")",
                            note: "When a sub-agent starts",
                            status: .active
                        ))
                    }
                }
                for event in subStop {
                    for handler in event.resolvedHandlers {
                        items.append(TimelineDetail(
                            text: "On complete: \(handler.command ?? handler.url ?? handler.handlerType?.rawValue ?? "handler")",
                            note: "When a sub-agent finishes",
                            status: .active
                        ))
                    }
                }
                moments.append(TimelineMoment(
                    id: "loop-subagent",
                    act: .loop,
                    ordinal: 43,
                    headline: "Sub-agent lifecycle",
                    narrative: "If Claude spawns a sub-agent (via the Agent tool), these hooks bracket its lifecycle.",
                    icon: "person.2.fill",
                    tint: .purple,
                    details: items
                ))
            }
        }

        // Compaction hooks
        if let hooks = projection?.hooks {
            let preCompact = hooks.events.filter { $0.eventType == .preCompact }
            let postCompact = hooks.events.filter { $0.eventType == .postCompact }
            if !preCompact.isEmpty || !postCompact.isEmpty {
                var items: [TimelineDetail] = []
                for event in preCompact {
                    for handler in event.resolvedHandlers {
                        items.append(TimelineDetail(
                            text: "Before compaction: \(handler.command ?? handler.url ?? handler.handlerType?.rawValue ?? "handler")",
                            note: "Runs before context is trimmed",
                            status: .active
                        ))
                    }
                }
                for event in postCompact {
                    for handler in event.resolvedHandlers {
                        items.append(TimelineDetail(
                            text: "After compaction: \(handler.command ?? handler.url ?? handler.handlerType?.rawValue ?? "handler")",
                            note: "Runs after context is trimmed",
                            status: .active
                        ))
                    }
                }
                moments.append(TimelineMoment(
                    id: "loop-compact",
                    act: .loop,
                    ordinal: 44,
                    headline: "Context compaction",
                    narrative: "When the conversation outgrows the context window, Claude summarises older messages. These hooks bracket that process.",
                    icon: "arrow.down.right.and.arrow.up.left",
                    tint: .orange,
                    details: items
                ))
            }
        }

        return moments
    }

    // MARK: - Helpers

    /// Describe a setting in human terms rather than showing the key path.
    private func describeSettingPurpose(_ keyPath: String, value: JSONValue?) -> String {
        let shortKey = keyPath.components(separatedBy: ".").last ?? keyPath
        let displayValue = formatValueBrief(value)

        // Map well-known keys to plain-English descriptions
        switch keyPath {
        case "model":
            return "Model set to \(displayValue)"
        case "smallModel":
            return "Quick-response model: \(displayValue)"
        case "maxTurns":
            return "Maximum agentic turns: \(displayValue)"
        case "maxThinkingTokens":
            return "Thinking budget: \(displayValue) tokens"
        case "permissions.allow":
            return "Allowed without asking: \(displayValue)"
        case "permissions.deny":
            return "Denied always: \(displayValue)"
        case "permissions.additionalDirectories":
            return "Extra directories Claude can access: \(displayValue)"
        case "permissions.defaultAllow":
            return displayValue == "true"
                ? "Default to allowing tool use"
                : "Default to asking before tool use"
        case "apiKey":
            return "API key configured"
        case "primaryOrganization":
            return "Organisation: \(displayValue)"
        case "hasCompletedOnboarding":
            return displayValue == "true" ? "Onboarding completed" : "Onboarding not completed"
        case "theme":
            return "Terminal theme: \(displayValue)"
        case "verbose":
            return displayValue == "true" ? "Verbose logging enabled" : "Verbose logging disabled"
        case "sharedBashState":
            return displayValue == "true" ? "Bash state shared between tools" : "Isolated bash sessions"
        case "templateMacroExpansion":
            return displayValue == "true" ? "Template macros expanded" : "Template macros disabled"
        default:
            if keyPath.hasPrefix("permissions.") {
                return "Permission rule: \(shortKey) = \(displayValue)"
            }
            if keyPath.hasPrefix("hooks.") {
                return "Hook configuration: \(shortKey)"
            }
            if keyPath.hasPrefix("mcpServers.") {
                return "MCP server config: \(shortKey)"
            }
            return "\(shortKey): \(displayValue)"
        }
    }

    private func formatValueBrief(_ value: JSONValue?) -> String {
        guard let value else { return "not set" }
        switch value {
        case .string(let s): return s.count > 40 ? String(s.prefix(37)) + "..." : s
        case .number(let n): return n == n.rounded() ? String(Int(n)) : String(format: "%.1f", n)
        case .bool(let b): return b ? "true" : "false"
        case .null: return "null"
        case .array(let arr): return "[\(arr.count) items]"
        case .object(let obj): return "{\(obj.count) keys}"
        }
    }

    private func extractFirstHeading(_ markdown: String) -> String? {
        for line in markdown.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2))
            }
            if trimmed.hasPrefix("## ") {
                return String(trimmed.dropFirst(3))
            }
        }
        return nil
    }
}

// MARK: - Data models

/// A single moment in the chronological timeline of a Claude exchange.
struct TimelineMoment: Identifiable {
    let id: String
    let act: TimelineAct
    let ordinal: Int
    let headline: String
    let narrative: String
    let icon: String
    let tint: Color
    let details: [TimelineDetail]
}

/// Which act of the exchange timeline this moment belongs to.
enum TimelineAct: String, CaseIterable {
    case environment  = "Environment"
    case readyState   = "Ready State"
    case prompt       = "Your Prompt"
    case exchange     = "The Exchange"
    case loop         = "The Loop"

    var subtitle: String {
        switch self {
        case .environment: "Configuration layers build up from least sticky to most"
        case .readyState:  "Everything Claude knows before you speak"
        case .prompt:      "You type, hooks fire, the prompt is assembled"
        case .exchange:    "Claude thinks, uses tools, and replies"
        case .loop:        "The agentic cycle: tool results feed back in"
        }
    }

    var icon: String {
        switch self {
        case .environment: "square.stack.3d.up"
        case .readyState:  "checkmark.circle"
        case .prompt:      "bubble.right"
        case .exchange:    "arrow.left.arrow.right"
        case .loop:        "arrow.triangle.2.circlepath"
        }
    }

    var tint: Color {
        switch self {
        case .environment: .gray
        case .readyState:  .green
        case .prompt:      .blue
        case .exchange:    .indigo
        case .loop:        .purple
        }
    }
}

/// A single detail line within a timeline moment.
struct TimelineDetail: Identifiable {
    let id = UUID()
    let text: String
    let note: String
    let status: DetailStatus

    enum DetailStatus {
        case active
        case overridden
        case inactive
        case enforced
        case warning
    }
}

import SwiftUI
import Combine

/// View model for the Flow Strip (View C).
///
/// Reads `SessionProjection` and `ScanResult` to build a phase-by-phase
/// narrative of how configuration becomes Claude's behaviour.
@MainActor
final class FlowStripViewModel: ObservableObject {

    // MARK: - Published state

    @Published var phases: [FlowPhase] = []
    @Published var expandedPhaseIDs: Set<String> = []
    @Published var detailLevel: DetailLevel = .scan

    enum DetailLevel: String, CaseIterable {
        case glance = "Summary"
        case scan = "Standard"
        case full = "Full Content"
    }

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

    func togglePhase(_ id: String) {
        if expandedPhaseIDs.contains(id) {
            expandedPhaseIDs.remove(id)
        } else {
            expandedPhaseIDs.insert(id)
        }
    }

    // MARK: - Rebuild

    private func rebuild(
        projection: SessionProjection?,
        scanResult: ScanResult?,
        parseResults: [ParseResultRecord]
    ) {
        var result: [FlowPhase] = []

        // Phase 1: Discovery
        result.append(buildDiscoveryPhase(scanResult: scanResult))

        // Phase 2: Settings Resolution
        if let settings = projection?.settings {
            result.append(buildSettingsPhase(settings: settings))
        }

        // Phase 3: Instructions
        if let instructions = projection?.instructions {
            result.append(buildInstructionsPhase(instructions: instructions))
        }

        // Phase 4: Tools & MCP
        if let mcp = projection?.mcp {
            result.append(buildMcpPhase(mcp: mcp))
        }

        // Phase 5: Hooks
        if let hooks = projection?.hooks {
            result.append(buildHooksPhase(hooks: hooks))
        }

        // Phase 6: Assembly (context budget)
        result.append(buildAssemblyPhase(projection: projection))

        phases = result
    }

    // MARK: - Phase builders

    private func buildDiscoveryPhase(scanResult: ScanResult?) -> FlowPhase {
        var sourceCards: [FlowSourceCard] = []

        if let scan = scanResult {
            // Build a card per discovered scope workspace
            let allWorkspaces: [DiscoveredWorkspace] = [scan.managedWorkspace, scan.userWorkspace].compactMap { $0 }
                + scan.projectWorkspaces

            for workspace in allWorkspaces {
                let scopeKind = workspace.scope.scopeKind
                let resScope = resolutionScope(for: scopeKind)
                let files = workspace.files.map { file in
                    FlowSourceEntry(
                        key: file.url.lastPathComponent,
                        value: "",
                        status: file.status == .present ? .found : .absent
                    )
                }
                let title = workspace.rootNormalizedPath.isEmpty
                    ? scopeKind.rawValue.localizedCapitalized
                    : workspace.rootNormalizedPath
                sourceCards.append(FlowSourceCard(
                    id: "\(scopeKind.rawValue)-\(workspace.rootNormalizedPath)",
                    title: title,
                    scope: resScope,
                    entries: files
                ))
            }
        }

        let fileCount = sourceCards.flatMap(\.entries).filter { $0.status == .found }.count
        let scopeCount = sourceCards.filter { !$0.entries.isEmpty }.count

        return FlowPhase(
            id: "discovery",
            number: 1,
            title: "Discovery",
            subtitle: "Find all config files",
            summary: "\(fileCount) files across \(scopeCount) scopes",
            color: .blue,
            sourceCards: sourceCards,
            mergeInfo: nil,
            budgetInfo: nil
        )
    }

    private func resolutionScope(for kind: DiscoveryScopeKind) -> ResolutionScope {
        switch kind {
        case .managed: .managed
        case .user:    .user
        case .project: .project
        }
    }

    private func buildSettingsPhase(settings: ResolvedSettingsSnapshot) -> FlowPhase {
        // Group entries by source scope to build source cards
        var scopeEntries: [ResolutionScope: [FlowSourceEntry]] = [:]

        for entry in settings.entries {
            for participant in entry.value.trace.participants {
                let isWinner = entry.value.winningSource?.scope == participant.scope
                let isOverridden = entry.value.trace.overridden.contains(participant)

                let status: FlowSourceEntry.EntryStatus
                if isWinner { status = .winner }
                else if isOverridden { status = .overridden }
                else { status = .contributor }

                let displayVal = formatJSONValueShort(entry.value.effectiveValue)

                let sourceEntry = FlowSourceEntry(
                    key: entry.keyPath,
                    value: displayVal,
                    status: status
                )
                scopeEntries[participant.scope, default: []].append(sourceEntry)
            }
        }

        let sourceCards = scopeEntries
            .sorted { scopePrecedence($0.key) < scopePrecedence($1.key) }
            .map { scope, entries in
                FlowSourceCard(
                    id: "settings-\(scope.rawValue)",
                    title: "\(scope.rawValue.localizedCapitalized) settings.json",
                    scope: scope,
                    entries: entries
                )
            }

        let conflictCount = settings.entries.filter { $0.value.trace.overridden.count > 0 }.count

        // Build merge info
        let methods = Set(settings.entries.map(\.value.mergeMethod))
        let mergeInfo = FlowMergeInfo(
            description: "Resolve by precedence",
            methods: methods.map(\.rawValue).sorted(),
            resolvedChips: [
                "\(settings.entries.count) keys resolved",
                conflictCount > 0 ? "\(conflictCount) overrides" : "no conflicts"
            ]
        )

        return FlowPhase(
            id: "settings",
            number: 2,
            title: "Settings",
            subtitle: "Parse & resolve settings.json",
            summary: "\(settings.entries.count) keys, \(conflictCount) conflict\(conflictCount == 1 ? "" : "s")",
            color: .orange,
            sourceCards: sourceCards,
            mergeInfo: mergeInfo,
            budgetInfo: nil
        )
    }

    private func buildInstructionsPhase(instructions: ResolvedInstructionSnapshot) -> FlowPhase {
        let sourceCards = instructions.orderedBlocks.map { block in
            let source = block.content.winningSource
            let scope = source?.scope ?? .project

            // Parse headings from content if available
            var entries: [FlowSourceEntry] = []
            if let text = block.content.effectiveValue {
                let headings = extractMarkdownHeadings(text)
                entries = headings.map { heading in
                    FlowSourceEntry(key: heading.text, value: heading.level, status: .found)
                }
                let lineCount = text.components(separatedBy: "\n").count
                let tokenEstimate = TokenEstimator.estimateTokenCount(text)
                entries.append(FlowSourceEntry(
                    key: "\(lineCount) lines",
                    value: "\(tokenEstimate) tokens",
                    status: .info
                ))
            }

            return FlowSourceCard(
                id: block.blockID,
                title: source?.displayName ?? block.blockID,
                scope: scope,
                entries: entries
            )
        }

        let totalTokens = instructions.orderedBlocks.compactMap { block in
            block.content.effectiveValue.map { TokenEstimator.estimateTokenCount($0) }
        }.reduce(0, +)

        let mergeInfo = FlowMergeInfo(
            description: "Append in load order",
            methods: ["append"],
            resolvedChips: [
                "\(instructions.orderedBlocks.count) layers",
                "~\(totalTokens) tokens total"
            ]
        )

        return FlowPhase(
            id: "instructions",
            number: 3,
            title: "Instructions",
            subtitle: "Layer CLAUDE.md files",
            summary: "\(instructions.orderedBlocks.count) sources → ~\(totalTokens) tokens",
            color: .green,
            sourceCards: sourceCards,
            mergeInfo: mergeInfo,
            budgetInfo: nil
        )
    }

    private func buildMcpPhase(mcp: ResolvedMcpSnapshot) -> FlowPhase {
        let sourceCards = mcp.servers.map { server in
            var entries: [FlowSourceEntry] = []
            entries.append(FlowSourceEntry(
                key: "state",
                value: server.effectiveState.rawValue,
                status: server.effectiveState == .active ? .found : .absent
            ))
            if !server.stateExplanation.isEmpty {
                entries.append(FlowSourceEntry(
                    key: "info",
                    value: server.stateExplanation,
                    status: .info
                ))
            }
            let winningScope = server.resolvedConfig.winningSource?.scope ?? .project
            return FlowSourceCard(
                id: server.serverID,
                title: server.serverID,
                scope: winningScope,
                entries: entries
            )
        }

        return FlowPhase(
            id: "mcp",
            number: 4,
            title: "Tools & MCP",
            subtitle: "Available tool catalog",
            summary: "\(mcp.servers.count) server\(mcp.servers.count == 1 ? "" : "s")",
            color: .teal,
            sourceCards: sourceCards,
            mergeInfo: nil,
            budgetInfo: nil
        )
    }

    private func buildHooksPhase(hooks: ResolvedHookSnapshot) -> FlowPhase {
        let sourceCards = hooks.events.map { event in
            let entries = event.resolvedHandlers.map { handler in
                FlowSourceEntry(
                    key: handler.handlerType?.rawValue ?? handler.rawType ?? "unknown",
                    value: handler.command ?? handler.url ?? "—",
                    status: .found
                )
            }

            let winningScope = event.hooks.winningSource?.scope ?? .project

            return FlowSourceCard(
                id: event.eventID,
                title: event.eventType.sortKey,
                scope: winningScope,
                entries: entries
            )
        }

        let handlerCount = hooks.events.flatMap(\.resolvedHandlers).count

        return FlowPhase(
            id: "hooks",
            number: 5,
            title: "Hooks & Lifecycle",
            subtitle: "Event handlers that bracket tool calls",
            summary: "\(hooks.events.count) events, \(handlerCount) handlers",
            color: .purple,
            sourceCards: sourceCards,
            mergeInfo: nil,
            budgetInfo: nil
        )
    }

    private func buildAssemblyPhase(projection: SessionProjection?) -> FlowPhase {
        let systemTokens = PromptLayerConstants.systemPromptTokens
        let toolTokens = PromptLayerConstants.toolDefinitionTokens
        let contextWindow = PromptLayerConstants.contextWindowSize

        var instructionTokens = 0
        if let instructions = projection?.instructions {
            for block in instructions.orderedBlocks {
                if let text = block.content.effectiveValue {
                    instructionTokens += TokenEstimator.estimateTokenCount(text)
                }
            }
        }

        let overhead = PromptLayerConstants.baselineOverhead
        let used = systemTokens + toolTokens + instructionTokens + overhead
        let available = contextWindow - used

        let budgetInfo = FlowBudgetInfo(
            contextWindow: contextWindow,
            segments: [
                FlowBudgetSegment(label: "System", tokens: systemTokens, color: .orange),
                FlowBudgetSegment(label: "Instructions", tokens: instructionTokens, color: .blue),
                FlowBudgetSegment(label: "Tools", tokens: toolTokens, color: .green),
                FlowBudgetSegment(label: "Overhead", tokens: overhead, color: .gray),
            ],
            usedTokens: used,
            availableTokens: available
        )

        return FlowPhase(
            id: "assembly",
            number: 6,
            title: "Prompt Assembly",
            subtitle: "Build the API request",
            summary: "\(used / 1000)K used of \(contextWindow / 1000)K window",
            color: .orange,
            sourceCards: [],
            mergeInfo: nil,
            budgetInfo: budgetInfo
        )
    }

    // MARK: - Helpers

    private func formatJSONValueShort(_ value: JSONValue?) -> String {
        guard let value else { return "null" }
        switch value {
        case .string(let s): return s.count > 30 ? String(s.prefix(27)) + "…" : s
        case .number(let n): return n == n.rounded() ? String(Int(n)) : String(format: "%.2f", n)
        case .bool(let b): return b ? "true" : "false"
        case .null: return "null"
        case .array(let arr): return "[\(arr.count)]"
        case .object(let obj): return "{\(obj.count)}"
        }
    }

    private func scopePrecedence(_ scope: ResolutionScope) -> Int {
        switch scope {
        case .managed: 0; case .user: 1; case .project: 2
        case .projectLocal: 3; case .session: 4; case .cli: 5
        case .imported: 6; case .autoMemory: 7; case .synthetic: 8
        }
    }

    private struct MarkdownHeading {
        let level: String
        let text: String
    }

    private func extractMarkdownHeadings(_ markdown: String) -> [MarkdownHeading] {
        markdown.components(separatedBy: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("### ") {
                return MarkdownHeading(level: "###", text: String(trimmed.dropFirst(4)))
            } else if trimmed.hasPrefix("## ") {
                return MarkdownHeading(level: "##", text: String(trimmed.dropFirst(3)))
            } else if trimmed.hasPrefix("# ") {
                return MarkdownHeading(level: "#", text: String(trimmed.dropFirst(2)))
            }
            return nil
        }
    }
}

// MARK: - Data models

struct FlowPhase: Identifiable {
    let id: String
    let number: Int
    let title: String
    let subtitle: String
    let summary: String
    let color: Color
    let sourceCards: [FlowSourceCard]
    let mergeInfo: FlowMergeInfo?
    let budgetInfo: FlowBudgetInfo?
}

struct FlowSourceCard: Identifiable {
    let id: String
    let title: String
    let scope: ResolutionScope
    let entries: [FlowSourceEntry]
}

struct FlowSourceEntry: Identifiable {
    let id = UUID()
    let key: String
    let value: String
    let status: EntryStatus

    enum EntryStatus {
        case found
        case absent
        case winner
        case overridden
        case contributor
        case info
    }
}

struct FlowMergeInfo {
    let description: String
    let methods: [String]
    let resolvedChips: [String]
}

struct FlowBudgetInfo {
    let contextWindow: Int
    let segments: [FlowBudgetSegment]
    let usedTokens: Int
    let availableTokens: Int
}

struct FlowBudgetSegment: Identifiable {
    let id = UUID()
    let label: String
    let tokens: Int
    let color: Color
}

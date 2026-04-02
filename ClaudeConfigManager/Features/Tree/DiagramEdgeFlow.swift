import Foundation

// MARK: - Diagram Edge

/// Represents one directed arrow in the pipeline diagram, with metadata for
/// the flow panel and health propagation.
struct DiagramEdge: Identifiable, Sendable {
    let id: String
    let from: PipelineStage
    let to: PipelineStage

    /// Human-readable explanation of what flows along this edge.
    let flowExplanation: String

    /// Title shown in the flow panel.
    var flowTitle: String { "What flows here" }

    init(from: PipelineStage, to: PipelineStage, flowExplanation: String) {
        self.id = "\(from.rawValue)→\(to.rawValue)"
        self.from = from
        self.to = to
        self.flowExplanation = flowExplanation
    }
}

// MARK: - Canonical Edge Definitions

extension DiagramEdge {

    /// All eight directed edges in pipeline order, with their flow explanations.
    static let all: [DiagramEdge] = [
        DiagramEdge(
            from: .discovery,
            to: .parsing,
            flowExplanation: "The raw files found on disk are handed to parsers. Each discovered file is parsed into structured data — settings keys, hook configurations, MCP server definitions, or instruction text."
        ),
        DiagramEdge(
            from: .parsing,
            to: .resolution,
            flowExplanation: "Parsed key-value pairs from every scope's files are collected and passed to the resolver, which determines a single winning value for each key."
        ),
        DiagramEdge(
            from: .resolution,
            to: .promptAssembly,
            flowExplanation: "Resolved settings govern how Claude's system prompt, tools list, and instruction stack are assembled from the CLAUDE.md files found during discovery."
        ),
        DiagramEdge(
            from: .promptAssembly,
            to: .toolExecution,
            flowExplanation: "The assembled prompt determines which tools Claude is given access to. The tool execution gate then applies permission rules to decide which tools Claude may actually use."
        ),
        DiagramEdge(
            from: .toolExecution,
            to: .hooksLifecycle,
            flowExplanation: "When Claude calls a tool, hooks that match that tool invocation are triggered. Hook execution is part of the tool call lifecycle."
        ),
        DiagramEdge(
            from: .hooksLifecycle,
            to: .mcpServers,
            flowExplanation: "Hooks can invoke MCP server tools. The MCP server landscape determines which external tools are available to hooks as well as to Claude directly."
        ),
        DiagramEdge(
            from: .mcpServers,
            to: .contextBudget,
            flowExplanation: "Each active MCP server's tool list contributes to the total tool count and consumes a portion of the available context budget."
        ),
        DiagramEdge(
            from: .contextBudget,
            to: .contextBudget,   // terminal — output edge
            flowExplanation: "The final assembled context — system prompt, instructions, tools, and conversation history — is bounded by the context budget. Anything that would exceed the budget is truncated or summarised."
        ),
    ]

    /// Lookup by source stage.
    static func edge(from stage: PipelineStage) -> DiagramEdge? {
        all.first { $0.from == stage }
    }

    /// Lookup by (from, to) pair.
    static func edge(from: PipelineStage, to: PipelineStage) -> DiagramEdge? {
        all.first { $0.from == from && $0.to == to }
    }

    /// The ordered pipeline sequence used for downstream propagation.
    static let stageOrder: [PipelineStage] = [
        .discovery, .parsing, .resolution, .promptAssembly,
        .toolExecution, .hooksLifecycle, .mcpServers, .contextBudget,
    ]
}

// MARK: - Health Propagation

/// Encapsulates the propagated health warning state for a single edge.
struct EdgeHealthState: Identifiable, Sendable {
    let id: String          // same as DiagramEdge.id
    let edge: DiagramEdge

    /// Issues that propagate through this edge (empty = clean).
    let propagatedIssues: [PropagatedIssue]

    /// The most severe level across all propagated issues, nil if none.
    var worstSeverity: PropagatedIssueSeverity? {
        if propagatedIssues.contains(where: { $0.severity == .error }) { return .error }
        if propagatedIssues.contains(where: { $0.severity == .warning }) { return .warning }
        return nil
    }

    /// True when at least one issue propagates through this edge.
    var hasPropagatedIssue: Bool { !propagatedIssues.isEmpty }
}

/// A single upstream issue that has been propagated downstream.
struct PropagatedIssue: Identifiable, Sendable {
    let id: String
    let sourceStage: PipelineStage
    let title: String
    let severity: PropagatedIssueSeverity

    init(id: String = UUID().uuidString,
         sourceStage: PipelineStage,
         title: String,
         severity: PropagatedIssueSeverity) {
        self.id = id
        self.sourceStage = sourceStage
        self.title = title
        self.severity = severity
    }
}

enum PropagatedIssueSeverity: Sendable {
    case warning
    case error
}

// MARK: - Propagation Engine

/// Computes `EdgeHealthState` for every edge given a stage health map.
enum EdgeHealthPropagator {

    /// Build the full set of edge health states from the current per-stage health values.
    ///
    /// Propagation rule: an issue at stage S propagates along all arrows whose source is S
    /// or whose source is downstream of S.
    static func compute(
        stageHealthMap: [PipelineStage: StageHealth]
    ) -> [String: EdgeHealthState] {
        // For each stage, collect issues it introduces.
        var issuesByStage = [PipelineStage: [PropagatedIssue]]()
        for stage in DiagramEdge.stageOrder {
            let health = stageHealthMap[stage] ?? .noData
            issuesByStage[stage] = propagatedIssues(for: stage, health: health)
        }

        // For each non-terminal edge (from → to where from != to), accumulate issues
        // from the source stage and all stages upstream of it in the pipeline.
        var result = [String: EdgeHealthState]()

        let nonTerminalEdges = DiagramEdge.all.filter { $0.from != $0.to }
        for edge in nonTerminalEdges {
            // Collect issues from the source stage and every stage upstream of it.
            let sourceIdx = DiagramEdge.stageOrder.firstIndex(of: edge.from) ?? 0
            var issues = [PropagatedIssue]()
            for idx in 0...sourceIdx {
                let stage = DiagramEdge.stageOrder[idx]
                issues.append(contentsOf: issuesByStage[stage] ?? [])
            }

            result[edge.id] = EdgeHealthState(id: edge.id, edge: edge, propagatedIssues: issues)
        }

        return result
    }

    // MARK: - Private

    private static func propagatedIssues(
        for stage: PipelineStage,
        health: StageHealth
    ) -> [PropagatedIssue] {
        switch health {
        case .errors(let count):
            return (0..<count).map { i in
                PropagatedIssue(
                    sourceStage: stage,
                    title: "\(stage.title) error \(i + 1)",
                    severity: .error
                )
            }
        case .warnings(let count):
            return (0..<count).map { i in
                PropagatedIssue(
                    sourceStage: stage,
                    title: "\(stage.title) warning \(i + 1)",
                    severity: .warning
                )
            }
        case .healthy, .noData:
            return []
        }
    }
}

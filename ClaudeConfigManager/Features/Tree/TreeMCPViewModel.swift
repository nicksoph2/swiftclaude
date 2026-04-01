import Foundation
import SwiftUI
import Combine

// MARK: - View Model

/// Transforms `SessionProjection.mcp` (`ResolvedMcpSnapshot`) into a tool landscape
/// tree visualization for Stage 7 — MCP Servers.
///
/// Builds a `[ToolLandscapeNode]` tree with two root nodes:
/// 1. Built-in tools (from `BuiltInToolCatalog`)
/// 2. MCP servers (from `ResolvedMcpSnapshot.servers`)
///
/// Detects override relationships when the same serverID appears at multiple scopes,
/// groups blocked vs. active servers, and computes aggregate stage health.
@MainActor
final class TreeMCPViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var landscapeNodes: [ToolLandscapeNode] = []
    @Published private(set) var activeServers: [MCPServerDisplayModel] = []
    @Published private(set) var blockedServers: [MCPServerDisplayModel] = []
    @Published private(set) var globalPolicyEffects: [McpPolicyEffect] = []
    @Published private(set) var stageHealth: StageHealth = .noData

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private weak var pipeline: ConfigurationPipeline?

    // MARK: - Binding

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
        guard let mcp = pipeline?.projection?.mcp else {
            landscapeNodes = []
            activeServers = []
            blockedServers = []
            globalPolicyEffects = []
            stageHealth = .noData
            return
        }

        globalPolicyEffects = mcp.policyEffects

        let displayModels = mcp.servers.map { buildDisplayModel(from: $0, allServers: mcp.servers) }

        activeServers = displayModels.filter { !$0.isBlocked }
        blockedServers = displayModels.filter { $0.isBlocked }
        landscapeNodes = buildLandscapeTree(from: displayModels)
        stageHealth = computeHealth(from: mcp)
    }

    // MARK: - Display Model Building

    private func buildDisplayModel(
        from entry: ResolvedMcpServerEntry,
        allServers: [ResolvedMcpServerEntry]
    ) -> MCPServerDisplayModel {
        let transport = extractTransportType(from: entry)
        let transportDetail = extractTransportDetail(from: entry)
        let sourceScope = entry.resolvedConfig.winningSource?.scope
        let sourcePath = entry.resolvedConfig.winningSource?.sourcePath
        let overrides = detectOverrides(for: entry)

        let isBlocked: Bool
        switch entry.effectiveState {
        case .blocked, .disabled:
            isBlocked = true
        case .active, .managed, .unresolved:
            isBlocked = false
        }

        let policyExplanation: String?
        if entry.policyEffects.isEmpty {
            policyExplanation = entry.stateExplanation.isEmpty ? nil : entry.stateExplanation
        } else {
            policyExplanation = entry.policyEffects.map(\.message).joined(separator: "; ")
        }

        return MCPServerDisplayModel(
            serverID: entry.serverID,
            transportType: transport,
            transportDetail: transportDetail,
            sourceScope: sourceScope,
            sourcePath: sourcePath,
            effectiveState: entry.effectiveState,
            isBlocked: isBlocked,
            policyExplanation: policyExplanation,
            overrides: overrides,
            environmentNotes: entry.environmentNotes
        )
    }

    private func extractTransportType(from entry: ResolvedMcpServerEntry) -> MCPTransportType {
        guard let config = entry.resolvedConfig.effectiveValue else { return .unknown }
        if case .object(let dict) = config {
            if dict["command"] != nil { return .stdio }
            if dict["url"] != nil { return .http }
            if case .string(let typeStr) = dict["type"] {
                if typeStr == "stdio" { return .stdio }
                if typeStr == "http" || typeStr == "sse" || typeStr == "streamable-http" { return .http }
            }
        }
        return .unknown
    }

    private func extractTransportDetail(from entry: ResolvedMcpServerEntry) -> String? {
        guard let config = entry.resolvedConfig.effectiveValue,
              case .object(let dict) = config else { return nil }

        if case .string(let command) = dict["command"] {
            var detail = command
            if case .array(let args) = dict["args"] {
                let argStrings = args.compactMap { arg -> String? in
                    if case .string(let s) = arg { return s }
                    return nil
                }
                if !argStrings.isEmpty {
                    detail += " " + argStrings.joined(separator: " ")
                }
            }
            return detail
        }

        if case .string(let url) = dict["url"] {
            return url
        }

        return nil
    }

    private func detectOverrides(for entry: ResolvedMcpServerEntry) -> [MCPOverrideRelationship] {
        let trace = entry.resolvedConfig.trace
        let winningScope = entry.resolvedConfig.winningSource?.scope
        var overrides: [MCPOverrideRelationship] = []
        for participant in trace.participants {
            if participant.scope != winningScope {
                overrides.append(MCPOverrideRelationship(
                    overriddenScope: participant.scope,
                    overriddenPath: participant.sourcePath
                ))
            }
        }
        return overrides
    }

    // MARK: - Landscape Tree Building

    private func buildLandscapeTree(from servers: [MCPServerDisplayModel]) -> [ToolLandscapeNode] {
        var nodes: [ToolLandscapeNode] = []

        let builtInChildren = BuiltInToolCatalog.tools.map { tool in
            ToolLandscapeNode(nodeType: .tool, label: tool.name, detail: tool.description)
        }
        nodes.append(ToolLandscapeNode(
            nodeType: .builtInGroup,
            label: "Built-in Tools",
            status: "\(BuiltInToolCatalog.tools.count) tools",
            children: builtInChildren,
            detail: "Tools available in every Claude Code session"
        ))

        let serverChildren = servers.map { server -> ToolLandscapeNode in
            let statusStr: String
            switch server.effectiveState {
            case .active: statusStr = "Active"
            case .blocked: statusStr = "Blocked"
            case .disabled: statusStr = "Disabled"
            case .managed: statusStr = "Managed"
            case .unresolved: statusStr = "Unresolved"
            }
            return ToolLandscapeNode(
                nodeType: .mcpServer,
                label: server.serverID,
                scope: server.sourceScope,
                status: statusStr,
                detail: server.transportDetail
            )
        }

        let activeCount = servers.filter { !$0.isBlocked }.count
        let blockedCount = servers.filter { $0.isBlocked }.count
        var parts: [String] = []
        if activeCount > 0 { parts.append("\(activeCount) active") }
        if blockedCount > 0 { parts.append("\(blockedCount) blocked") }
        let summary = parts.isEmpty ? "No servers" : parts.joined(separator: ", ")

        nodes.append(ToolLandscapeNode(
            nodeType: .builtInGroup,
            label: "MCP Servers",
            status: summary,
            children: serverChildren,
            detail: "Model Context Protocol servers providing additional tools"
        ))

        return nodes
    }

    // MARK: - Health

    private func computeHealth(from mcp: ResolvedMcpSnapshot) -> StageHealth {
        let blockedCount = mcp.servers.filter {
            $0.effectiveState == .blocked || $0.effectiveState == .disabled
        }.count

        var errorCount = 0
        var warningCount = 0
        for issue in mcp.issues {
            switch issue.severity {
            case .error: errorCount += 1
            case .warning: warningCount += 1
            case .info: break
            }
        }
        warningCount += blockedCount

        if errorCount > 0 { return .errors(errorCount) }
        if warningCount > 0 { return .warnings(warningCount) }
        return .healthy
    }
}

// MARK: - Supporting Display Models

struct MCPServerDisplayModel: Identifiable {
    let id: String
    let serverID: String
    let transportType: MCPTransportType
    let transportDetail: String?
    let sourceScope: ResolutionScope?
    let sourcePath: String?
    let effectiveState: McpServerEffectiveState
    let isBlocked: Bool
    let policyExplanation: String?
    let overrides: [MCPOverrideRelationship]
    let environmentNotes: [McpEnvironmentNote]

    init(
        serverID: String,
        transportType: MCPTransportType,
        transportDetail: String? = nil,
        sourceScope: ResolutionScope? = nil,
        sourcePath: String? = nil,
        effectiveState: McpServerEffectiveState = .active,
        isBlocked: Bool = false,
        policyExplanation: String? = nil,
        overrides: [MCPOverrideRelationship] = [],
        environmentNotes: [McpEnvironmentNote] = []
    ) {
        self.id = serverID
        self.serverID = serverID
        self.transportType = transportType
        self.transportDetail = transportDetail
        self.sourceScope = sourceScope
        self.sourcePath = sourcePath
        self.effectiveState = effectiveState
        self.isBlocked = isBlocked
        self.policyExplanation = policyExplanation
        self.overrides = overrides
        self.environmentNotes = environmentNotes
    }
}

enum MCPTransportType: String {
    case stdio
    case http
    case unknown
}

struct MCPOverrideRelationship {
    let overriddenScope: ResolutionScope
    let overriddenPath: String?
}

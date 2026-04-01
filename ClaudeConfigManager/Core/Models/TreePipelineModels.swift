import Foundation

// MARK: - Pipeline Stage

/// Represents the 8 stages of the Claude Code configuration pipeline.
enum PipelineStage: String, CaseIterable, Identifiable, Hashable, Sendable {
    case discovery
    case parsing
    case resolution
    case promptAssembly
    case toolExecution
    case hooksLifecycle
    case mcpServers
    case contextBudget

    var id: String { rawValue }

    var title: String {
        switch self {
        case .discovery: "Discovery"
        case .parsing: "Parsing"
        case .resolution: "Resolution"
        case .promptAssembly: "Prompt Assembly"
        case .toolExecution: "Tool Execution"
        case .hooksLifecycle: "Hooks Lifecycle"
        case .mcpServers: "MCP Servers"
        case .contextBudget: "Context Budget"
        }
    }

    var icon: String {
        switch self {
        case .discovery: "magnifyingglass"
        case .parsing: "doc.text.magnifyingglass"
        case .resolution: "arrow.triangle.merge"
        case .promptAssembly: "square.stack.3d.up"
        case .toolExecution: "hammer"
        case .hooksLifecycle: "arrow.triangle.capsulepath"
        case .mcpServers: "server.rack"
        case .contextBudget: "chart.bar"
        }
    }

    var sortOrder: Int {
        switch self {
        case .discovery: 0
        case .parsing: 1
        case .resolution: 2
        case .promptAssembly: 3
        case .toolExecution: 4
        case .hooksLifecycle: 5
        case .mcpServers: 6
        case .contextBudget: 7
        }
    }
}

// MARK: - Stage Health

/// Summarizes the health status of a pipeline stage.
enum StageHealth: Equatable, Sendable {
    case healthy
    case warnings(Int)
    case errors(Int)
    case noData
}

// MARK: - Discovery Tree Node

/// A node in the discovery file tree, representing a scope group or individual config file.
struct DiscoveryTreeNode: Identifiable, Sendable {
    let id: String
    let label: String
    let path: String?
    let scope: ResolutionScope?
    let status: DiscoveredFileStatus?
    let children: [DiscoveryTreeNode]
    let fileReference: URL?

    init(
        id: String = UUID().uuidString,
        label: String,
        path: String? = nil,
        scope: ResolutionScope? = nil,
        status: DiscoveredFileStatus? = nil,
        children: [DiscoveryTreeNode] = [],
        fileReference: URL? = nil
    ) {
        self.id = id
        self.label = label
        self.path = path
        self.scope = scope
        self.status = status
        self.children = children
        self.fileReference = fileReference
    }
}

/// Status of a discovered configuration file on disk.
enum DiscoveredFileStatus: String, Sendable {
    case present
    case notFound
    case unreadable
    case inaccessible
}

// MARK: - Waterfall Node

/// A single tier in the resolution waterfall visualization.
struct WaterfallNode: Identifiable, Sendable {
    let id: String
    let scope: ResolutionScope
    let scopeLabel: String
    let value: String?
    let status: WaterfallNodeStatus
    let sourcePath: String?

    init(
        id: String = UUID().uuidString,
        scope: ResolutionScope,
        scopeLabel: String,
        value: String? = nil,
        status: WaterfallNodeStatus,
        sourcePath: String? = nil
    ) {
        self.id = id
        self.scope = scope
        self.scopeLabel = scopeLabel
        self.value = value
        self.status = status
        self.sourcePath = sourcePath
    }
}

/// Status of a scope tier in the resolution waterfall.
enum WaterfallNodeStatus: String, Sendable {
    case winner
    case overridden
    case contributor
    case absent
}

// MARK: - Execution Gate

/// A gate in the tool execution flowchart.
struct ExecutionGate: Identifiable, Sendable {
    let id: String
    let gateType: ExecutionGateType
    let items: [ExecutionGateItem]
    let status: GateStatus

    init(
        id: String = UUID().uuidString,
        gateType: ExecutionGateType,
        items: [ExecutionGateItem] = [],
        status: GateStatus = .empty
    ) {
        self.id = id
        self.gateType = gateType
        self.items = items
        self.status = status
    }
}

/// The type of execution gate in the tool permission flowchart.
enum ExecutionGateType: String, CaseIterable, Sendable {
    case preHook
    case permissions
    case execution
    case postHook
}

/// An individual item within an execution gate.
struct ExecutionGateItem: Identifiable, Sendable {
    let id: String
    let label: String
    let detail: String?
    let sourceScope: ResolutionScope?
    let sourcePath: String?

    init(
        id: String = UUID().uuidString,
        label: String,
        detail: String? = nil,
        sourceScope: ResolutionScope? = nil,
        sourcePath: String? = nil
    ) {
        self.id = id
        self.label = label
        self.detail = detail
        self.sourceScope = sourceScope
        self.sourcePath = sourcePath
    }
}

/// Status of an execution gate.
enum GateStatus: Sendable, Equatable {
    case active
    case empty
    case suppressed(reason: String)
}

// MARK: - Permission Rule Display

/// A permission rule for display in the tool execution flowchart.
struct PermissionRuleDisplay: Identifiable, Sendable {
    let id: String
    let ruleType: PermissionRuleType
    let pattern: String
    let sourceScope: ResolutionScope
    let sourcePath: String?

    init(
        id: String = UUID().uuidString,
        ruleType: PermissionRuleType,
        pattern: String,
        sourceScope: ResolutionScope,
        sourcePath: String? = nil
    ) {
        self.id = id
        self.ruleType = ruleType
        self.pattern = pattern
        self.sourceScope = sourceScope
        self.sourcePath = sourcePath
    }
}

/// Permission rule type in the deny/ask/allow hierarchy.
enum PermissionRuleType: String, CaseIterable, Sendable {
    case deny
    case ask
    case allow
}

// MARK: - Lifecycle Event Node

/// A node in the hooks lifecycle timeline.
struct LifecycleEventNode: Identifiable, Sendable {
    let id: String
    let eventType: String
    let displayName: String
    let handlers: [ResolvedHookHandler]
    let isSuppressed: Bool
    let suppressionReason: String?

    init(
        id: String = UUID().uuidString,
        eventType: String,
        displayName: String,
        handlers: [ResolvedHookHandler] = [],
        isSuppressed: Bool = false,
        suppressionReason: String? = nil
    ) {
        self.id = id
        self.eventType = eventType
        self.displayName = displayName
        self.handlers = handlers
        self.isSuppressed = isSuppressed
        self.suppressionReason = suppressionReason
    }
}

// NOTE: ResolvedHookHandler is defined in Infrastructure/Resolver/ResolverModels.swift
// NOTE: HookHandlerType is defined in Infrastructure/Parsers/SettingsParser.swift

// MARK: - Tool Landscape Node

/// A node in the MCP / tool landscape tree.
struct ToolLandscapeNode: Identifiable, Sendable {
    let id: String
    let nodeType: ToolLandscapeNodeType
    let label: String
    let scope: ResolutionScope?
    let status: String?
    let children: [ToolLandscapeNode]
    let detail: String?

    init(
        id: String = UUID().uuidString,
        nodeType: ToolLandscapeNodeType,
        label: String,
        scope: ResolutionScope? = nil,
        status: String? = nil,
        children: [ToolLandscapeNode] = [],
        detail: String? = nil
    ) {
        self.id = id
        self.nodeType = nodeType
        self.label = label
        self.scope = scope
        self.status = status
        self.children = children
        self.detail = detail
    }
}

/// The type of node in the tool landscape tree.
enum ToolLandscapeNodeType: String, Sendable {
    case builtInGroup
    case mcpServer
    case tool
}

// MARK: - Context Budget Segment

/// A segment in the context budget bar visualization.
struct ContextBudgetSegment: Identifiable, Sendable {
    let id: String
    let layer: String
    let estimatedTokens: Int
    let color: String
    let isConfigurable: Bool

    init(
        id: String = UUID().uuidString,
        layer: String,
        estimatedTokens: Int,
        color: String,
        isConfigurable: Bool = false
    ) {
        self.id = id
        self.layer = layer
        self.estimatedTokens = estimatedTokens
        self.color = color
        self.isConfigurable = isConfigurable
    }
}

// MARK: - Prompt Layer

/// A layer in the prompt assembly "layer cake" visualization.
struct PromptLayer: Identifiable, Sendable {
    let id: String
    let name: String
    let description: String
    let estimatedTokens: Int?
    let isConfigurable: Bool
    let isPresent: Bool
    let children: [PromptLayer]
    let expandedContent: String?

    init(
        id: String = UUID().uuidString,
        name: String,
        description: String = "",
        estimatedTokens: Int? = nil,
        isConfigurable: Bool = false,
        isPresent: Bool = true,
        children: [PromptLayer] = [],
        expandedContent: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.estimatedTokens = estimatedTokens
        self.isConfigurable = isConfigurable
        self.isPresent = isPresent
        self.children = children
        self.expandedContent = expandedContent
    }
}

// MARK: - Tree Navigation Target

/// Cross-stage navigation target used to coordinate scrolling between stages.
///
/// When a user taps a navigable element in one stage (e.g., a file in Discovery),
/// the parent `TreePipelineView` updates `selectedStage` and uses `ScrollViewReader`
/// to scroll to the target's anchor ID.
enum TreeNavigationTarget: Equatable, Hashable {
    /// Navigate to a file in the Discovery stage.
    case discoveryFile(URL)
    /// Navigate to a parsed file card in the Parsing stage.
    case parsingFile(URL)
    /// Navigate to a specific key within a parsed file card.
    case parsingKey(fileURL: URL, keyPath: String)
    /// Navigate to a resolved key in the Resolution stage.
    case resolutionKey(String)
    /// Navigate to a permission rule in the Resolution stage.
    case resolutionPermission(String)
    /// Navigate to an execution gate in Tool Execution.
    case toolExecutionGate(ExecutionGateType)
    /// Navigate to a hooks lifecycle event.
    case hooksEvent(String)
    /// Navigate to an MCP server policy in Resolution.
    case mcpServerPolicy(String)
    /// Navigate to a prompt layer in Prompt Assembly.
    case promptLayer(String)
    /// Navigate to a context budget segment.
    case contextBudgetSegment(String)

    /// The pipeline stage this target lives in.
    var targetStage: PipelineStage {
        switch self {
        case .discoveryFile: return .discovery
        case .parsingFile, .parsingKey: return .parsing
        case .resolutionKey, .resolutionPermission: return .resolution
        case .toolExecutionGate: return .toolExecution
        case .hooksEvent: return .hooksLifecycle
        case .mcpServerPolicy: return .mcpServers
        case .promptLayer: return .promptAssembly
        case .contextBudgetSegment: return .contextBudget
        }
    }

    /// The scroll anchor ID for this target.
    var anchorID: String {
        switch self {
        case .discoveryFile(let url):
            return "discovery-\(url.absoluteString)"
        case .parsingFile(let url):
            return "parsing-file-\(url.absoluteString)"
        case .parsingKey(let url, let keyPath):
            return "parsing-key-\(url.absoluteString)-\(keyPath)"
        case .resolutionKey(let key):
            return "resolution-\(key)"
        case .resolutionPermission(let key):
            return "resolution-perm-\(key)"
        case .toolExecutionGate(let gate):
            return "gate-\(gate.rawValue)"
        case .hooksEvent(let event):
            return "hooks-\(event)"
        case .mcpServerPolicy(let server):
            return "mcp-policy-\(server)"
        case .promptLayer(let layer):
            return "prompt-\(layer)"
        case .contextBudgetSegment(let segment):
            return "budget-\(segment)"
        }
    }
}

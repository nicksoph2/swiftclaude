import Foundation
import Combine

// MARK: - Search Result Types

/// The category of a global search result.
enum SearchResultKind: String, Equatable, Sendable {
    case setting
    case file
    case mcp
    case hook

    var badge: String {
        switch self {
        case .setting: "Setting"
        case .file:    "File"
        case .mcp:     "MCP"
        case .hook:    "Hook"
        }
    }
}

/// A single result row returned by global search.
struct GlobalSearchResult: Identifiable, Equatable {
    let id: String
    let kind: SearchResultKind
    let title: String
    let detail: String
    let stage: PipelineStage
    let navigationTarget: TreeNavigationTarget?

    static func == (lhs: GlobalSearchResult, rhs: GlobalSearchResult) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - View Model

/// Drives the global search overlay. Searches across resolved settings, discovered files,
/// MCP servers, and hook event types.
@MainActor
final class GlobalSearchViewModel: ObservableObject {

    @Published var query: String = ""
    @Published private(set) var results: [GlobalSearchResult] = []
    @Published var isPresented: Bool = false

    private var debounceCancellable: AnyCancellable?

    /// The pipeline providing data to search across.
    weak var pipeline: ConfigurationPipeline?

    static let suggestedSearches = ["model", "permissions.deny", "mcp", "hooks", "sandbox"]

    init() {
        debounceCancellable = $query
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] newQuery in
                self?.performSearch(newQuery)
            }
    }

    func open() {
        isPresented = true
        query = ""
        results = []
    }

    func dismiss() {
        isPresented = false
        query = ""
        results = []
    }

    // MARK: - Search Logic

    func performSearch(_ query: String) {
        guard !query.isEmpty else {
            results = []
            return
        }

        let lowered = query.lowercased()
        var found: [GlobalSearchResult] = []

        // Search settings
        found.append(contentsOf: searchSettings(lowered))

        // Search files
        found.append(contentsOf: searchFiles(lowered))

        // Search MCP servers
        found.append(contentsOf: searchMcpServers(lowered))

        // Search hooks
        found.append(contentsOf: searchHooks(lowered))

        results = found
    }

    // MARK: - Settings Search

    private func searchSettings(_ query: String) -> [GlobalSearchResult] {
        guard let settings = pipeline?.projection?.settings else { return [] }

        return settings.entries.compactMap { entry in
            let keyMatch = entry.keyPath.lowercased().contains(query)
            let valueString = describeValue(entry.value.effectiveValue)
            let valueMatch = valueString.lowercased().contains(query)

            guard keyMatch || valueMatch else { return nil }

            return GlobalSearchResult(
                id: "setting-\(entry.keyPath)",
                kind: .setting,
                title: entry.keyPath,
                detail: valueString,
                stage: .resolution,
                navigationTarget: .resolutionKey(entry.keyPath)
            )
        }
    }

    // MARK: - File Search

    private func searchFiles(_ query: String) -> [GlobalSearchResult] {
        guard let scanResult = pipeline?.scanResult else { return [] }

        var results: [GlobalSearchResult] = []

        let allWorkspaces = [scanResult.managedWorkspace, scanResult.userWorkspace].compactMap { $0 }
            + scanResult.projectWorkspaces

        for workspace in allWorkspaces {
            for file in workspace.files {
                let filePath = file.url.path
                let fileName = file.url.lastPathComponent

                guard fileName.lowercased().contains(query) || filePath.lowercased().contains(query) else {
                    continue
                }

                results.append(GlobalSearchResult(
                    id: "file-\(file.id.rawValue)",
                    kind: .file,
                    title: fileName,
                    detail: filePath,
                    stage: .discovery,
                    navigationTarget: .discoveryFile(file.url)
                ))
            }
        }

        return results
    }

    // MARK: - MCP Search

    private func searchMcpServers(_ query: String) -> [GlobalSearchResult] {
        guard let mcp = pipeline?.projection?.mcp else { return [] }

        return mcp.servers.compactMap { server in
            guard server.serverID.lowercased().contains(query) else { return nil }

            return GlobalSearchResult(
                id: "mcp-\(server.serverID)",
                kind: .mcp,
                title: server.serverID,
                detail: server.effectiveState.rawValue,
                stage: .mcpServers,
                navigationTarget: .mcpServerPolicy(server.serverID)
            )
        }
    }

    // MARK: - Hooks Search

    private func searchHooks(_ query: String) -> [GlobalSearchResult] {
        guard let hooks = pipeline?.projection?.hooks else { return [] }

        return hooks.events.compactMap { event in
            let eventName = event.eventType.canonicalName
            guard eventName.lowercased().contains(query) else { return nil }

            let handlerCount = event.resolvedHandlers.count
            let detail = handlerCount == 1 ? "1 handler" : "\(handlerCount) handlers"

            return GlobalSearchResult(
                id: "hook-\(event.eventID)",
                kind: .hook,
                title: eventName,
                detail: detail,
                stage: .hooksLifecycle,
                navigationTarget: .hooksEvent(eventName)
            )
        }
    }

    // MARK: - Helpers

    private func describeValue(_ value: JSONValue?) -> String {
        guard let value else { return "nil" }
        switch value {
        case .null:
            return "null"
        case .bool(let b):
            return b ? "true" : "false"
        case .number(let n):
            return String(n)
        case .string(let s):
            return s
        case .array(let arr):
            return "[\(arr.count) items]"
        case .object(let obj):
            return "{\(obj.count) keys}"
        }
    }
}

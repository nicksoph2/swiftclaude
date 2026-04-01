import Foundation
import SwiftUI
import Combine

/// View model for Stage 1 — Discovery.
///
/// Transforms `ScanResult` and `[ParseResultRecord]` from the pipeline into
/// a tree of `DiscoveryTreeNode` items suitable for rendering by `TreeDiscoveryView`.
@MainActor
final class TreeDiscoveryViewModel: ObservableObject {

    // MARK: - Published State

    /// Root-level nodes of the discovery tree, grouped by scope.
    @Published private(set) var rootNodes: [DiscoveryTreeNode] = []

    /// Indicates which managed tier is active (if any), used for the "first active tier wins" gate.
    @Published private(set) var activeManagedTier: ManagedTierStatus = .none

    /// Stage health summary for the overview strip badge.
    @Published private(set) var stageHealth: StageHealth = .noData

    // MARK: - Internal Types

    /// Describes which managed tier is active, so the view can dim suppressed tiers.
    enum ManagedTierStatus: Equatable {
        case none
        case serverManaged
        case mdm
        case fileBased
    }

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private weak var pipeline: ConfigurationPipeline?

    // MARK: - Binding

    /// Binds to the pipeline and recomputes the tree whenever scan results change.
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

    // MARK: - Public Helpers

    /// Returns the `ParseResultRecord` for a given file URL, if one was parsed.
    func parseRecord(for fileURL: URL) -> ParseResultRecord? {
        pipeline?.parseResults.first(where: { $0.sourceFile == fileURL })
    }

    // MARK: - Tree Construction

    private func rebuild() {
        guard let scan = pipeline?.scanResult else {
            rootNodes = []
            activeManagedTier = .none
            stageHealth = .noData
            return
        }

        var nodes: [DiscoveryTreeNode] = []

        // 1. Managed Tier
        if let managed = scan.managedWorkspace {
            let managedNode = buildManagedNode(from: managed)
            nodes.append(managedNode)
            activeManagedTier = determineManagedTier(from: managed)
        } else {
            activeManagedTier = .none
        }

        // 2. User Scope
        if let user = scan.userWorkspace {
            let userNode = buildWorkspaceNode(
                label: "User Scope",
                scope: .user,
                workspace: user
            )
            nodes.append(userNode)
        }

        // 3. Project Scopes
        for project in scan.projectWorkspaces {
            let projectLabel = project.scope.project?.normalizedProjectRootPath ?? "Project"
            let projectNode = buildWorkspaceNode(
                label: "Project: \(projectLabel)",
                scope: .project,
                workspace: project
            )
            nodes.append(projectNode)
        }

        rootNodes = nodes
        stageHealth = computeHealth(from: scan)
    }

    // MARK: - Managed Tier

    /// Builds the managed workspace node with sub-tier grouping.
    private func buildManagedNode(from workspace: DiscoveredWorkspace) -> DiscoveryTreeNode {
        // Group managed files into sub-tiers by file kind
        let serverFiles: [DiscoveryTreeNode] = []
        var mdmFiles: [DiscoveryTreeNode] = []
        var fileBasedFiles: [DiscoveryTreeNode] = []

        for file in workspace.files {
            let leaf = fileLeafNode(from: file, scope: .managed)
            // Categorize by file kind naming convention
            switch file.kind {
            case .managedSettingsJSON:
                // The primary managed settings file could be any tier;
                // treat as file-based unless we have more specific info
                fileBasedFiles.append(leaf)
            case .managedSettingsDropIn:
                // Drop-in files are MDM-style
                mdmFiles.append(leaf)
            case .managedMcpJSON:
                fileBasedFiles.append(leaf)
            case .managedClaudeMarkdown:
                fileBasedFiles.append(leaf)
            default:
                fileBasedFiles.append(leaf)
            }
        }

        var subTiers: [DiscoveryTreeNode] = []

        if !serverFiles.isEmpty {
            subTiers.append(DiscoveryTreeNode(
                id: "managed-server",
                label: "Server-Managed",
                scope: .managed,
                children: serverFiles
            ))
        }

        if !mdmFiles.isEmpty {
            subTiers.append(DiscoveryTreeNode(
                id: "managed-mdm",
                label: "MDM",
                scope: .managed,
                children: mdmFiles
            ))
        }

        if !fileBasedFiles.isEmpty {
            subTiers.append(DiscoveryTreeNode(
                id: "managed-filebased",
                label: "File-Based",
                scope: .managed,
                children: fileBasedFiles
            ))
        }

        // If no sub-tier grouping makes sense, just show files flat
        let children = subTiers.isEmpty ? [] : subTiers

        return DiscoveryTreeNode(
            id: "managed-tier",
            label: "Managed Tier",
            path: workspace.rootNormalizedPath,
            scope: .managed,
            children: children
        )
    }

    /// Determines which managed tier is "active" (first tier with present files wins).
    private func determineManagedTier(from workspace: DiscoveredWorkspace) -> ManagedTierStatus {
        // Check for any present files — in practice, the managed workspace existing
        // means file-based management is active
        let hasPresentFiles = workspace.files.contains { $0.status == .present }
        if hasPresentFiles {
            // Check if any drop-in (MDM) files are present
            let hasMDM = workspace.files.contains {
                $0.kind == .managedSettingsDropIn && $0.status == .present
            }
            if hasMDM { return .mdm }
            return .fileBased
        }
        return .none
    }

    // MARK: - Generic Workspace

    /// Builds a node for a user or project workspace.
    private func buildWorkspaceNode(
        label: String,
        scope: ResolutionScope,
        workspace: DiscoveredWorkspace
    ) -> DiscoveryTreeNode {
        let fileNodes = workspace.files.map { fileLeafNode(from: $0, scope: scope) }
        let dirNodes = workspace.directories.map { directoryNode(from: $0, scope: scope) }

        return DiscoveryTreeNode(
            id: "workspace-\(scope.rawValue)-\(workspace.rootNormalizedPath)",
            label: label,
            path: workspace.rootNormalizedPath,
            scope: scope,
            children: fileNodes + dirNodes
        )
    }

    // MARK: - Leaf Nodes

    /// Creates a leaf node for a discovered file.
    private func fileLeafNode(from file: DiscoveredFile, scope: ResolutionScope) -> DiscoveryTreeNode {
        DiscoveryTreeNode(
            id: file.id.rawValue,
            label: file.displayPath,
            path: file.normalizedPath,
            scope: scope,
            status: mapPathStatus(file.status),
            fileReference: file.url
        )
    }

    /// Creates a node for a discovered directory.
    private func directoryNode(from dir: DiscoveredDirectory, scope: ResolutionScope) -> DiscoveryTreeNode {
        DiscoveryTreeNode(
            id: dir.id.rawValue,
            label: dir.displayPath,
            path: dir.normalizedPath,
            scope: scope,
            status: mapPathStatus(dir.status)
        )
    }

    /// Maps `DiscoveryPathStatus` to the simpler `DiscoveredFileStatus` used in tree nodes.
    private func mapPathStatus(_ status: DiscoveryPathStatus) -> DiscoveredFileStatus {
        switch status {
        case .present: .present
        case .missing: .notFound
        case .unreadable: .unreadable
        case .inaccessible: .inaccessible
        case .unsupported: .unreadable
        }
    }

    // MARK: - Health

    private func computeHealth(from scan: ScanResult) -> StageHealth {
        var errorCount = 0

        let allWorkspaces = [scan.managedWorkspace, scan.userWorkspace].compactMap { $0 }
            + scan.projectWorkspaces

        for workspace in allWorkspaces {
            for file in workspace.files {
                switch file.status {
                case .unreadable, .inaccessible, .unsupported:
                    errorCount += 1
                case .missing, .present:
                    break
                }
            }
        }

        errorCount += scan.issues.count

        if errorCount > 0 { return .errors(errorCount) }

        let hasFiles = allWorkspaces.contains { !$0.files.isEmpty }
        return hasFiles ? .healthy : .noData
    }
}

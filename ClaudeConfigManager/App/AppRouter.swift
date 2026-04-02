import Foundation
import CryptoKit
import os
import SwiftUI

@MainActor
final class AppRouter: ObservableObject {
    @Published private(set) var bootstrapState: AppBootstrapState
    @Published private(set) var bookmarkResolutionResults: [BookmarkResolutionResult]
    @Published private(set) var bookmarkBootstrapSummary: BookmarkBootstrapSummary
    @Published private(set) var rootSelectionViewModel: RootSelectionViewModel
    @Published private(set) var pipeline: ConfigurationPipeline

    @Published var sidebarState: SidebarState

    /// Shared transcript scanner for the analytics dashboard sidebar destination.
    lazy var transcriptScannerForAnalytics: TranscriptScanner = TranscriptScanner()

    /// Shared usage aggregator for the analytics dashboard sidebar destination.
    lazy var usageAggregatorForAnalytics: UsageAggregator = UsageAggregator(
        transcriptScanner: transcriptScannerForAnalytics,
        runtimeDiscovery: RuntimeSessionDiscovery()
    )

    private let bookmarkStore: BookmarkStore?
    private let logger = Logger(subsystem: "com.nicholassophocleous.ClaudeConfigManager", category: "Bootstrap")
    private var pipelineObservationTask: Task<Void, Never>?

    init(
        bootstrapState: AppBootstrapState = .launching,
        sidebarState: SidebarState,
        bookmarkStore: BookmarkStore? = nil,
        globalStateStore: GlobalStateStore = GlobalStateStore(persistence: InMemoryGlobalStatePersistence()),
        rootSelectionViewModel: RootSelectionViewModel? = nil,
        bookmarkResolutionResults: [BookmarkResolutionResult] = [],
        bookmarkBootstrapSummary: BookmarkBootstrapSummary = .empty,
        pipeline: ConfigurationPipeline? = nil
    ) {
        self.bootstrapState = bootstrapState
        self.sidebarState = sidebarState
        self.bookmarkStore = bookmarkStore
        self.bookmarkResolutionResults = bookmarkResolutionResults
        self.bookmarkBootstrapSummary = bookmarkBootstrapSummary
        self.pipeline = pipeline ?? ConfigurationPipeline()

        if let rootSelectionViewModel {
            self.rootSelectionViewModel = rootSelectionViewModel
        } else {
            let projectRegistry = ProjectRegistry(
                bookmarkStore: bookmarkStore,
                globalStateStore: globalStateStore
            )
            self.rootSelectionViewModel = RootSelectionViewModel(
                bookmarkStore: bookmarkStore,
                projectRegistry: projectRegistry,
                folderSelector: NoopFolderSelector()
            )
        }

        // Set up pipeline observation for root changes
        setupPipelineWiring()
    }

    private func setupPipelineWiring() {
        // Observe root selection changes and trigger pipeline
        pipelineObservationTask = Task {
            // Trigger initial pipeline run if bootstrap completes
            if bootstrapState == .ready {
                await triggerPipeline()
            }
        }
    }

    private func triggerPipeline() async {
        let globalRoot = rootSelectionViewModel.selectedGlobalRootURL
        let projectRoots = rootSelectionViewModel.projectRegistrations
            .filter { $0.id == rootSelectionViewModel.selectedProjectRegistrationID }
            .map { URL(fileURLWithPath: $0.preferredPath, isDirectory: true) }
        await pipeline.run(globalRootURL: globalRoot, projectRootURLs: projectRoots)
    }

    convenience init() {
        let bookmarkStore: BookmarkStore?
        do {
            bookmarkStore = try BookmarkStore.makeLiveStore()
        } catch {
            let logger = Logger(subsystem: "com.nicholassophocleous.ClaudeConfigManager", category: "Bootstrap")
            logger.error("Failed to create live BookmarkStore: \(String(describing: error), privacy: .public)")
            bookmarkStore = nil
        }

        let globalStateStore: GlobalStateStore
        do {
            globalStateStore = try GlobalStateStore.makeLiveStore()
        } catch {
            let logger = Logger(subsystem: "com.nicholassophocleous.ClaudeConfigManager", category: "Bootstrap")
            logger.error("Failed to create live GlobalStateStore, falling back to in-memory: \(String(describing: error), privacy: .public)")
            globalStateStore = GlobalStateStore(persistence: InMemoryGlobalStatePersistence())
        }
        let projectRegistry = ProjectRegistry(bookmarkStore: bookmarkStore, globalStateStore: globalStateStore)
        let rootSelectionViewModel = RootSelectionViewModel(
            bookmarkStore: bookmarkStore,
            projectRegistry: projectRegistry,
            folderSelector: OpenPanelFolderSelector()
        )

        self.init(
            bootstrapState: .launching,
            sidebarState: SidebarState(),
            bookmarkStore: bookmarkStore,
            rootSelectionViewModel: rootSelectionViewModel
        )
    }

    func refreshPipeline() {
        Task {
            await triggerPipeline()
        }
    }

    func completeBootstrap() {
        defer {
            bootstrapState = .ready

            if sidebarState.selection == nil {
                sidebarState.selection = .dashboard
            }

            // Trigger pipeline after bootstrap completes
            Task {
                await triggerPipeline()
            }
        }

        guard let bookmarkStore else {
            logger.notice("Bookmark store unavailable at launch; proceeding without restored folder access")
            bookmarkResolutionResults = []
            bookmarkBootstrapSummary = .empty
            return
        }

        do {
            let results = try bookmarkStore.restoreAccessToKnownFolders()
            bookmarkResolutionResults = results
            bookmarkBootstrapSummary = BookmarkBootstrapSummary(
                total: results.count,
                accessible: results.filter {
                    if case .accessible = $0.status {
                        return true
                    }
                    return false
                }.count,
                requiresReauthorization: results.filter {
                    if case .requiresReauthorization = $0.status {
                        return true
                    }
                    return false
                }.count
            )
            rootSelectionViewModel.refreshFromStores()
        } catch {
            logger.error("Bookmark restore failed: \(String(describing: error), privacy: .public)")
            bookmarkResolutionResults = []
            bookmarkBootstrapSummary = .empty
            rootSelectionViewModel.refreshFromStores()
        }
    }
}

struct ProjectAddOutcome: Equatable {
    let registration: ProjectRegistration
    let wasDuplicate: Bool
}

final class ProjectRegistry {
    private let bookmarkStore: BookmarkStore?
    private let globalStateStore: GlobalStateStore

    init(
        bookmarkStore: BookmarkStore?,
        globalStateStore: GlobalStateStore
    ) {
        self.bookmarkStore = bookmarkStore
        self.globalStateStore = globalStateStore
    }

    func loadState() throws -> GlobalAppState {
        try globalStateStore.loadState()
    }

    func addProject(folderURL: URL, now: Date = Date()) throws -> ProjectAddOutcome {
        var state = try globalStateStore.loadState()
        let normalizedPath = Self.normalizePath(folderURL.path)

        if let existing = state.projectRegistrations.first(where: {
            $0.normalizedPath == normalizedPath
        }) {
            return ProjectAddOutcome(registration: existing, wasDuplicate: true)
        }

        guard let bookmarkStore else {
            throw BookmarkError.failedToSaveMetadata
        }

        let bookmarkID = Self.projectBookmarkID(for: normalizedPath)
        _ = try bookmarkStore.upsertBookmark(
            id: bookmarkID,
            kind: .projectRoot,
            folderURL: folderURL,
            displayName: folderURL.lastPathComponent,
            now: now
        )

        let registration = ProjectRegistration(
            id: bookmarkID,
            displayName: folderURL.lastPathComponent,
            preferredPath: folderURL.path,
            normalizedPath: normalizedPath,
            createdAt: now,
            updatedAt: now
        )
        state.projectRegistrations.append(registration)
        state.projectRegistrations.sort {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }

        if state.selectedProjectRegistrationID == nil {
            state.selectedProjectRegistrationID = registration.id
        }

        try globalStateStore.saveState(state)
        return ProjectAddOutcome(registration: registration, wasDuplicate: false)
    }

    func removeProject(id: String) throws {
        var state = try globalStateStore.loadState()
        state.projectRegistrations.removeAll { $0.id == id }
        if state.selectedProjectRegistrationID == id {
            state.selectedProjectRegistrationID = state.projectRegistrations.first?.id
        }

        try globalStateStore.saveState(state)
        try bookmarkStore?.removeBookmark(id: id)
    }

    func setSelectedProject(id: String?) throws {
        var state = try globalStateStore.loadState()
        if let id {
            guard state.projectRegistrations.contains(where: { $0.id == id }) else {
                return
            }
            state.selectedProjectRegistrationID = id
        } else {
            state.selectedProjectRegistrationID = nil
        }
        try globalStateStore.saveState(state)
    }

    func setGlobalRoot(folderURL: URL, source: GlobalClaudeRootSource, now: Date = Date()) throws {
        guard let bookmarkStore else {
            throw BookmarkError.failedToSaveMetadata
        }

        _ = try bookmarkStore.upsertBookmark(
            id: BookmarkStore.globalRootBookmarkID,
            kind: .globalClaudeRoot,
            folderURL: folderURL,
            displayName: "Claude Home Root",
            now: now
        )

        var state = try globalStateStore.loadState()
        state.globalClaudeRootSource = source
        state.globalClaudeRootBookmarkID = BookmarkStore.globalRootBookmarkID
        state.hasCompletedInitialGlobalRootSetup = true
        try globalStateStore.saveState(state)
    }

    func clearGlobalRootSelection() throws {
        var state = try globalStateStore.loadState()
        state.globalClaudeRootSource = .defaultHomeClaude
        state.globalClaudeRootBookmarkID = nil
        state.hasCompletedInitialGlobalRootSetup = true
        try globalStateStore.saveState(state)
        try bookmarkStore?.removeBookmark(id: BookmarkStore.globalRootBookmarkID)
    }

    func markInitialGlobalRootSetupCompleted() throws {
        var state = try globalStateStore.loadState()
        state.hasCompletedInitialGlobalRootSetup = true
        try globalStateStore.saveState(state)
    }

    func setManagedRoot(folderURL: URL, now: Date = Date()) throws {
        guard let bookmarkStore else {
            throw BookmarkError.failedToSaveMetadata
        }

        _ = try bookmarkStore.upsertBookmark(
            id: BookmarkStore.managedRootBookmarkID,
            kind: .managedClaudeCodeRoot,
            folderURL: folderURL,
            displayName: "Managed ClaudeCode Root",
            now: now
        )

        var state = try globalStateStore.loadState()
        state.managedRootBookmarkID = BookmarkStore.managedRootBookmarkID
        try globalStateStore.saveState(state)
    }

    func clearManagedRoot() throws {
        var state = try globalStateStore.loadState()
        state.managedRootBookmarkID = nil
        try globalStateStore.saveState(state)
        try bookmarkStore?.removeBookmark(id: BookmarkStore.managedRootBookmarkID)
    }

    func setUserClaudeJson(fileURL: URL, now: Date = Date()) throws {
        guard let bookmarkStore else {
            throw BookmarkError.failedToSaveMetadata
        }

        _ = try bookmarkStore.upsertBookmark(
            id: BookmarkStore.userClaudeJsonBookmarkID,
            kind: .userClaudeJson,
            folderURL: fileURL,
            displayName: ".claude.json",
            now: now
        )

        var state = try globalStateStore.loadState()
        state.userClaudeJsonBookmarkID = BookmarkStore.userClaudeJsonBookmarkID
        try globalStateStore.saveState(state)
    }

    func clearUserClaudeJson() throws {
        var state = try globalStateStore.loadState()
        state.userClaudeJsonBookmarkID = nil
        try globalStateStore.saveState(state)
        try bookmarkStore?.removeBookmark(id: BookmarkStore.userClaudeJsonBookmarkID)
    }

    func setEtcClaudeCodeRoot(folderURL: URL, now: Date = Date()) throws {
        guard let bookmarkStore else {
            throw BookmarkError.failedToSaveMetadata
        }

        _ = try bookmarkStore.upsertBookmark(
            id: BookmarkStore.etcClaudeCodeRootBookmarkID,
            kind: .etcClaudeCodeRoot,
            folderURL: folderURL,
            displayName: "etc claude-code Root",
            now: now
        )

        var state = try globalStateStore.loadState()
        state.etcClaudeCodeRootBookmarkID = BookmarkStore.etcClaudeCodeRootBookmarkID
        try globalStateStore.saveState(state)
    }

    func clearEtcClaudeCodeRoot() throws {
        var state = try globalStateStore.loadState()
        state.etcClaudeCodeRootBookmarkID = nil
        try globalStateStore.saveState(state)
        try bookmarkStore?.removeBookmark(id: BookmarkStore.etcClaudeCodeRootBookmarkID)
    }

    static func normalizePath(_ path: String) -> String {
        let resolved = URL(fileURLWithPath: path)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        return normalizeForCaseInsensitiveComparison(resolved)
    }

    static func projectBookmarkID(for normalizedPath: String) -> String {
        let digest = SHA256.hash(data: Data(normalizedPath.utf8))
        let prefix = digest.prefix(8).map { String(format: "%02x", $0) }.joined()
        return "project-\(prefix)"
    }

    private static func normalizeForCaseInsensitiveComparison(_ path: String) -> String {
        var normalized = (path as NSString).standardizingPath
        if normalized.count > 1, normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        return normalized.lowercased()
    }
}

@MainActor
final class RootSelectionViewModel: ObservableObject {
    @Published private(set) var defaultGlobalRootURL: URL
    @Published private(set) var selectedGlobalRootURL: URL
    @Published private(set) var globalRootSource: GlobalClaudeRootSource
    @Published private(set) var hasAuthorizedGlobalRoot: Bool
    @Published private(set) var hasCompletedInitialGlobalRootSetup: Bool
    @Published private(set) var hasAuthorizedManagedRoot: Bool
    @Published private(set) var hasAuthorizedUserClaudeJson: Bool
    @Published private(set) var hasAuthorizedEtcClaudeCodeRoot: Bool
    @Published private(set) var projectRegistrations: [ProjectRegistration]
    @Published var selectedProjectRegistrationID: String?
    @Published var issue: RootSelectionIssue?

    private let bookmarkStore: BookmarkStore?
    private let projectRegistry: ProjectRegistry
    private let folderSelector: FolderSelecting
    private let accessChecker: RootDirectoryAccessChecking

    init(
        bookmarkStore: BookmarkStore?,
        projectRegistry: ProjectRegistry,
        folderSelector: FolderSelecting,
        accessChecker: RootDirectoryAccessChecking = FileSystemRootDirectoryAccessChecker()
    ) {
        self.bookmarkStore = bookmarkStore
        self.projectRegistry = projectRegistry
        self.folderSelector = folderSelector
        self.accessChecker = accessChecker

        let defaultRoot = RealHomeDirectory.url
            .appendingPathComponent(".claude", isDirectory: true)
        self.defaultGlobalRootURL = defaultRoot
        self.selectedGlobalRootURL = defaultRoot
        self.globalRootSource = .defaultHomeClaude
        self.hasAuthorizedGlobalRoot = false
        self.hasCompletedInitialGlobalRootSetup = false
        self.hasAuthorizedManagedRoot = false
        self.hasAuthorizedUserClaudeJson = false
        self.hasAuthorizedEtcClaudeCodeRoot = false
        self.projectRegistrations = []
        self.selectedProjectRegistrationID = nil

        refreshFromStores()
    }

    var globalRootSourceLabel: String {
        guard hasAuthorizedGlobalRoot else {
            return "Not Authorized"
        }

        switch globalRootSource {
        case .defaultHomeClaude:
            return "Default"
        case .overrideBookmark:
            return "Custom"
        }
    }

    var recommendedGlobalRootIsAvailable: Bool {
        accessChecker.accessStatus(forDirectoryAt: defaultGlobalRootURL) == .accessible
    }

    var shouldPromptForInitialGlobalRootAccess: Bool {
        !hasCompletedInitialGlobalRootSetup && !hasAuthorizedGlobalRoot
    }

    func refreshFromStores() {
        do {
            let state = try projectRegistry.loadState()
            globalRootSource = state.globalClaudeRootSource
            hasCompletedInitialGlobalRootSetup = state.hasCompletedInitialGlobalRootSetup
            projectRegistrations = state.projectRegistrations
            selectedProjectRegistrationID = state.selectedProjectRegistrationID

            let allRecords = try bookmarkStore?.allRecords() ?? []

            if let globalRecord = allRecords.first(where: {
                $0.id == BookmarkStore.globalRootBookmarkID
            }) {
                selectedGlobalRootURL = URL(fileURLWithPath: globalRecord.preferredPath, isDirectory: true)
                hasAuthorizedGlobalRoot = true
            } else {
                selectedGlobalRootURL = defaultGlobalRootURL
                hasAuthorizedGlobalRoot = false
            }

            hasAuthorizedManagedRoot = allRecords.contains(where: {
                $0.id == BookmarkStore.managedRootBookmarkID
            })

            hasAuthorizedUserClaudeJson = allRecords.contains(where: {
                $0.id == BookmarkStore.userClaudeJsonBookmarkID
            })

            hasAuthorizedEtcClaudeCodeRoot = allRecords.contains(where: {
                $0.id == BookmarkStore.etcClaudeCodeRootBookmarkID
            })
        } catch {
            issue = .persistenceFailure(area: .globalRoot, details: String(describing: error))
        }
    }

    func chooseGlobalRootFolder() async {
        let candidate = await folderSelector.selectFolder(
            title: "Choose Global Claude Folder",
            message: "Choose the folder to inspect for global Claude configuration. The app requests read-only access.",
            prompt: "Grant Access",
            initialDirectory: selectedGlobalRootURL,
            showsHiddenFiles: true
        )
        guard let candidate else {
            return
        }

        guard accessChecker.accessStatus(forDirectoryAt: candidate) == .accessible else {
            issue = .unreadableGlobalRoot(path: candidate.path)
            return
        }

        saveGlobalRoot(candidate)
    }

    func authorizeRecommendedGlobalRoot() async {
        let candidate = await folderSelector.selectFolder(
            title: "Authorize Recommended Claude Folder",
            message: "Select the .claude folder in your home directory to grant read-only access.",
            prompt: "Grant Access",
            initialDirectory: defaultGlobalRootURL.deletingLastPathComponent(),
            showsHiddenFiles: true
        )
        guard let candidate else {
            return
        }

        guard accessChecker.accessStatus(forDirectoryAt: candidate) == .accessible else {
            issue = .unreadableGlobalRoot(path: candidate.path)
            return
        }

        // This method is specifically for the recommended default root,
        // so always use .defaultHomeClaude as the source.
        do {
            try projectRegistry.setGlobalRoot(folderURL: candidate, source: .defaultHomeClaude)
            issue = nil
            refreshFromStores()
        } catch {
            issue = .bookmarkFailure(area: .globalRoot, details: String(describing: error))
        }
    }

    private func saveGlobalRoot(_ folderURL: URL) {
        let normalizedCandidate = RootLocator.normalizedIdentityPath(folderURL.path)
        let normalizedDefault = RootLocator.normalizedIdentityPath(defaultGlobalRootURL.path)
        let source: GlobalClaudeRootSource = normalizedCandidate == normalizedDefault ? .defaultHomeClaude : .overrideBookmark

        do {
            try projectRegistry.setGlobalRoot(folderURL: folderURL, source: source)
            issue = nil
            refreshFromStores()
        } catch {
            issue = .bookmarkFailure(area: .globalRoot, details: String(describing: error))
        }
    }

    func clearGlobalRootSelection() {
        do {
            try projectRegistry.clearGlobalRootSelection()
            issue = nil
            refreshFromStores()
        } catch {
            issue = .bookmarkFailure(area: .globalRoot, details: String(describing: error))
        }
    }

    func authorizeManagedRoot() async {
        let managedURL = URL(fileURLWithPath: ManagedSettingsLocator.managedRootPath, isDirectory: true)
        let candidate = await folderSelector.selectFolder(
            title: "Authorize Managed Settings Folder",
            message: "Select the ClaudeCode folder in /Library/Application Support/ to grant read-only access to managed settings.",
            prompt: "Grant Access",
            initialDirectory: managedURL.deletingLastPathComponent(),
            showsHiddenFiles: false
        )
        guard let candidate else {
            return
        }

        do {
            try projectRegistry.setManagedRoot(folderURL: candidate)
            issue = nil
            refreshFromStores()
        } catch {
            issue = .bookmarkFailure(area: .managedRoot, details: String(describing: error))
        }
    }

    func clearManagedRootSelection() {
        do {
            try projectRegistry.clearManagedRoot()
            issue = nil
            refreshFromStores()
        } catch {
            issue = .bookmarkFailure(area: .managedRoot, details: String(describing: error))
        }
    }

    func authorizeUserClaudeJson() async {
        let candidate = await folderSelector.selectFolder(
            title: "Authorize .claude.json",
            message: "Select the .claude.json file in your home directory to grant read access.",
            prompt: "Grant Access",
            initialDirectory: RealHomeDirectory.url,
            showsHiddenFiles: true
        )
        guard let candidate else {
            return
        }

        do {
            try projectRegistry.setUserClaudeJson(fileURL: candidate)
            issue = nil
            refreshFromStores()
        } catch {
            issue = .bookmarkFailure(area: .userClaudeJson, details: String(describing: error))
        }
    }

    func clearUserClaudeJsonSelection() {
        do {
            try projectRegistry.clearUserClaudeJson()
            issue = nil
            refreshFromStores()
        } catch {
            issue = .bookmarkFailure(area: .userClaudeJson, details: String(describing: error))
        }
    }

    func authorizeEtcClaudeCodeRoot() async {
        let etcURL = URL(fileURLWithPath: "/etc/", isDirectory: true)
        let candidate = await folderSelector.selectFolder(
            title: "Authorize /etc/claude-code",
            message: "Select the claude-code folder in /etc/ to grant read access to system-level managed settings.",
            prompt: "Grant Access",
            initialDirectory: etcURL,
            showsHiddenFiles: false
        )
        guard let candidate else {
            return
        }

        do {
            try projectRegistry.setEtcClaudeCodeRoot(folderURL: candidate)
            issue = nil
            refreshFromStores()
        } catch {
            issue = .bookmarkFailure(area: .etcClaudeCodeRoot, details: String(describing: error))
        }
    }

    func clearEtcClaudeCodeRootSelection() {
        do {
            try projectRegistry.clearEtcClaudeCodeRoot()
            issue = nil
            refreshFromStores()
        } catch {
            issue = .bookmarkFailure(area: .etcClaudeCodeRoot, details: String(describing: error))
        }
    }

    func skipInitialGlobalRootSetup() {
        do {
            try projectRegistry.markInitialGlobalRootSetupCompleted()
            issue = nil
            refreshFromStores()
        } catch {
            issue = .persistenceFailure(area: .globalRoot, details: String(describing: error))
        }
    }

    func addProjectRoot() async {
        let candidate = await folderSelector.selectFolder(
            title: "Add Project Root",
            message: "Choose a project folder to register for discovery.",
            prompt: "Add Project",
            initialDirectory: RealHomeDirectory.url,
            showsHiddenFiles: false
        )
        guard let candidate else {
            return
        }

        do {
            let outcome = try projectRegistry.addProject(folderURL: candidate)
            if outcome.wasDuplicate {
                issue = .duplicateProject(path: outcome.registration.preferredPath)
            } else {
                issue = nil
            }
            refreshFromStores()
        } catch {
            issue = .bookmarkFailure(area: .projects, details: String(describing: error))
        }
    }

    func removeProject(id: String) {
        do {
            try projectRegistry.removeProject(id: id)
            issue = nil
            refreshFromStores()
        } catch {
            issue = .bookmarkFailure(area: .projects, details: String(describing: error))
        }
    }

    func selectProject(id: String) {
        do {
            try projectRegistry.setSelectedProject(id: id)
            selectedProjectRegistrationID = id
            issue = nil
        } catch {
            issue = .persistenceFailure(area: .projects, details: String(describing: error))
        }
    }

    func clearIssue(for area: RootSelectionArea) {
        guard issue?.area == area else {
            return
        }
        issue = nil
    }
}

@MainActor
private struct NoopFolderSelector: FolderSelecting {
    func selectFolder(
        title: String,
        message: String,
        prompt: String,
        initialDirectory: URL?,
        showsHiddenFiles: Bool
    ) async -> URL? {
        nil
    }
}

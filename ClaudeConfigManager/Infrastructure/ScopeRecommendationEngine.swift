import Foundation

struct ScopeRecommendation {
    let recommendedScope: ResolutionScope
    let rationale: String
    let isEditable: Bool
    let lockInfo: ManagedLockInfo?
}

struct ManagedLockInfo {
    let controllingTier: ManagedSettingsTierKind
    let sourcePath: String
    let enforcedValue: JSONValue
}

struct ScopeRecommendationEngine {
    /// Recommend where a setting should be saved based on its current state and availability.
    ///
    /// Rules (in order):
    /// 1. If the key is defined at the managed scope → `isEditable = false`, return `lockInfo`
    /// 2. If the key is already defined at one writable scope (user/project/project-local) → recommend that scope
    /// 3. If not defined anywhere, use the key's category from implicit rules:
    ///    - Personal preference keys → recommend `.user`
    ///    - Project behaviour keys → recommend `.project`
    /// 4. If `availableScopes` does not include the recommended scope, fall back to the next available scope
    func recommend(
        for keyPath: String,
        currentProjection: SessionProjection,
        availableScopes: [ResolutionScope]
    ) -> ScopeRecommendation {
        // Rule 1: Check if key is managed-locked
        if let managedLock = checkManagedLock(for: keyPath, in: currentProjection) {
            return ScopeRecommendation(
                recommendedScope: .managed,
                rationale: "This setting is controlled by \(managedLock.controllingTier.displayName).",
                isEditable: false,
                lockInfo: managedLock
            )
        }

        // Rule 2: Check if key already exists at writable scopes
        let writableScopes: [ResolutionScope] = [.user, .project, .projectLocal]
        if let existingScope = findExistingScope(for: keyPath, in: writableScopes, projection: currentProjection) {
            return ScopeRecommendation(
                recommendedScope: existingScope,
                rationale: "This setting already exists at \(scopeDisplayName(existingScope)). Editing here updates it in place.",
                isEditable: true,
                lockInfo: nil
            )
        }

        // Rule 3: Determine recommendation based on key category
        let recommendedByCategory = categorizeKey(keyPath)
        var finalScope = recommendedByCategory

        // Rule 4: Fall back if recommended scope not available
        if !availableScopes.contains(finalScope) {
            if let fallback = availableScopes.first(where: { $0 != .managed && $0 != .cli }) {
                finalScope = fallback
            } else if let fallback = availableScopes.first {
                finalScope = fallback
            }
        }

        let rationale = rationaleForCategory(keyPath, category: recommendedByCategory)
        return ScopeRecommendation(
            recommendedScope: finalScope,
            rationale: rationale,
            isEditable: true,
            lockInfo: nil
        )
    }

    // MARK: - Private helpers

    private func checkManagedLock(
        for keyPath: String,
        in projection: SessionProjection
    ) -> ManagedLockInfo? {
        // Check if the key is defined in the current resolved settings
        guard let settings = projection.settings else { return nil }

        // Find the entry for this keyPath
        guard let entry = settings.entries.first(where: { $0.keyPath == keyPath }) else {
            return nil
        }

        // Check if managed is a participant in the trace
        let managedParticipants = entry.value.trace.participants.filter { $0.scope == .managed }
        guard !managedParticipants.isEmpty else { return nil }

        // Key is managed-locked
        if let source = managedParticipants.first,
           let path = source.sourcePath,
           let resolvedValue = entry.value.effectiveValue {
            return ManagedLockInfo(
                controllingTier: .fileBased,
                sourcePath: path,
                enforcedValue: resolvedValue
            )
        }

        return nil
    }

    private func findExistingScope(
        for keyPath: String,
        in scopes: [ResolutionScope],
        projection: SessionProjection
    ) -> ResolutionScope? {
        guard let settings = projection.settings else { return nil }

        // Find the entry for this keyPath
        guard let entry = settings.entries.first(where: { $0.keyPath == keyPath }) else {
            return nil
        }

        // Check which of the writable scopes has this key
        let scopesWithKey = entry.value.trace.participants
            .filter { scopes.contains($0.scope) }
            .map { $0.scope }

        // Return the first matching scope (would be more sophisticated in reality)
        return scopesWithKey.first
    }

    private func categorizeKey(_ keyPath: String) -> ResolutionScope {
        let personalPrefixes = [
            "model", "smallModel", "largeLargeContextModel", "maxTokens",
            "temperature", "streaming", "verbose", "debug", "outputFormat",
            "preferredNotifChannel", "statusLine", "showTurnDuration"
        ]

        let projectBehaviourPrefixes = [
            "permissions", "hooks", "sandbox", "mcp",
            "worktree", "fileSuggestion", "env", "attribution"
        ]

        let prefix = keyPath.split(separator: ".").first.map(String.init) ?? keyPath

        if personalPrefixes.contains(prefix) {
            return .user
        } else if projectBehaviourPrefixes.contains(prefix) {
            return .project
        } else {
            // Default to user for unknown keys
            return .user
        }
    }

    private func rationaleForCategory(_ keyPath: String, category: ResolutionScope) -> String {
        switch category {
        case .user:
            return "This is a personal preference. Saving here applies it to all your projects."
        case .project:
            return "This setting affects how Claude behaves in this project. Saving here shares it with your team."
        default:
            return "Saving this setting."
        }
    }

    private func scopeDisplayName(_ scope: ResolutionScope) -> String {
        switch scope {
        case .user:
            return "User"
        case .project:
            return "Project"
        case .projectLocal:
            return "Project (Local)"
        case .session:
            return "Session"
        case .managed:
            return "Managed"
        case .cli:
            return "CLI"
        case .imported:
            return "Imported"
        case .autoMemory:
            return "Auto Memory"
        case .synthetic:
            return "Synthetic"
        }
    }
}

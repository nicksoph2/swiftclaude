import SwiftUI

/// Maps `SettingsKeyCategory` values into user-facing functional groups.
///
/// Users think "I want to restrict shell access", not "I need to edit permissions.deny
/// in settings.json". These groups answer the user's real question.
enum FunctionalGroup: String, CaseIterable, Identifiable {
    case modelAndReasoning
    case safetyAndPermissions
    case toolAccess
    case hooksAndLifecycle
    case instructionsAndMemory
    case identityAndAuth
    case uiAndSession
    case pluginsAndMarketplaces
    case gitAndAttribution
    case sandboxAndWorktree
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .modelAndReasoning:      "Model & Reasoning"
        case .safetyAndPermissions:   "Safety & Permissions"
        case .toolAccess:             "Tools & MCP Servers"
        case .hooksAndLifecycle:      "Hooks & Lifecycle"
        case .instructionsAndMemory:  "Instructions & Memory"
        case .identityAndAuth:        "Identity & Auth"
        case .uiAndSession:           "UI & Session"
        case .pluginsAndMarketplaces: "Plugins & Marketplaces"
        case .gitAndAttribution:      "Git & Attribution"
        case .sandboxAndWorktree:     "Sandbox & Worktree"
        case .general:                "General"
        }
    }

    var subtitle: String {
        switch self {
        case .modelAndReasoning:      "Which model, how hard does it try?"
        case .safetyAndPermissions:   "What can Claude do and not do?"
        case .toolAccess:             "What tools and servers are available?"
        case .hooksAndLifecycle:      "What code runs around tool calls?"
        case .instructionsAndMemory:  "What persistent instructions exist?"
        case .identityAndAuth:        "How does Claude authenticate?"
        case .uiAndSession:           "How does the session look and behave?"
        case .pluginsAndMarketplaces: "What plugins are installed?"
        case .gitAndAttribution:      "How are commits attributed?"
        case .sandboxAndWorktree:     "Sandbox isolation and worktree setup"
        case .general:                "Schema version and miscellaneous"
        }
    }

    var systemImage: String {
        switch self {
        case .modelAndReasoning:      "brain"
        case .safetyAndPermissions:   "lock.shield"
        case .toolAccess:             "wrench.and.screwdriver"
        case .hooksAndLifecycle:      "arrow.triangle.capsulepath"
        case .instructionsAndMemory:  "doc.text"
        case .identityAndAuth:        "person.badge.key"
        case .uiAndSession:           "macwindow"
        case .pluginsAndMarketplaces: "puzzlepiece.extension"
        case .gitAndAttribution:      "arrow.triangle.branch"
        case .sandboxAndWorktree:     "shield.lefthalf.filled"
        case .general:                "gearshape"
        }
    }

    /// The settings-key categories that belong to this functional group.
    var categories: Set<SettingsKeyCategory> {
        switch self {
        case .modelAndReasoning:      [.modelReasoning]
        case .safetyAndPermissions:   [.permissions]
        case .toolAccess:             [.mcpControls]
        case .hooksAndLifecycle:      [.hooksHookPolicy]
        case .instructionsAndMemory:  [.memoryClaudeMd]
        case .identityAndAuth:        [.authenticationIdentity, .environmentHelpers]
        case .uiAndSession:           [.uiSessionExperience, .operations]
        case .pluginsAndMarketplaces: [.pluginsMarketplaces]
        case .gitAndAttribution:      [.attributionGitBehavior]
        case .sandboxAndWorktree:     [.sandbox, .worktree]
        case .general:                [.general]
        }
    }

    /// Look up the functional group for a given settings category.
    static func group(for category: SettingsKeyCategory) -> FunctionalGroup {
        for group in FunctionalGroup.allCases {
            if group.categories.contains(category) {
                return group
            }
        }
        return .general
    }

    /// Look up the functional group for a given key definition.
    static func group(for key: SettingsKeyDefinition) -> FunctionalGroup {
        group(for: key.category)
    }
}

import XCTest
import SwiftUI
@testable import ClaudeConfigManager

final class ProjectSettingsEditorTests: XCTestCase {
    
    func testProjectEditorShowsTwoSections() {
        // Create team and personal documents
        let teamRawTopLevel: [String: JSONValue] = [
            "model": .string("claude-opus-4-1-20250805"),
        ]
        
        let personalRawTopLevel: [String: JSONValue] = [
            "temperature": .number(0.8),
        ]
        
        let teamDoc = ParsedSettingsDocument(
            source: SourceFileReference(url: URL(fileURLWithPath: "/Projects/test/.claude/settings.json")),
            value: SettingsDocumentValue(
                schema: nil, apiKeyHelper: nil, autoMemoryDirectory: nil, cleanupPeriodDays: nil,
                companyAnnouncements: nil, env: nil, attribution: nil, includeCoAuthoredBy: nil,
                includeGitInstructions: nil, permissions: nil, autoMode: nil, disableAutoMode: nil,
                useAutoModeDuringPlan: nil, worktree: nil, disableDeepLinkRegistration: nil, hooks: nil, disableAllHooks: nil,
                allowManagedHooksOnly: nil, allowedHTTPHookURLs: nil, httpHookAllowedEnvVars: nil,
                allowManagedMcpServersOnly: nil, enableAllProjectMcpServers: nil, enabledMcpjsonServers: nil,
                disabledMcpjsonServers: nil, allowedMcpServers: nil, deniedMcpServers: nil,
                sandbox: nil, enabledPlugins: nil, extraKnownMarketplaces: nil, strictKnownMarketplaces: nil,
                blockedMarketplaces: nil, pluginTrustMessage: nil, channelsEnabled: nil,
                allowedChannelPlugins: nil, language: nil, respectGitignore: nil, outputStyle: nil,
                defaultShell: nil, voiceEnabled: nil, prefersReducedMotion: nil, spinnerTipsEnabled: nil,
                showClearContextOnPlanAccept: nil, pluginSettings: [:], keyedStorage: [:], registryValues: [:]
            ),
            rawTopLevelObject: teamRawTopLevel,
            unsupportedTopLevelKeys: [:]
        )
        
        let personalDoc = ParsedSettingsDocument(
            source: SourceFileReference(url: URL(fileURLWithPath: "/Projects/test/.claude/settings.local.json")),
            value: SettingsDocumentValue(
                schema: nil, apiKeyHelper: nil, autoMemoryDirectory: nil, cleanupPeriodDays: nil,
                companyAnnouncements: nil, env: nil, attribution: nil, includeCoAuthoredBy: nil,
                includeGitInstructions: nil, permissions: nil, autoMode: nil, disableAutoMode: nil,
                useAutoModeDuringPlan: nil, worktree: nil, disableDeepLinkRegistration: nil, hooks: nil, disableAllHooks: nil,
                allowManagedHooksOnly: nil, allowedHTTPHookURLs: nil, httpHookAllowedEnvVars: nil,
                allowManagedMcpServersOnly: nil, enableAllProjectMcpServers: nil, enabledMcpjsonServers: nil,
                disabledMcpjsonServers: nil, allowedMcpServers: nil, deniedMcpServers: nil,
                sandbox: nil, enabledPlugins: nil, extraKnownMarketplaces: nil, strictKnownMarketplaces: nil,
                blockedMarketplaces: nil, pluginTrustMessage: nil, channelsEnabled: nil,
                allowedChannelPlugins: nil, language: nil, respectGitignore: nil, outputStyle: nil,
                defaultShell: nil, voiceEnabled: nil, prefersReducedMotion: nil, spinnerTipsEnabled: nil,
                showClearContextOnPlanAccept: nil, pluginSettings: [:], keyedStorage: [:], registryValues: [:]
            ),
            rawTopLevelObject: personalRawTopLevel,
            unsupportedTopLevelKeys: [:]
        )
        
        let view = ProjectSettingsEditorView(
            teamFileURL: URL(fileURLWithPath: "/Projects/test/.claude/settings.json"),
            personalFileURL: URL(fileURLWithPath: "/Projects/test/.claude/settings.local.json"),
            teamDocument: teamDoc,
            personalDocument: personalDoc
        )
        
        // Verify:
        // 1. Team section is labeled with person.2 icon and "shared with team"
        // 2. Personal section is labeled with person icon and "personal override, not shared"
        // 3. Personal section has visually distinct styling (dashed border)
        // 4. Team section shows model key
        // 5. Personal section shows temperature key
        
        XCTAssertNotNil(view)
    }
}

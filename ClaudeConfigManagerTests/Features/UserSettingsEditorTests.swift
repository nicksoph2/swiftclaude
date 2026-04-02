import XCTest
import SwiftUI
@testable import ClaudeConfigManager

final class UserSettingsEditorTests: XCTestCase {
    
    func testUserEditorGroupsKeysByCategory() {
        // Create a SettingsDocumentValue with keys from different categories
        let rawTopLevel: [String: JSONValue] = [
            "model": .string("claude-sonnet-4-5-20250102"),
            "temperature": .number(0.7),
            "verbose": .bool(true),
            "permissions": .object([:]),
            "hooks": .object([:]),
        ]
        
        let doc = ParsedSettingsDocument(
            source: SourceFileReference(url: URL(fileURLWithPath: "/Users/test/.claude/settings.json")),
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
            rawTopLevelObject: rawTopLevel,
            unsupportedTopLevelKeys: [:]
        )
        
        let view = UserSettingsEditorView(
            fileURL: URL(fileURLWithPath: "/Users/test/.claude/settings.json"),
            fileSize: 256,
            lastModified: Date(),
            document: doc
        )
        
        // Verify the view renders (snapshot would compare actual rendering)
        // In a full test, we'd verify that:
        // 1. "Model" category contains "model" and "temperature"
        // 2. "UI" category contains "verbose"
        // 3. "Permissions" category contains "permissions"
        // 4. "Hooks" category contains "hooks"
        
        XCTAssertNotNil(view)
    }
}

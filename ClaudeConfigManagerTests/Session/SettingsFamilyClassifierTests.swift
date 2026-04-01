import XCTest
@testable import ClaudeConfigManager

final class SettingsFamilyClassifierTests: XCTestCase {

    // MARK: - Model Family

    func testModelFamilyExactMatches() {
        let modelKeys = ["model", "availableModels", "modelOverrides", "effortLevel",
                         "alwaysThinkingEnabled", "fastMode", "fastModePerSessionOptIn",
                         "feedbackSurveyRate", "agent", "autoMode", "disableAutoMode",
                         "useAutoModeDuringPlan"]
        for key in modelKeys {
            XCTAssertEqual(
                SettingsFamilyClassifier.classify(key), .model,
                "Expected '\(key)' to classify as .model"
            )
        }
    }

    // MARK: - Permissions Family

    func testPermissionsFamilyExactAndPrefixMatches() {
        XCTAssertEqual(SettingsFamilyClassifier.classify("allowManagedPermissionRulesOnly"), .permissions)
        XCTAssertEqual(SettingsFamilyClassifier.classify("permissions.allow"), .permissions)
        XCTAssertEqual(SettingsFamilyClassifier.classify("permissions.deny"), .permissions)
        XCTAssertEqual(SettingsFamilyClassifier.classify("permissions.defaultMode"), .permissions)
        XCTAssertEqual(SettingsFamilyClassifier.classify("permissions.additionalDirectories"), .permissions)
        XCTAssertEqual(SettingsFamilyClassifier.classify("permissions.disableBypassPermissionsMode"), .permissions)
    }

    // MARK: - Hooks Policy Family

    func testHooksPolicyFamilyMatches() {
        XCTAssertEqual(SettingsFamilyClassifier.classify("disableAllHooks"), .hooksPolicy)
        XCTAssertEqual(SettingsFamilyClassifier.classify("allowManagedHooksOnly"), .hooksPolicy)
        XCTAssertEqual(SettingsFamilyClassifier.classify("allowedHttpHookUrls"), .hooksPolicy)
        XCTAssertEqual(SettingsFamilyClassifier.classify("httpHookAllowedEnvVars"), .hooksPolicy)
        XCTAssertEqual(SettingsFamilyClassifier.classify("hooks"), .hooksPolicy)
        // Nested hook keyPaths also classify as hooks policy
        XCTAssertEqual(SettingsFamilyClassifier.classify("hooks.preToolUse"), .hooksPolicy)
    }

    // MARK: - MCP Policy Family

    func testMcpPolicyFamilyMatches() {
        XCTAssertEqual(SettingsFamilyClassifier.classify("allowManagedMcpServersOnly"), .mcpPolicy)
        XCTAssertEqual(SettingsFamilyClassifier.classify("enableAllProjectMcpServers"), .mcpPolicy)
        XCTAssertEqual(SettingsFamilyClassifier.classify("enabledMcpjsonServers"), .mcpPolicy)
        XCTAssertEqual(SettingsFamilyClassifier.classify("disabledMcpjsonServers"), .mcpPolicy)
        XCTAssertEqual(SettingsFamilyClassifier.classify("allowedMcpServers"), .mcpPolicy)
        XCTAssertEqual(SettingsFamilyClassifier.classify("deniedMcpServers"), .mcpPolicy)
    }

    // MARK: - Sandbox Family

    func testSandboxFamilyPrefixMatches() {
        XCTAssertEqual(SettingsFamilyClassifier.classify("sandbox.enabled"), .sandbox)
        XCTAssertEqual(SettingsFamilyClassifier.classify("sandbox.failIfUnavailable"), .sandbox)
        XCTAssertEqual(SettingsFamilyClassifier.classify("sandbox.network.allowedDomains"), .sandbox)
        XCTAssertEqual(SettingsFamilyClassifier.classify("sandbox.filesystem.allowWrite"), .sandbox)
        XCTAssertEqual(SettingsFamilyClassifier.classify("sandbox.network.socksProxyPort"), .sandbox)
    }

    // MARK: - Plugins & Marketplaces Family

    func testPluginsAndMarketplacesFamilyMatches() {
        XCTAssertEqual(SettingsFamilyClassifier.classify("enabledPlugins"), .pluginsAndMarketplaces)
        XCTAssertEqual(SettingsFamilyClassifier.classify("extraKnownMarketplaces"), .pluginsAndMarketplaces)
        XCTAssertEqual(SettingsFamilyClassifier.classify("strictKnownMarketplaces"), .pluginsAndMarketplaces)
        XCTAssertEqual(SettingsFamilyClassifier.classify("blockedMarketplaces"), .pluginsAndMarketplaces)
        XCTAssertEqual(SettingsFamilyClassifier.classify("channelsEnabled"), .pluginsAndMarketplaces)
        XCTAssertEqual(SettingsFamilyClassifier.classify("allowedChannelPlugins"), .pluginsAndMarketplaces)
    }

    // MARK: - Authentication & Helpers Family

    func testAuthenticationAndHelpersFamilyMatches() {
        XCTAssertEqual(SettingsFamilyClassifier.classify("forceLoginMethod"), .authenticationAndHelpers)
        XCTAssertEqual(SettingsFamilyClassifier.classify("forceLoginOrgUUID"), .authenticationAndHelpers)
        XCTAssertEqual(SettingsFamilyClassifier.classify("otelHeadersHelper"), .authenticationAndHelpers)
        XCTAssertEqual(SettingsFamilyClassifier.classify("awsAuthRefresh"), .authenticationAndHelpers)
        XCTAssertEqual(SettingsFamilyClassifier.classify("apiKeyHelper"), .authenticationAndHelpers)
    }

    // MARK: - Memory & CLAUDE.md Family

    func testMemoryAndClaudeMdFamilyMatches() {
        XCTAssertEqual(SettingsFamilyClassifier.classify("autoMemoryDirectory"), .memoryAndClaudeMd)
        XCTAssertEqual(SettingsFamilyClassifier.classify("autoMemoryEnabled"), .memoryAndClaudeMd)
        XCTAssertEqual(SettingsFamilyClassifier.classify("claudeMdExcludes"), .memoryAndClaudeMd)
        XCTAssertEqual(SettingsFamilyClassifier.classify("includeGitInstructions"), .memoryAndClaudeMd)
        XCTAssertEqual(SettingsFamilyClassifier.classify("includeCoAuthoredBy"), .memoryAndClaudeMd)
        XCTAssertEqual(SettingsFamilyClassifier.classify("attribution.commit"), .memoryAndClaudeMd)
        XCTAssertEqual(SettingsFamilyClassifier.classify("attribution.pr"), .memoryAndClaudeMd)
    }

    // MARK: - UI & Session Experience Family

    func testUiAndSessionExperienceFamilyMatches() {
        XCTAssertEqual(SettingsFamilyClassifier.classify("language"), .uiAndSessionExperience)
        XCTAssertEqual(SettingsFamilyClassifier.classify("outputStyle"), .uiAndSessionExperience)
        XCTAssertEqual(SettingsFamilyClassifier.classify("defaultShell"), .uiAndSessionExperience)
        XCTAssertEqual(SettingsFamilyClassifier.classify("voiceEnabled"), .uiAndSessionExperience)
        XCTAssertEqual(SettingsFamilyClassifier.classify("cleanupPeriodDays"), .uiAndSessionExperience)
        XCTAssertEqual(SettingsFamilyClassifier.classify("env"), .uiAndSessionExperience)
        XCTAssertEqual(SettingsFamilyClassifier.classify("statusLine"), .uiAndSessionExperience)
        XCTAssertEqual(SettingsFamilyClassifier.classify("statusLine.padding"), .uiAndSessionExperience)
        XCTAssertEqual(SettingsFamilyClassifier.classify("prefersReducedMotion"), .uiAndSessionExperience)
        XCTAssertEqual(SettingsFamilyClassifier.classify("spinnerVerbs"), .uiAndSessionExperience)
    }

    // MARK: - Worktree Family

    func testWorktreeFamilyPrefixMatches() {
        XCTAssertEqual(SettingsFamilyClassifier.classify("worktree.sparsePaths"), .worktree)
        XCTAssertEqual(SettingsFamilyClassifier.classify("worktree.symlinkDirectories"), .worktree)
    }

    // MARK: - Unknown Keys

    func testUnknownKeysFallToOther() {
        XCTAssertEqual(SettingsFamilyClassifier.classify("someUnknownFutureKey"), .other)
        XCTAssertEqual(SettingsFamilyClassifier.classify("experimental.newFeature"), .other)
        XCTAssertEqual(SettingsFamilyClassifier.classify(""), .other)
    }

    // MARK: - Group By Family

    func testGroupByFamilyExcludesEmptyFamilies() {
        let keyPaths = ["model", "effortLevel", "sandbox.enabled"]
        let groups = SettingsFamilyClassifier.groupByFamily(keyPaths) { $0 }

        // Only Model and Sandbox should be present; all other families are empty and excluded
        XCTAssertEqual(groups.map(\.family), [.model, .sandbox])
        XCTAssertEqual(groups[0].items, ["model", "effortLevel"])
        XCTAssertEqual(groups[1].items, ["sandbox.enabled"])
    }

    func testGroupByFamilyPreservesFamilySortOrder() {
        // Insert in reverse order to verify sorting
        let keyPaths = ["worktree.sparsePaths", "sandbox.enabled", "model"]
        let groups = SettingsFamilyClassifier.groupByFamily(keyPaths) { $0 }

        XCTAssertEqual(groups.map(\.family), [.model, .sandbox, .worktree])
    }

    func testGroupByFamilyReturnsEmptyForNoItems() {
        let groups = SettingsFamilyClassifier.groupByFamily([String]()) { $0 }
        XCTAssertTrue(groups.isEmpty)
    }

    // MARK: - Family Properties

    func testAllFamiliesHaveTitles() {
        for family in SettingsFamily.allCases {
            XCTAssertFalse(family.title.isEmpty, "\(family) should have a non-empty title")
        }
    }

    func testAllFamiliesHaveUniqueRawValues() {
        let rawValues = SettingsFamily.allCases.map(\.rawValue)
        XCTAssertEqual(rawValues.count, Set(rawValues).count, "All families should have unique raw values")
    }

    func testAllFamiliesHaveUniqueSortOrders() {
        let orders = SettingsFamily.allCases.map(\.sortOrder)
        XCTAssertEqual(orders.count, Set(orders).count, "All families should have unique sort orders")
    }
}

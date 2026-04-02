import XCTest
@testable import ClaudeConfigManager

@MainActor
final class ProfileStoreTests: XCTestCase {

    // MARK: - Profile Round-Trip

    func testProfileRoundTrip() throws {
        let persistence = InMemoryProfilePersistence()
        let store = ProfileStore(persistence: persistence)

        let settings: [String: JSONValue] = [
            "model": .string("claude-opus"),
            "verbose": .bool(true),
            "maxTokens": .number(4096),
        ]

        let profile = ConfigurationProfile(
            name: "Test Profile",
            scope: .user,
            settings: settings,
            description: "A test profile"
        )

        try store.save(profile)

        // Verify it's in the store
        XCTAssertEqual(store.profiles.count, 1)
        XCTAssertEqual(store.profiles.first?.name, "Test Profile")

        // Load from persistence
        let loaded = try persistence.loadProfiles()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, profile.id)
        XCTAssertEqual(loaded.first?.name, profile.name)
        XCTAssertEqual(loaded.first?.scope, "user")
        XCTAssertEqual(loaded.first?.settings["model"], .string("claude-opus"))
        XCTAssertEqual(loaded.first?.settings["verbose"], .bool(true))
        XCTAssertEqual(loaded.first?.settings["maxTokens"], .number(4096))
        XCTAssertEqual(loaded.first?.description, "A test profile")
    }

    func testProfileDelete() throws {
        let persistence = InMemoryProfilePersistence()
        let store = ProfileStore(persistence: persistence)

        let profile = ConfigurationProfile(
            name: "To Delete",
            scope: .project,
            settings: ["model": .string("claude-sonnet")]
        )

        try store.save(profile)
        XCTAssertEqual(store.profiles.count, 1)

        store.delete(profile)
        XCTAssertEqual(store.profiles.count, 0)
    }

    func testProfileRename() throws {
        let persistence = InMemoryProfilePersistence()
        let store = ProfileStore(persistence: persistence)

        let profile = ConfigurationProfile(
            name: "Original",
            scope: .user,
            settings: [:]
        )

        try store.save(profile)
        try store.rename(profile, to: "Renamed")

        XCTAssertEqual(store.profiles.first?.name, "Renamed")
    }

    func testProfileDuplicate() throws {
        let persistence = InMemoryProfilePersistence()
        let store = ProfileStore(persistence: persistence)

        let profile = ConfigurationProfile(
            name: "Original",
            scope: .user,
            settings: ["model": .string("claude-opus")]
        )

        try store.save(profile)
        try store.duplicate(profile)

        XCTAssertEqual(store.profiles.count, 2)
        let copy = store.profiles.first { $0.id != profile.id }
        XCTAssertEqual(copy?.name, "Original Copy")
        XCTAssertEqual(copy?.settings["model"], .string("claude-opus"))
    }

    func testCreateFromProjection() throws {
        let persistence = InMemoryProfilePersistence()
        let store = ProfileStore(persistence: persistence)

        let userSource = ResolutionSource(
            scope: .user,
            kind: .file,
            identifier: "user-settings",
            sourcePath: "/home/.claude/settings.json"
        )
        let projectSource = ResolutionSource(
            scope: .project,
            kind: .file,
            identifier: "project-settings",
            sourcePath: "/project/.claude/settings.json"
        )

        let entries: [ResolvedSettingsEntry] = [
            ResolvedSettingsEntry(
                keyPath: "model",
                value: ResolvedValue(
                    effectiveValue: .string("claude-opus"),
                    winningSource: userSource,
                    trace: ResolutionTrace(participants: [userSource]),
                    mergeMethod: .selectHighestPrecedence
                )
            ),
            ResolvedSettingsEntry(
                keyPath: "verbose",
                value: ResolvedValue(
                    effectiveValue: .bool(true),
                    winningSource: projectSource,
                    trace: ResolutionTrace(participants: [projectSource]),
                    mergeMethod: .selectHighestPrecedence
                )
            ),
        ]

        let settings = ResolvedSettingsSnapshot(entries: entries)
        let projection = SessionProjection(settings: settings)

        let profile = try store.createFromProjection(
            name: "User Settings Capture",
            scope: .user,
            projection: projection,
            description: "Captured user scope settings"
        )

        // Should only include the entry won by user scope
        XCTAssertEqual(profile.settings.count, 1)
        XCTAssertEqual(profile.settings["model"], .string("claude-opus"))
        XCTAssertNil(profile.settings["verbose"]) // Won by project, not user
    }
}

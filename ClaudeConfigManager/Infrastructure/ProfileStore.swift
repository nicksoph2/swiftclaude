import Foundation

// MARK: - Configuration Profile Model

struct ConfigurationProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    let scope: String  // ResolutionScope raw value (stored as String for Codable)
    let settings: [String: JSONValue]
    let createdAt: Date
    let description: String?

    init(
        id: UUID = UUID(),
        name: String,
        scope: ResolutionScope,
        settings: [String: JSONValue],
        createdAt: Date = Date(),
        description: String? = nil
    ) {
        self.id = id
        self.name = name
        self.scope = scope.rawValue
        self.settings = settings
        self.createdAt = createdAt
        self.description = description
    }

    var resolutionScope: ResolutionScope? {
        ResolutionScope(rawValue: scope)
    }

    var keyCount: Int {
        settings.count
    }
}

// MARK: - Profile Store Errors

enum ProfileStoreError: Error, LocalizedError {
    case fileWriteFailed(String)
    case fileReadFailed(String)
    case profileNotFound(UUID)
    case duplicateName(String)

    var errorDescription: String? {
        switch self {
        case .fileWriteFailed(let detail):
            return "Failed to write profiles: \(detail)"
        case .fileReadFailed(let detail):
            return "Failed to read profiles: \(detail)"
        case .profileNotFound(let id):
            return "Profile not found: \(id)"
        case .duplicateName(let name):
            return "A profile named '\(name)' already exists"
        }
    }
}

// MARK: - Profile Persistence Protocol

protocol ProfilePersisting {
    func loadProfiles() throws -> [ConfigurationProfile]
    func saveProfiles(_ profiles: [ConfigurationProfile]) throws
}

// MARK: - File-Based Profile Persistence

struct FileProfilePersistence: ProfilePersisting {
    let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            self.fileURL = homeDir
                .appendingPathComponent(".claude", isDirectory: true)
                .appendingPathComponent("app-profiles.json", isDirectory: false)
        }
    }

    func loadProfiles() throws -> [ConfigurationProfile] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ConfigurationProfile].self, from: data)
    }

    func saveProfiles(_ profiles: [ConfigurationProfile]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(profiles)

        let directory = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - In-Memory Profile Persistence (for testing)

final class InMemoryProfilePersistence: ProfilePersisting {
    var profiles: [ConfigurationProfile] = []

    func loadProfiles() throws -> [ConfigurationProfile] {
        profiles
    }

    func saveProfiles(_ profiles: [ConfigurationProfile]) throws {
        self.profiles = profiles
    }
}

// MARK: - Profile Store

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profiles: [ConfigurationProfile] = []

    private let persistence: ProfilePersisting

    init(persistence: ProfilePersisting = FileProfilePersistence()) {
        self.persistence = persistence
        loadFromDisk()
    }

    func loadFromDisk() {
        do {
            profiles = try persistence.loadProfiles()
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        } catch {
            profiles = []
        }
    }

    func save(_ profile: ConfigurationProfile) throws {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        profiles.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        try persistence.saveProfiles(profiles)
    }

    func delete(_ profile: ConfigurationProfile) {
        profiles.removeAll { $0.id == profile.id }
        try? persistence.saveProfiles(profiles)
    }

    func rename(_ profile: ConfigurationProfile, to newName: String) throws {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
            throw ProfileStoreError.profileNotFound(profile.id)
        }
        var updated = profiles[index]
        updated.name = newName
        profiles[index] = updated
        profiles.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        try persistence.saveProfiles(profiles)
    }

    func duplicate(_ profile: ConfigurationProfile) throws {
        let copy = ConfigurationProfile(
            name: "\(profile.name) Copy",
            scope: profile.resolutionScope ?? .user,
            settings: profile.settings,
            createdAt: Date(),
            description: profile.description
        )
        try save(copy)
    }

    /// Creates a profile from the current resolved settings for a given scope.
    func createFromProjection(
        name: String,
        scope: ResolutionScope,
        projection: SessionProjection,
        description: String? = nil
    ) throws -> ConfigurationProfile {
        guard let settings = projection.settings else {
            let profile = ConfigurationProfile(
                name: name,
                scope: scope,
                settings: [:],
                description: description
            )
            try save(profile)
            return profile
        }

        // Filter entries to only those where the winning source is from the requested scope
        var scopeSettings: [String: JSONValue] = [:]
        for entry in settings.entries {
            if let winningSource = entry.value.winningSource,
               winningSource.scope == scope,
               let value = entry.value.effectiveValue {
                scopeSettings[entry.keyPath] = value
            }
        }

        let profile = ConfigurationProfile(
            name: name,
            scope: scope,
            settings: scopeSettings,
            description: description
        )
        try save(profile)
        return profile
    }
}

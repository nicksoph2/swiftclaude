import Foundation
import os

protocol BookmarkMetadataPersisting {
    func loadRecords() throws -> [BookmarkRecord]
    func saveRecords(_ records: [BookmarkRecord]) throws
    func loadBookmarkData(for id: String) throws -> Data?
    func saveBookmarkData(_ data: Data, for id: String) throws
    func removeBookmarkData(for id: String) throws
}

protocol GlobalStatePersisting {
    func loadState() throws -> GlobalAppState
    func saveState(_ state: GlobalAppState) throws
}

struct BookmarkStorageDescriptor: Equatable, Sendable {
    let metadataURL: URL
    let bookmarkBlobDirectoryURL: URL
}

struct AppOwnedBookmarkStorageLocator {
    private let fileManager: FileManager
    private let appFolderName: String

    init(
        fileManager: FileManager = .default,
        appFolderName: String = "ClaudeConfigManager"
    ) {
        self.fileManager = fileManager
        self.appFolderName = appFolderName
    }

    func makeStorageDescriptor() throws -> BookmarkStorageDescriptor {
        guard let appSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw BookmarkError.appSupportLocationUnavailable
        }

        let appDirectoryURL = appSupportURL.appendingPathComponent(appFolderName, isDirectory: true)
        let bookmarksDirectoryURL = appDirectoryURL.appendingPathComponent("Bookmarks", isDirectory: true)
        let blobsDirectoryURL = bookmarksDirectoryURL.appendingPathComponent("BookmarkBlobs", isDirectory: true)
        let metadataURL = bookmarksDirectoryURL.appendingPathComponent("bookmark_metadata.json", isDirectory: false)

        do {
            try fileManager.createDirectory(at: blobsDirectoryURL, withIntermediateDirectories: true)
        } catch {
            throw BookmarkError.failedToCreateStorageDirectory
        }

        return BookmarkStorageDescriptor(
            metadataURL: metadataURL,
            bookmarkBlobDirectoryURL: blobsDirectoryURL
        )
    }
}

struct AppOwnedGlobalStateStorageLocator {
    private let fileManager: FileManager
    private let appFolderName: String

    init(
        fileManager: FileManager = .default,
        appFolderName: String = "ClaudeConfigManager"
    ) {
        self.fileManager = fileManager
        self.appFolderName = appFolderName
    }

    func makeGlobalStateURL() throws -> URL {
        guard let appSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw BookmarkError.appSupportLocationUnavailable
        }

        let appDirectoryURL = appSupportURL.appendingPathComponent(appFolderName, isDirectory: true)
        let stateDirectoryURL = appDirectoryURL.appendingPathComponent("State", isDirectory: true)

        do {
            try fileManager.createDirectory(at: stateDirectoryURL, withIntermediateDirectories: true)
        } catch {
            throw BookmarkError.failedToCreateStorageDirectory
        }

        return stateDirectoryURL.appendingPathComponent("global_state.json", isDirectory: false)
    }
}

final class FileSystemGlobalStatePersistence: GlobalStatePersisting {
    private let fileManager: FileManager
    private let stateURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        fileManager: FileManager = .default,
        stateURL: URL
    ) {
        self.fileManager = fileManager
        self.stateURL = stateURL

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadState() throws -> GlobalAppState {
        guard fileManager.fileExists(atPath: stateURL.path) else {
            return .default
        }

        do {
            let data = try Data(contentsOf: stateURL)
            return try decoder.decode(GlobalAppState.self, from: data)
        } catch {
            throw BookmarkError.failedToLoadMetadata
        }
    }

    func saveState(_ state: GlobalAppState) throws {
        do {
            let data = try encoder.encode(state)
            try data.write(to: stateURL, options: .atomic)
        } catch {
            throw BookmarkError.failedToSaveMetadata
        }
    }
}

final class InMemoryGlobalStatePersistence: GlobalStatePersisting {
    var state: GlobalAppState = .default

    func loadState() throws -> GlobalAppState {
        state
    }

    func saveState(_ state: GlobalAppState) throws {
        self.state = state
    }
}

final class GlobalStateStore {
    private static let logger = Logger(subsystem: "com.nicholassophocleous.ClaudeConfigManager", category: "GlobalStateStore")

    private let persistence: GlobalStatePersisting

    init(persistence: GlobalStatePersisting) {
        self.persistence = persistence
    }

    static func makeLiveStore() throws -> GlobalStateStore {
        let stateURL = try AppOwnedGlobalStateStorageLocator().makeGlobalStateURL()
        logger.info("GlobalStateStore live store created at \(stateURL.path, privacy: .public)")
        let persistence = FileSystemGlobalStatePersistence(stateURL: stateURL)
        return GlobalStateStore(persistence: persistence)
    }

    func loadState() throws -> GlobalAppState {
        try persistence.loadState()
    }

    func saveState(_ state: GlobalAppState) throws {
        try persistence.saveState(state)
    }
}

final class FileSystemBookmarkPersistence: BookmarkMetadataPersisting {
    private struct MetadataEnvelope: Codable {
        var records: [BookmarkRecord]
    }

    private let fileManager: FileManager
    private let storage: BookmarkStorageDescriptor
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        fileManager: FileManager = .default,
        storage: BookmarkStorageDescriptor
    ) {
        self.fileManager = fileManager
        self.storage = storage

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadRecords() throws -> [BookmarkRecord] {
        guard fileManager.fileExists(atPath: storage.metadataURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: storage.metadataURL)
            let envelope = try decoder.decode(MetadataEnvelope.self, from: data)
            return envelope.records
        } catch {
            throw BookmarkError.failedToLoadMetadata
        }
    }

    func saveRecords(_ records: [BookmarkRecord]) throws {
        let envelope = MetadataEnvelope(records: records)

        do {
            let data = try encoder.encode(envelope)
            try data.write(to: storage.metadataURL, options: .atomic)
        } catch {
            throw BookmarkError.failedToSaveMetadata
        }
    }

    func loadBookmarkData(for id: String) throws -> Data? {
        let url = bookmarkBlobURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            return try Data(contentsOf: url)
        } catch {
            throw BookmarkError.failedToLoadBookmarkData
        }
    }

    func saveBookmarkData(_ data: Data, for id: String) throws {
        do {
            try data.write(to: bookmarkBlobURL(for: id), options: .atomic)
        } catch {
            throw BookmarkError.failedToSaveBookmarkData
        }
    }

    func removeBookmarkData(for id: String) throws {
        let url = bookmarkBlobURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw BookmarkError.failedToRemoveBookmarkData
        }
    }

    private func bookmarkBlobURL(for id: String) -> URL {
        storage.bookmarkBlobDirectoryURL
            .appendingPathComponent(sanitizeFileComponent(id), isDirectory: false)
            .appendingPathExtension("bookmark")
    }

    private func sanitizeFileComponent(_ input: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let cleanedScalars = input.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "_"
        }
        return String(cleanedScalars)
    }
}

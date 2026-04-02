import Foundation
import os

protocol BookmarkDataCoding {
    func makeBookmarkData(for url: URL) throws -> Data
    func resolveBookmarkData(_ data: Data) throws -> ResolvedBookmark
}

protocol SecurityScopedAccessing {
    func startAccessing(_ url: URL) -> Bool
    func stopAccessing(_ url: URL)
}

struct ResolvedBookmark: Equatable {
    let url: URL
    let isStale: Bool
}

struct URLBookmarkDataCoder: BookmarkDataCoding {
    func makeBookmarkData(for url: URL) throws -> Data {
        do {
            return try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw BookmarkError.failedToCreateBookmark
        }
    }

    func resolveBookmarkData(_ data: Data) throws -> ResolvedBookmark {
        var stale = false

        do {
            let resolvedURL = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            return ResolvedBookmark(url: resolvedURL, isStale: stale)
        } catch {
            throw BookmarkError.failedToLoadBookmarkData
        }
    }
}

struct URLSecurityScopeAccessor: SecurityScopedAccessing {
    func startAccessing(_ url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}

final class BookmarkStore {
    static let globalRootBookmarkID = "global-claude-root"
    static let managedRootBookmarkID = "managed-claude-code-root"
    static let userClaudeJsonBookmarkID = "user-claude-json"
    static let etcClaudeCodeRootBookmarkID = "etc-claude-code-root"

    private let persistence: BookmarkMetadataPersisting
    private let dataCoder: BookmarkDataCoding
    private let accessManager: SecurityScopedAccessing
    private let logger = Logger(subsystem: "com.nicholassophocleous.ClaudeConfigManager", category: "Bookmarks")

    private var activeAccessIDs: Set<String> = []
    private var activeURLsByID: [String: URL] = [:]

    init(
        persistence: BookmarkMetadataPersisting,
        dataCoder: BookmarkDataCoding = URLBookmarkDataCoder(),
        accessManager: SecurityScopedAccessing = URLSecurityScopeAccessor()
    ) {
        self.persistence = persistence
        self.dataCoder = dataCoder
        self.accessManager = accessManager
    }

    static func makeLiveStore() throws -> BookmarkStore {
        let storage = try AppOwnedBookmarkStorageLocator().makeStorageDescriptor()
        let logger = Logger(subsystem: "com.nicholassophocleous.ClaudeConfigManager", category: "BookmarkStore")
        logger.info("BookmarkStore live store created — metadata: \(storage.metadataURL.path, privacy: .public), blobs: \(storage.bookmarkBlobDirectoryURL.path, privacy: .public)")
        let persistence = FileSystemBookmarkPersistence(storage: storage)
        return BookmarkStore(persistence: persistence)
    }

    @discardableResult
    func upsertBookmark(
        id: String,
        kind: BookmarkKind,
        folderURL: URL,
        displayName: String? = nil,
        now: Date = Date()
    ) throws -> BookmarkRecord {
        let bookmarkData = try dataCoder.makeBookmarkData(for: folderURL)
        var records = try persistence.loadRecords()

        let resolvedDisplayName = displayName ?? folderURL.lastPathComponent

        if let index = records.firstIndex(where: { $0.id == id }) {
            var existing = records[index]
            existing.displayName = resolvedDisplayName
            existing.preferredPath = folderURL.path
            existing.updatedAt = now
            records[index] = existing
        } else {
            records.append(
                BookmarkRecord(
                    id: id,
                    kind: kind,
                    displayName: resolvedDisplayName,
                    preferredPath: folderURL.path,
                    createdAt: now,
                    updatedAt: now
                )
            )
        }

        try persistence.saveBookmarkData(bookmarkData, for: id)
        try persistence.saveRecords(records)

        logger.debug("Upserted bookmark id=\(id, privacy: .public) kind=\(kind.rawValue, privacy: .public)")

        guard let record = records.first(where: { $0.id == id }) else {
            assertionFailure("Bookmark record should exist after upsert")
            throw BookmarkError.failedToSaveMetadata
        }

        return record
    }

    func removeBookmark(id: String) throws {
        var records = try persistence.loadRecords()
        records.removeAll { $0.id == id }
        try persistence.saveRecords(records)
        try persistence.removeBookmarkData(for: id)

        releaseAccess(id: id)

        logger.debug("Removed bookmark id=\(id, privacy: .public)")
    }

    func allRecords() throws -> [BookmarkRecord] {
        try persistence.loadRecords().sorted { lhs, rhs in
            if lhs.kind == rhs.kind {
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
            return lhs.kind.rawValue < rhs.kind.rawValue
        }
    }

    func restoreAccessToKnownFolders() throws -> [BookmarkResolutionResult] {
        let records = try allRecords()
        return try records.map(resolveRecord(_:))
    }

    func resolveBookmark(id: String) throws -> BookmarkResolutionResult? {
        let record = try allRecords().first(where: { $0.id == id })
        guard let record else {
            return nil
        }

        return try resolveRecord(record)
    }

    func releaseAllAccess() {
        for (id, _) in activeURLsByID {
            releaseAccess(id: id)
        }
    }

    private func resolveRecord(_ record: BookmarkRecord) throws -> BookmarkResolutionResult {
        guard let bookmarkData = try persistence.loadBookmarkData(for: record.id) else {
            return BookmarkResolutionResult(record: record, status: .requiresReauthorization(reason: .missingBookmarkData, resolvedURL: nil))
        }

        let resolved: ResolvedBookmark

        do {
            resolved = try dataCoder.resolveBookmarkData(bookmarkData)
        } catch {
            logger.error("Failed to resolve bookmark id=\(record.id, privacy: .public): \(String(describing: error), privacy: .public)")
            return BookmarkResolutionResult(record: record, status: .requiresReauthorization(reason: .invalidBookmarkData, resolvedURL: nil))
        }

        if resolved.isStale {
            logger.notice("Bookmark id=\(record.id, privacy: .public) is stale and needs reauthorization")
            return BookmarkResolutionResult(
                record: record,
                status: .requiresReauthorization(reason: .staleBookmark, resolvedURL: resolved.url)
            )
        }

        if accessManager.startAccessing(resolved.url) {
            releaseAccess(id: record.id)
            activeURLsByID[record.id] = resolved.url
            activeAccessIDs.insert(record.id)

            return BookmarkResolutionResult(record: record, status: .accessible(url: resolved.url))
        }

        logger.notice("Bookmark id=\(record.id, privacy: .public) could not start security-scoped access")
        return BookmarkResolutionResult(
            record: record,
            status: .requiresReauthorization(reason: .accessDenied, resolvedURL: resolved.url)
        )
    }

    private func releaseAccess(id: String) {
        guard activeAccessIDs.contains(id), let url = activeURLsByID[id] else {
            return
        }

        accessManager.stopAccessing(url)
        activeAccessIDs.remove(id)
        activeURLsByID[id] = nil
    }
}

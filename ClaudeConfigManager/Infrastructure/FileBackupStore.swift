import Foundation

final class FileBackupStore {
    private let fileManager = FileManager.default
    private var backupMap: [String: URL] = [:]

    init() {}

    /// Save a copy of fileURL in a temp location. Returns the backup path.
    func backup(_ fileURL: URL) throws -> URL {
        let backupDir = URL.temporaryDirectory.appendingPathComponent("ClaudeConfigBackup", isDirectory: true)

        // Create backup directory if needed
        try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true, attributes: nil)

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fileName = fileURL.lastPathComponent
        let backupFileName = "\(fileName)_\(timestamp)_\(UUID().uuidString)"
        let backupURL = backupDir.appendingPathComponent(backupFileName)

        // If file exists, copy it to backup location
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.copyItem(at: fileURL, to: backupURL)
        }

        // Track this backup for later restoration
        backupMap[fileURL.path] = backupURL

        return backupURL
    }

    /// Restore the backed-up file to its original location.
    func restore(_ fileURL: URL) throws {
        guard let backupURL = backupMap[fileURL.path] else {
            throw NSError(domain: "FileBackupStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "No backup found for \(fileURL.path)"])
        }

        // If backup exists, restore it
        if fileManager.fileExists(atPath: backupURL.path) {
            // Remove the current file if it exists
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            try fileManager.moveItem(at: backupURL, to: fileURL)
        }

        // Clean up from map
        backupMap.removeValue(forKey: fileURL.path)
    }

    /// Remove the backup (called on successful write).
    func clear(_ fileURL: URL) {
        guard let backupURL = backupMap[fileURL.path] else {
            return
        }

        do {
            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.removeItem(at: backupURL)
            }
        } catch {
            // Silently ignore cleanup errors
        }

        backupMap.removeValue(forKey: fileURL.path)
    }
}

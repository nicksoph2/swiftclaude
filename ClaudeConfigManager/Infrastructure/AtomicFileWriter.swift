import Foundation
import Darwin

struct SettingsChange {
    let keyPath: String
    let newValue: JSONValue
    let operation: ChangeOperation
}

enum ChangeOperation {
    case set
    case remove
    case appendToArray(JSONValue)
    case removeFromArray(JSONValue)
}

indirect enum WriteError: Error {
    case fileNotReadable(URL)
    case parseFailure(URL, [SyntaxIssue])
    case schemaValidationFailed([SyntaxIssue])
    case serializationFailed(Error)
    case writeFailed(URL, Error)
    case syncFailed(Error)
    case renameFailed(URL, Error)
    case postWriteValidationFailed(expected: JSONValue, actual: JSONValue?)
    case rolledBack(originalError: WriteError)
}

final class AtomicFileWriter {
    private let pipeline: ConfigurationPipeline
    private let backupStore: FileBackupStore
    private let parser: SettingsParser
    private let validator: SettingsValidator
    private let fileManager = FileManager.default

    init(
        pipeline: ConfigurationPipeline,
        backupStore: FileBackupStore,
        parser: SettingsParser = SettingsParser(),
        validator: SettingsValidator = SettingsValidator()
    ) {
        self.pipeline = pipeline
        self.backupStore = backupStore
        self.parser = parser
        self.validator = validator
    }

    /// Apply a change to a settings file at the given scope.
    /// Validates before writing. Rolls back on post-write failure.
    func write(
        change: SettingsChange,
        to fileURL: URL,
        at scope: ResolutionScope,
        globalRootURL: URL? = nil,
        projectRootURLs: [URL] = []
    ) async throws(WriteError) {
        // Step 1: Read the target file into memory. If not exists, start with {}.
        let fileContent: String
        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                fileContent = try String(contentsOf: fileURL, encoding: .utf8)
            } catch {
                throw WriteError.fileNotReadable(fileURL)
            }
        } else {
            fileContent = "{}"
        }

        // Step 2: Parse JSON into SettingsDocument.
        guard let contentData = fileContent.data(using: .utf8) else {
            throw WriteError.parseFailure(fileURL, [])
        }
        let parseResult = parser.parse(data: contentData, sourceURL: fileURL, scope: scope)
        guard !parseResult.hasErrors, let document = parseResult.value else {
            throw WriteError.parseFailure(fileURL, parseResult.issues)
        }

        // Step 3: Apply the change in memory.
        let mutator = JSONKeyPathMutator()
        let modifiedRoot: JSONValue
        do {
            modifiedRoot = try mutator.apply(change, to: .object(document.rawTopLevelObject))
        } catch {
            throw WriteError.writeFailed(fileURL, error)
        }

        // Step 4: Validate the modified document against the schema.
        let modifiedDocument = ParsedSettingsDocument(
            source: document.source,
            value: document.value,
            rawTopLevelObject: modifiedRoot.objectValue ?? [:],
            unsupportedTopLevelKeys: document.unsupportedTopLevelKeys
        )
        let validationIssues = validator.validate(modifiedDocument, at: scope)
        let validationErrors = validationIssues.filter { $0.severity == .error }
        if !validationErrors.isEmpty {
            throw WriteError.schemaValidationFailed(validationErrors)
        }

        // Step 5: Serialize to canonical JSON with sortedKeys + prettyPrinted.
        let serializedData: Data
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            serializedData = try encoder.encode(modifiedRoot)
        } catch {
            throw WriteError.serializationFailed(error)
        }

        // Step 6: Backup original file.
        do {
            _ = try backupStore.backup(fileURL)
        } catch {
            throw WriteError.writeFailed(fileURL, error)
        }

        // Step 7: Write to temp file.
        let tempFileName = ".tmp_\(UUID()).json"
        let tempFileURL = fileURL.deletingLastPathComponent().appendingPathComponent(tempFileName)

        do {
            try serializedData.write(to: tempFileURL)
        } catch {
            throw WriteError.writeFailed(tempFileURL, error)
        }

        // Step 8: fsync the temp file.
        let fd = open(tempFileURL.path, O_WRONLY)
        if fd < 0 {
            throw WriteError.syncFailed(NSError(domain: "fsync", code: Int(errno)))
        }
        if fsync(fd) != 0 {
            close(fd)
            throw WriteError.syncFailed(NSError(domain: "fsync", code: Int(errno)))
        }
        close(fd)

        // Step 9: Rename temp file to fileURL.
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            try fileManager.moveItem(at: tempFileURL, to: fileURL)
        } catch {
            throw WriteError.renameFailed(fileURL, error)
        }

        // Step 10: Re-run pipeline.
        await pipeline.run(
            globalRootURL: globalRootURL,
            projectRootURLs: projectRootURLs
        )

        // Step 11: Verify resolved value for .set operations.
        if case .set = change.operation {
            let projection = await MainActor.run { self.pipeline.projection }
            let resolvedValue = getResolvedValue(at: change.keyPath, from: projection)
            if resolvedValue != change.newValue {
                // Rollback — restore backup, re-run pipeline.
                try? backupStore.restore(fileURL)
                await pipeline.run(
                    globalRootURL: globalRootURL,
                    projectRootURLs: projectRootURLs
                )
                let validationError = WriteError.postWriteValidationFailed(
                    expected: change.newValue,
                    actual: resolvedValue
                )
                throw WriteError.rolledBack(originalError: validationError)
            }
        }

        // Step 12: Clear backup on success.
        backupStore.clear(fileURL)
    }

    private func getResolvedValue(at keyPath: String, from projection: SessionProjection?) -> JSONValue? {
        guard let projection = projection,
              let settings = projection.settings else { return nil }
        return settings.entries.first(where: { $0.keyPath == keyPath })?.value.effectiveValue
    }
}

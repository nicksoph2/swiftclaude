import Foundation

protocol RuntimeSessionFileSystem {
    func nodeKind(at url: URL) -> WorkspaceScanningNodeKind
    func isReadable(at url: URL) -> Bool
    func contentsOfDirectory(at url: URL) throws -> [URL]
    func attributesOfItem(at url: URL) throws -> [FileAttributeKey: Any]
    func contents(at url: URL) throws -> Data
    func openFileHandle(forReadingFrom url: URL) throws -> FileHandle
}

struct DefaultRuntimeSessionFileSystem: RuntimeSessionFileSystem {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func nodeKind(at url: URL) -> WorkspaceScanningNodeKind {
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)

        guard exists else {
            return .missing
        }

        guard fileManager.isReadableFile(atPath: url.path) else {
            return .inaccessible
        }

        return isDirectory.boolValue ? .directory : .file
    }

    func isReadable(at url: URL) -> Bool {
        fileManager.isReadableFile(atPath: url.path)
    }

    func contentsOfDirectory(at url: URL) throws -> [URL] {
        try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
    }

    func attributesOfItem(at url: URL) throws -> [FileAttributeKey: Any] {
        try fileManager.attributesOfItem(atPath: url.path)
    }

    func contents(at url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    func openFileHandle(forReadingFrom url: URL) throws -> FileHandle {
        try FileHandle(forReadingFrom: url)
    }
}

@MainActor
final class RuntimeSessionDiscovery: ObservableObject {
    enum DataSource: Equatable {
        case none
        case transcriptDerived
        case statusLineSnapshot

        var displayName: String {
            switch self {
            case .none:
                return "None"
            case .transcriptDerived:
                return "Transcript-derived"
            case .statusLineSnapshot:
                return "Live status-line"
            }
        }
    }

    @Published var currentSession: RuntimeSessionSnapshot?
    @Published var lastUpdateTime: Date?
    @Published var discoveryIssues: [RuntimeSessionSnapshotError]
    @Published var dataSource: DataSource

    private let fileSystem: RuntimeSessionFileSystem
    private let nowProvider: () -> Date
    private let transcriptScanner: TranscriptScanner
    private var claudeRootURL: URL

    init(
        claudeRootURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude", isDirectory: true),
        fileSystem: RuntimeSessionFileSystem = DefaultRuntimeSessionFileSystem(),
        nowProvider: @escaping () -> Date = { .now }
    ) {
        self.claudeRootURL = RootLocator.normalizedDirectoryURL(claudeRootURL)
        self.fileSystem = fileSystem
        self.nowProvider = nowProvider
        self.transcriptScanner = TranscriptScanner(
            claudeRootURL: claudeRootURL,
            fileSystem: RuntimeSessionTranscriptScannerFileSystem(base: fileSystem)
        )
        self.currentSession = nil
        self.lastUpdateTime = nil
        self.discoveryIssues = []
        self.dataSource = .none
    }

    func updateClaudeRootURL(_ url: URL) {
        claudeRootURL = RootLocator.normalizedDirectoryURL(url)
        transcriptScanner.updateClaudeRootURL(claudeRootURL)
    }

    func discoverFromTranscripts() async {
        transcriptScanner.updateClaudeRootURL(claudeRootURL)
        await transcriptScanner.scanTranscripts()

        var issues = transcriptScanner.discoveryIssues.map(Self.mapDiscoveryError)
        var discoveredSnapshot: RuntimeSessionSnapshot?

        for metadata in transcriptScanner.recentTranscripts {
            let (entries, loadIssues) = await transcriptScanner.loadTranscriptContent(path: metadata.transcriptPath)
            issues.append(contentsOf: loadIssues.map(Self.mapDiscoveryError))

            if !entries.isEmpty || metadata.lineCount == 0 {
                discoveredSnapshot = TranscriptRuntimeSnapshotExtractor.snapshot(
                    metadata: metadata,
                    entries: entries,
                    capturedAt: metadata.modifiedAt
                )
                break
            }
        }

        currentSession = discoveredSnapshot
        dataSource = discoveredSnapshot == nil ? .none : .transcriptDerived
        discoveryIssues = deduplicated(issues)
        lastUpdateTime = nowProvider()
    }

    func parseStatusLinePayload(_ jsonData: Data) -> Result<RuntimeSessionSnapshot, RuntimeSessionSnapshotError> {
        do {
            let payload = try JSONDecoder().decode(StatusLinePayload.self, from: jsonData)
            return .success(RuntimeSessionSnapshot(from: payload, capturedAt: nowProvider()))
        } catch let error as DecodingError {
            return .failure(mapDecodingError(error))
        } catch {
            return .failure(.invalidJsonFormat(details: error.localizedDescription))
        }
    }

    private func mapDecodingError(_ error: DecodingError) -> RuntimeSessionSnapshotError {
        switch error {
        case .keyNotFound(let key, _):
            return .missingRequiredField(fieldName: key.stringValue)
        case .valueNotFound(let type, let context):
            return .invalidJsonFormat(details: "Missing \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))")
        case .typeMismatch(let type, let context):
            return .invalidJsonFormat(details: "Expected \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))")
        case .dataCorrupted(let context):
            return .invalidJsonFormat(details: context.debugDescription)
        @unknown default:
            return .invalidJsonFormat(details: String(describing: error))
        }
    }

    private func deduplicated(_ issues: [RuntimeSessionSnapshotError]) -> [RuntimeSessionSnapshotError] {
        var seen = Set<String>()
        return issues.filter { issue in
            seen.insert(String(describing: issue)).inserted
        }
    }

    private static func mapDiscoveryError(_ error: TranscriptDiscoveryError) -> RuntimeSessionSnapshotError {
        switch error {
        case .transcriptFileNotFound(let path):
            return .transcriptNotFound(path: path)
        case .invalidJsonLine(_, _, let details):
            return .invalidJsonFormat(details: details)
        case .fileAccessDenied(let path):
            return .fileAccessDenied(path: path)
        case .unexpectedDirectoryStructure(let path, let details):
            return .invalidJsonFormat(details: "\(details) (\(path))")
        }
    }
}

private struct RuntimeSessionTranscriptScannerFileSystem: TranscriptScannerFileSystem {
    let base: RuntimeSessionFileSystem

    func nodeKind(at url: URL) -> WorkspaceScanningNodeKind {
        base.nodeKind(at: url)
    }

    func isReadable(at url: URL) -> Bool {
        base.isReadable(at: url)
    }

    func contentsOfDirectory(at url: URL) throws -> [URL] {
        try base.contentsOfDirectory(at: url)
    }

    func attributesOfItem(at url: URL) throws -> [FileAttributeKey: Any] {
        try base.attributesOfItem(at: url)
    }

    func openFileHandle(forReadingFrom url: URL) throws -> FileHandle {
        try base.openFileHandle(forReadingFrom: url)
    }
}

protocol TranscriptScannerFileSystem {
    func nodeKind(at url: URL) -> WorkspaceScanningNodeKind
    func isReadable(at url: URL) -> Bool
    func contentsOfDirectory(at url: URL) throws -> [URL]
    func attributesOfItem(at url: URL) throws -> [FileAttributeKey: Any]
    func openFileHandle(forReadingFrom url: URL) throws -> FileHandle
}

struct DefaultTranscriptScannerFileSystem: TranscriptScannerFileSystem {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func nodeKind(at url: URL) -> WorkspaceScanningNodeKind {
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)

        guard exists else {
            return .missing
        }

        guard fileManager.isReadableFile(atPath: url.path) else {
            return .inaccessible
        }

        return isDirectory.boolValue ? .directory : .file
    }

    func isReadable(at url: URL) -> Bool {
        fileManager.isReadableFile(atPath: url.path)
    }

    func contentsOfDirectory(at url: URL) throws -> [URL] {
        try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
    }

    func attributesOfItem(at url: URL) throws -> [FileAttributeKey: Any] {
        try fileManager.attributesOfItem(atPath: url.path)
    }

    func openFileHandle(forReadingFrom url: URL) throws -> FileHandle {
        try FileHandle(forReadingFrom: url)
    }
}

@MainActor
final class TranscriptScanner: ObservableObject {
    @Published var recentTranscripts: [TranscriptMetadata]
    @Published var discoveryIssues: [TranscriptDiscoveryError]

    private let rootLocator: RootLocator
    private let fileSystem: TranscriptScannerFileSystem
    private var claudeRootURL: URL
    private(set) var allTranscripts: [TranscriptMetadata]

    init(
        rootLocator: RootLocator = RootLocator(bookmarkResolver: nil),
        claudeRootURL: URL? = nil,
        fileSystem: TranscriptScannerFileSystem = DefaultTranscriptScannerFileSystem()
    ) {
        self.rootLocator = rootLocator
        self.fileSystem = fileSystem
        let defaultRoot = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude", isDirectory: true)
        self.claudeRootURL = RootLocator.normalizedDirectoryURL(claudeRootURL ?? defaultRoot)
        self.recentTranscripts = []
        self.discoveryIssues = []
        self.allTranscripts = []
    }

    func updateClaudeRootURL(_ url: URL) {
        claudeRootURL = RootLocator.normalizedDirectoryURL(url)
    }

    func scanTranscripts() async {
        let _ = rootLocator
        let projectsRootURL = claudeRootURL.appendingPathComponent("projects", isDirectory: true)
        var issues: [TranscriptDiscoveryError] = []

        switch fileSystem.nodeKind(at: projectsRootURL) {
        case .missing:
            recentTranscripts = []
            allTranscripts = []
            discoveryIssues = []
            return
        case .inaccessible:
            recentTranscripts = []
            allTranscripts = []
            discoveryIssues = [.fileAccessDenied(path: projectsRootURL.path)]
            return
        case .file:
            recentTranscripts = []
            allTranscripts = []
            discoveryIssues = [.unexpectedDirectoryStructure(path: projectsRootURL.path, details: "Projects root is not a directory.")]
            return
        case .directory:
            break
        }

        let transcriptURLs = recursiveTranscriptURLs(in: projectsRootURL, issues: &issues)
        var transcripts: [TranscriptMetadata] = []

        for transcriptURL in transcriptURLs {
            let (metadata, metadataIssues) = await extractMetadata(path: transcriptURL.path)
            issues.append(contentsOf: metadataIssues)
            if let metadata {
                transcripts.append(metadata)
            }
        }

        let sorted = transcripts.sorted(by: compareMetadata)
        allTranscripts = sorted
        recentTranscripts = sorted.filter { $0.transcriptKind == .primarySession }
        discoveryIssues = deduplicated(issues)
    }

    func loadTranscriptContent(path: String) async -> ([TranscriptEntry], [TranscriptDiscoveryError]) {
        let transcriptURL = RootLocator.normalizedDirectoryURL(URL(fileURLWithPath: path, isDirectory: false))

        guard fileSystem.nodeKind(at: transcriptURL) == .file else {
            return ([], [.transcriptFileNotFound(path: transcriptURL.path)])
        }

        guard fileSystem.isReadable(at: transcriptURL) else {
            return ([], [.fileAccessDenied(path: transcriptURL.path)])
        }

        var entries: [TranscriptEntry] = []
        var issues: [TranscriptDiscoveryError] = []

        do {
            try TranscriptLineReader.enumerateLines(at: transcriptURL, using: fileSystem) { lineNumber, rawLine, lineData in
                let parsed = TranscriptRecordParser.parseEntry(
                    lineNumber: lineNumber,
                    rawLine: rawLine,
                    lineData: lineData,
                    path: transcriptURL.path
                )
                entries.append(parsed.entry)
                issues.append(contentsOf: parsed.issues)
            }
        } catch {
            issues.append(.fileAccessDenied(path: transcriptURL.path))
        }

        return (entries, deduplicated(issues))
    }

    func extractMetadata(path: String) async -> (TranscriptMetadata?, [TranscriptDiscoveryError]) {
        let transcriptURL = RootLocator.normalizedDirectoryURL(URL(fileURLWithPath: path, isDirectory: false))
        let projectsRootURL = claudeRootURL.appendingPathComponent("projects", isDirectory: true)

        guard fileSystem.nodeKind(at: transcriptURL) == .file else {
            return (nil, [.transcriptFileNotFound(path: transcriptURL.path)])
        }

        guard fileSystem.isReadable(at: transcriptURL) else {
            return (nil, [.fileAccessDenied(path: transcriptURL.path)])
        }

        let classification = classifyTranscript(at: transcriptURL, projectsRootURL: projectsRootURL)
        var issues = classification.issues

        guard let pathInfo = classification.classification else {
            return (nil, deduplicated(issues))
        }

        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try fileSystem.attributesOfItem(at: transcriptURL)
        } catch {
            return (nil, deduplicated(issues + [.fileAccessDenied(path: transcriptURL.path)]))
        }

        let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        let createdAt = attributes[.creationDate] as? Date
        let modifiedAt = (attributes[.modificationDate] as? Date) ?? .distantPast

        var lineCount = 0
        var detectedModel: String?
        var totalTokensIn: Int?
        var totalTokensOut: Int?

        do {
            try TranscriptLineReader.enumerateLines(at: transcriptURL, using: fileSystem) { lineNumber, rawLine, lineData in
                lineCount = lineNumber
                let parsed = TranscriptRecordParser.parseEntry(
                    lineNumber: lineNumber,
                    rawLine: rawLine,
                    lineData: lineData,
                    path: transcriptURL.path
                )
                issues.append(contentsOf: parsed.issues)

                if detectedModel == nil {
                    detectedModel = parsed.entry.model
                }
                if let usage = parsed.entry.usage {
                    if let inputTokens = usage.inputTokens {
                        totalTokensIn = inputTokens
                    }
                    if let outputTokens = usage.outputTokens {
                        totalTokensOut = outputTokens
                    }
                }
            }
        } catch {
            return (nil, deduplicated(issues + [.fileAccessDenied(path: transcriptURL.path)]))
        }

        let metadata = TranscriptMetadata(
            id: RootLocator.normalizedIdentityPath(transcriptURL.path),
            sessionId: pathInfo.sessionId,
            transcriptKind: pathInfo.transcriptKind,
            agentId: pathInfo.agentId,
            projectKey: pathInfo.projectKey,
            transcriptPath: transcriptURL.path,
            fileSize: fileSize,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            lineCount: lineCount,
            model: detectedModel,
            totalTokensIn: totalTokensIn,
            totalTokensOut: totalTokensOut
        )

        return (metadata, deduplicated(issues))
    }

    func subagentTranscripts(forParentSessionID sessionID: String?) -> [TranscriptMetadata] {
        guard let sessionID else {
            return []
        }

        return allTranscripts
            .filter { $0.transcriptKind == .subagent && $0.sessionId == sessionID }
            .sorted(by: compareMetadata)
    }

    private func recursiveTranscriptURLs(
        in directoryURL: URL,
        issues: inout [TranscriptDiscoveryError]
    ) -> [URL] {
        do {
            let children = try fileSystem.contentsOfDirectory(at: directoryURL)
            var results: [URL] = []

            for child in children.sorted(by: { $0.path < $1.path }) {
                switch fileSystem.nodeKind(at: child) {
                case .directory:
                    results.append(contentsOf: recursiveTranscriptURLs(in: child, issues: &issues))
                case .file:
                    if child.pathExtension.lowercased() == "jsonl" {
                        results.append(RootLocator.normalizedDirectoryURL(child))
                    }
                case .inaccessible:
                    issues.append(.fileAccessDenied(path: child.path))
                case .missing:
                    continue
                }
            }

            return results
        } catch {
            issues.append(.fileAccessDenied(path: directoryURL.path))
            return []
        }
    }

    private func compareMetadata(lhs: TranscriptMetadata, rhs: TranscriptMetadata) -> Bool {
        if lhs.modifiedAt == rhs.modifiedAt {
            return lhs.transcriptPath < rhs.transcriptPath
        }

        return lhs.modifiedAt > rhs.modifiedAt
    }

    private func classifyTranscript(
        at transcriptURL: URL,
        projectsRootURL: URL
    ) -> (classification: TranscriptPathClassification?, issues: [TranscriptDiscoveryError]) {
        let normalizedProjectsRoot = RootLocator.normalizedDirectoryURL(projectsRootURL)
        let normalizedTranscriptURL = RootLocator.normalizedDirectoryURL(transcriptURL)
        let prefix = normalizedProjectsRoot.path.hasSuffix("/") ? normalizedProjectsRoot.path : normalizedProjectsRoot.path + "/"

        guard normalizedTranscriptURL.path.hasPrefix(prefix) else {
            return (
                nil,
                [.unexpectedDirectoryStructure(path: normalizedTranscriptURL.path, details: "Transcript is outside the Claude projects directory.")]
            )
        }

        let relativePath = String(normalizedTranscriptURL.path.dropFirst(prefix.count))
        let components = relativePath.split(separator: "/").map(String.init)
        guard components.count >= 2 else {
            return (
                nil,
                [.unexpectedDirectoryStructure(path: normalizedTranscriptURL.path, details: "Expected a project key and transcript filename.")]
            )
        }

        let projectKey = components.first
        let transcriptName = normalizedTranscriptURL.deletingPathExtension().lastPathComponent

        if let subagentIndex = components.firstIndex(of: "subagents"), subagentIndex >= 2 {
            let parentSessionID = components[subagentIndex - 1]
            return (
                TranscriptPathClassification(
                    transcriptKind: .subagent,
                    sessionId: parentSessionID,
                    agentId: transcriptName,
                    projectKey: projectKey
                ),
                []
            )
        }

        var issues: [TranscriptDiscoveryError] = []
        if components.count != 2 {
            issues.append(
                .unexpectedDirectoryStructure(
                    path: normalizedTranscriptURL.path,
                    details: "Treating nested transcript as a primary session transcript using the filename stem."
                )
            )
        }

        return (
            TranscriptPathClassification(
                transcriptKind: .primarySession,
                sessionId: transcriptName,
                agentId: nil,
                projectKey: projectKey
            ),
            issues
        )
    }

    private func deduplicated(_ issues: [TranscriptDiscoveryError]) -> [TranscriptDiscoveryError] {
        var seen = Set<String>()
        return issues.filter { issue in
            seen.insert(String(describing: issue)).inserted
        }
    }
}

private struct TranscriptPathClassification {
    let transcriptKind: TranscriptKind
    let sessionId: String?
    let agentId: String?
    let projectKey: String?
}

private enum TranscriptLineReader {
    static func enumerateLines(
        at url: URL,
        using fileSystem: TranscriptScannerFileSystem,
        _ body: (_ lineNumber: Int, _ rawLine: String, _ lineData: Data) -> Void
    ) throws {
        let handle = try fileSystem.openFileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }

        var buffer = Data()
        var lineNumber = 0

        while let chunk = try handle.read(upToCount: 4096), !chunk.isEmpty {
            buffer.append(chunk)

            while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                let lineData = Data(buffer[..<newlineIndex])
                buffer.removeSubrange(...newlineIndex)
                lineNumber += 1
                body(lineNumber, decodeLine(lineData), trimCarriageReturn(in: lineData))
            }
        }

        if !buffer.isEmpty {
            lineNumber += 1
            body(lineNumber, decodeLine(buffer), trimCarriageReturn(in: buffer))
        }
    }

    private static func decodeLine(_ data: Data) -> String {
        String(decoding: trimCarriageReturn(in: data), as: UTF8.self)
    }

    private static func trimCarriageReturn(in data: Data) -> Data {
        guard data.last == 0x0D else {
            return data
        }

        return Data(data.dropLast())
    }
}

private enum TranscriptRecordParser {
    struct ParsedEntry {
        let entry: TranscriptEntry
        let issues: [TranscriptDiscoveryError]
    }

    private static let iso8601WithFractional = ISO8601DateFormatter()
    private static let iso8601WithoutFractional = ISO8601DateFormatter()

    static func parseEntry(
        lineNumber: Int,
        rawLine: String,
        lineData: Data,
        path: String
    ) -> ParsedEntry {
        configureFormattersIfNeeded()

        do {
            let object = try decodeJSONObject(lineData)
            let entry = TranscriptEntry(
                lineNumber: lineNumber,
                rawJson: object,
                rawLine: rawLine,
                type: string(in: object["type"]),
                role: role(in: object),
                contentPreview: contentPreview(in: object),
                model: model(in: object),
                timestamp: timestamp(in: object),
                usage: usage(in: object)
            )
            return ParsedEntry(entry: entry, issues: [])
        } catch {
            let entry = TranscriptEntry(
                lineNumber: lineNumber,
                rawJson: [:],
                rawLine: rawLine,
                type: nil,
                role: nil,
                contentPreview: nil,
                model: nil,
                timestamp: nil,
                usage: nil
            )
            return ParsedEntry(
                entry: entry,
                issues: [.invalidJsonLine(path: path, lineNumber: lineNumber, details: error.localizedDescription)]
            )
        }
    }

    private static func configureFormattersIfNeeded() {
        iso8601WithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        iso8601WithoutFractional.formatOptions = [.withInternetDateTime]
    }

    private static func decodeJSONObject(_ data: Data) throws -> [String: JSONValue] {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw NSError(domain: "TranscriptRecordParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Top-level JSON value is not an object."])
        }

        return dictionary.mapValues(JSONValue.from(any:))
    }

    private static func role(in object: [String: JSONValue]) -> String? {
        if let messageObject = object["message"]?.objectValue,
           let role = string(in: messageObject["role"]) {
            return role
        }

        return string(in: object["role"])
    }

    private static func contentPreview(in object: [String: JSONValue]) -> String? {
        if let messageObject = object["message"]?.objectValue,
           let content = contentString(from: messageObject["content"]) {
            return content
        }

        if let content = contentString(from: object["content"]) {
            return content
        }

        if let message = string(in: object["message"]) {
            return message
        }

        return nil
    }

    private static func contentString(from value: JSONValue?) -> String? {
        guard let value else {
            return nil
        }

        switch value {
        case .string(let string):
            return string
        case .array(let values):
            let strings = values.compactMap { element -> String? in
                switch element {
                case .string(let string):
                    return string
                case .object(let object):
                    if string(in: object["type"]) == "text" {
                        return string(in: object["text"])
                    }
                    return string(in: object["text"])
                case .number, .bool, .array, .null:
                    return nil
                }
            }
            return strings.isEmpty ? nil : strings.joined(separator: "\n")
        case .object(let object):
            return string(in: object["text"])
        case .number, .bool, .null:
            return nil
        }
    }

    private static func model(in object: [String: JSONValue]) -> String? {
        if let messageObject = object["message"]?.objectValue,
           let model = modelString(from: messageObject["model"]) {
            return model
        }

        return modelString(from: object["model"])
    }

    private static func modelString(from value: JSONValue?) -> String? {
        switch value {
        case .string(let string):
            return string
        case .object(let object):
            return string(in: object["id"]) ?? string(in: object["name"]) ?? string(in: object["display_name"])
        case .array, .number, .bool, .null, nil:
            return nil
        }
    }

    private static func usage(in object: [String: JSONValue]) -> TranscriptUsage? {
        if let messageObject = object["message"]?.objectValue,
           let usage = usage(from: messageObject["usage"]) {
            return usage
        }

        return usage(from: object["usage"])
    }

    private static func usage(from value: JSONValue?) -> TranscriptUsage? {
        guard let object = value?.objectValue else {
            return nil
        }

        let inputTokens = int(in: object["input_tokens"]) ?? int(in: object["inputTokens"])
        let outputTokens = int(in: object["output_tokens"]) ?? int(in: object["outputTokens"])

        guard inputTokens != nil || outputTokens != nil else {
            return nil
        }

        return TranscriptUsage(inputTokens: inputTokens, outputTokens: outputTokens)
    }

    private static func timestamp(in object: [String: JSONValue]) -> Date? {
        if let stringTimestamp = string(in: object["timestamp"]) {
            return iso8601WithFractional.date(from: stringTimestamp) ?? iso8601WithoutFractional.date(from: stringTimestamp)
        }

        if let numericTimestamp = object["timestamp"]?.intValue {
            let value = Double(numericTimestamp)
            return value > 9_999_999_999 ? Date(timeIntervalSince1970: value / 1000) : Date(timeIntervalSince1970: value)
        }

        return nil
    }

    private static func string(in value: JSONValue?) -> String? {
        value?.stringValue
    }

    private static func int(in value: JSONValue?) -> Int? {
        value?.intValue
    }
}

enum TranscriptRuntimeSnapshotExtractor {
    static func snapshot(
        metadata: TranscriptMetadata,
        entries: [TranscriptEntry],
        capturedAt: Date
    ) -> RuntimeSessionSnapshot {
        let values = entries
            .filter { !$0.rawJson.isEmpty }
            .map { JSONValue.object($0.rawJson) }
        let recentFirst = Array(values.reversed())
        let combined = recentFirst + values

        let modelObject = combined.compactMap { findObject(in: $0, keys: ["model"]) }.first

        let modelId =
            string(in: modelObject?["id"]) ??
            findString(in: combined, keys: ["model_id", "modelId"]) ??
            metadata.model ??
            "unknown"
        let modelDisplayName =
            string(in: modelObject?["display_name"]) ??
            string(in: modelObject?["displayName"]) ??
            findString(in: combined, keys: ["display_name", "displayName", "model_name", "modelName"]) ??
            metadata.model ??
            modelId
        let cwd =
            findWorkspaceString(in: combined, key: "current_dir") ??
            findWorkspaceString(in: combined, key: "currentDir") ??
            findString(in: combined, keys: ["cwd", "current_dir", "currentDir"]) ??
            "Unknown"
        let projectDir =
            findWorkspaceString(in: combined, key: "project_dir") ??
            findWorkspaceString(in: combined, key: "projectDir") ??
            findString(in: combined, keys: ["project_dir", "projectDir"])
        let version = findString(in: combined, keys: ["version"])
        let sessionID =
            findString(in: combined, keys: ["session_id", "sessionId"]) ??
            metadata.sessionId ??
            URL(fileURLWithPath: metadata.transcriptPath).deletingPathExtension().lastPathComponent

        return RuntimeSessionSnapshot(
            id: sessionID,
            transcriptPath: metadata.transcriptPath,
            modelId: modelId,
            modelDisplayName: modelDisplayName,
            cwd: cwd,
            projectDir: projectDir,
            version: version,
            totalCostUsd: nil,
            totalDurationMs: nil,
            totalLinesAdded: nil,
            totalLinesRemoved: nil,
            totalInputTokens: metadata.totalTokensIn,
            totalOutputTokens: metadata.totalTokensOut,
            contextWindowSize: nil,
            usedPercentage: nil,
            fiveHourUsedPercentage: nil,
            fiveHourResetsAt: nil,
            sevenDayUsedPercentage: nil,
            sevenDayResetsAt: nil,
            capturedAt: capturedAt
        )
    }

    private static func findWorkspaceString(in values: [JSONValue], key: String) -> String? {
        for value in values {
            guard let workspace = findObject(in: value, keys: ["workspace"]) else {
                continue
            }
            if let match = string(in: workspace[key]) {
                return match
            }
        }
        return nil
    }

    private static func findString(in values: [JSONValue], keys: [String]) -> String? {
        for value in values {
            if let match = findString(in: value, keys: keys) {
                return match
            }
        }
        return nil
    }

    private static func findString(in value: JSONValue, keys: [String]) -> String? {
        switch value {
        case .object(let object):
            for key in keys {
                if let match = string(in: object[key]) {
                    return match
                }
            }
            for nested in object.values {
                if let match = findString(in: nested, keys: keys) {
                    return match
                }
            }
            return nil
        case .array(let array):
            for nested in array {
                if let match = findString(in: nested, keys: keys) {
                    return match
                }
            }
            return nil
        case .string, .number, .bool, .null:
            return nil
        }
    }

    private static func findObject(in value: JSONValue, keys: [String]) -> [String: JSONValue]? {
        switch value {
        case .object(let object):
            for key in keys {
                if case let .object(match)? = object[key] {
                    return match
                }
            }
            for nested in object.values {
                if let match = findObject(in: nested, keys: keys) {
                    return match
                }
            }
            return nil
        case .array(let array):
            for nested in array {
                if let match = findObject(in: nested, keys: keys) {
                    return match
                }
            }
            return nil
        case .string, .number, .bool, .null:
            return nil
        }
    }

    private static func string(in value: JSONValue?) -> String? {
        value?.stringValue
    }
}

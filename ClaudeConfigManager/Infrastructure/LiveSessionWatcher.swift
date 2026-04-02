import Foundation
import Combine

// MARK: - Live Session State

/// Represents the current state of an actively-running Claude Code session,
/// derived from watching the transcript `.jsonl` file for new appended lines.
struct LiveSessionState: Equatable, Sendable {
    var inputTokensUsed: Int
    var outputTokensUsed: Int
    var contextWindowSize: Int
    var activeToolName: String?
    var activeHookEvent: String?
    var lastUpdated: Date

    var totalTokens: Int {
        inputTokensUsed + outputTokensUsed
    }

    var usedPercentage: Double {
        guard contextWindowSize > 0 else { return 0 }
        return Double(totalTokens) / Double(contextWindowSize) * 100.0
    }
}

// MARK: - File System Abstraction

/// Abstraction over file system operations for testability.
protocol LiveSessionFileSystem: AnyObject, Sendable {
    func fileExists(atPath path: String) -> Bool
    func modificationDate(atPath path: String) -> Date?
    func openFileHandle(atPath path: String) throws -> FileHandle
    func fileDescriptor(for handle: FileHandle) -> Int32
}

final class DefaultLiveSessionFileSystem: LiveSessionFileSystem, @unchecked Sendable {
    func fileExists(atPath path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    func modificationDate(atPath path: String) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date
    }

    func openFileHandle(atPath path: String) throws -> FileHandle {
        try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
    }

    func fileDescriptor(for handle: FileHandle) -> Int32 {
        handle.fileDescriptor
    }
}

// MARK: - Live Session Watcher

/// Watches a Claude Code transcript `.jsonl` file for new appended lines
/// and publishes live session state updates.
///
/// ## Mechanism
///
/// Claude Code does not write a separate status-line JSON file to disk.
/// The status line is output on stdout for terminal integration only.
/// However, the transcript `.jsonl` file IS written incrementally as the
/// session progresses. This watcher monitors that file using
/// `DispatchSource.makeFileSystemObjectSource` to detect writes, then
/// reads newly appended lines to derive live token counts and active
/// tool state.
///
/// ## Usage
///
/// ```swift
/// let watcher = LiveSessionWatcher()
/// watcher.start(transcriptPath: "/path/to/session.jsonl")
/// // Observe watcher.activeSession for live updates
/// watcher.stop()
/// ```
@MainActor
final class LiveSessionWatcher: ObservableObject {

    // MARK: - Published State

    /// The current live session state, or `nil` if no active session is detected.
    @Published private(set) var activeSession: LiveSessionState?

    /// Whether a live session is currently being monitored.
    @Published private(set) var isLive: Bool = false

    /// The path of the transcript file being watched.
    @Published private(set) var watchedTranscriptPath: String?

    // MARK: - Configuration

    /// Maximum age (in seconds) of the last transcript modification before
    /// the session is considered inactive. Default: 5 minutes.
    var inactivityTimeout: TimeInterval = 5 * 60

    /// Polling interval (in seconds) for checking file modifications when
    /// DispatchSource is not available. Default: 2 seconds.
    var pollingInterval: TimeInterval = 2.0

    // MARK: - Private State

    private let fileSystem: LiveSessionFileSystem
    private let nowProvider: () -> Date
    private var fileHandle: FileHandle?
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var pollingTimer: Timer?
    private var fileOffset: UInt64 = 0
    private var accumulatedInputTokens: Int = 0
    private var accumulatedOutputTokens: Int = 0
    private var contextWindowSize: Int = 200_000
    private var currentActiveToolName: String?
    private var currentActiveHookEvent: String?
    private var lastKnownModificationDate: Date?

    // MARK: - Init

    init(
        fileSystem: LiveSessionFileSystem = DefaultLiveSessionFileSystem(),
        nowProvider: @escaping () -> Date = { .now }
    ) {
        self.fileSystem = fileSystem
        self.nowProvider = nowProvider
    }

    // MARK: - Public API

    /// Start watching a transcript file for live updates.
    func start(transcriptPath: String) {
        stop()

        guard fileSystem.fileExists(atPath: transcriptPath) else {
            return
        }

        watchedTranscriptPath = transcriptPath
        resetAccumulatedState()

        // Read existing content to establish baseline
        readExistingContent(atPath: transcriptPath)

        // Set up file watching
        setupFileWatching(atPath: transcriptPath)

        isLive = true
        publishState()
    }

    /// Stop watching the current transcript file.
    func stop() {
        stopInternal()
        activeSession = nil
        isLive = false
        watchedTranscriptPath = nil
    }

    /// Manually trigger a check for new content. Useful for testing.
    func checkForUpdates() {
        guard let path = watchedTranscriptPath else { return }
        readNewLines(atPath: path)
        checkInactivity()
    }

    // MARK: - Private: File Watching

    private func setupFileWatching(atPath path: String) {
        do {
            let handle = try fileSystem.openFileHandle(atPath: path)
            self.fileHandle = handle

            let fd = fileSystem.fileDescriptor(for: handle)
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .extend],
                queue: .main
            )

            source.setEventHandler { [weak self] in
                self?.readNewLines(atPath: path)
            }

            source.setCancelHandler { [weak self] in
                try? self?.fileHandle?.close()
                self?.fileHandle = nil
            }

            source.resume()
            self.dispatchSource = source
        } catch {
            // Fallback to polling if DispatchSource setup fails
            setupPolling(atPath: path)
        }
    }

    private func setupPolling(atPath path: String) {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.readNewLines(atPath: path)
                self?.checkInactivity()
            }
        }
    }

    private func stopInternal() {
        dispatchSource?.cancel()
        dispatchSource = nil
        pollingTimer?.invalidate()
        pollingTimer = nil
        // File handle is closed by the cancel handler
        if dispatchSource == nil {
            try? fileHandle?.close()
            fileHandle = nil
        }
    }

    // MARK: - Private: Reading

    private func readExistingContent(atPath path: String) {
        do {
            let handle = try fileSystem.openFileHandle(atPath: path)
            defer { try? handle.close() }

            var buffer = Data()
            while let chunk = try handle.read(upToCount: 8192), !chunk.isEmpty {
                buffer.append(chunk)
            }

            fileOffset = UInt64(buffer.count)
            if !buffer.isEmpty {
                lastKnownModificationDate = nowProvider()
            }
            processBuffer(buffer)
        } catch {
            // Ignore read errors during initial load
        }
    }

    private func readNewLines(atPath path: String) {
        guard let handle = fileHandle else { return }

        do {
            handle.seek(toFileOffset: fileOffset)
            guard let data = try handle.readToEnd(), !data.isEmpty else {
                return
            }

            fileOffset += UInt64(data.count)
            lastKnownModificationDate = nowProvider()
            processBuffer(data)
            publishState()
        } catch {
            // File may have been truncated or deleted
            checkInactivity()
        }
    }

    private func processBuffer(_ data: Data) {
        var remaining = data

        while let newlineIndex = remaining.firstIndex(of: 0x0A) {
            let lineData = Data(remaining[remaining.startIndex..<newlineIndex])
            remaining = Data(remaining[remaining.index(after: newlineIndex)...])

            let trimmed = lineData.last == 0x0D ? Data(lineData.dropLast()) : lineData
            processLine(trimmed)
        }

        // Don't process incomplete lines — they'll be picked up next read
    }

    private func processLine(_ lineData: Data) {
        guard !lineData.isEmpty else { return }

        guard let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
            return
        }

        let entryType = object["type"] as? String

        // Extract usage tokens
        if let message = object["message"] as? [String: Any],
           let usage = message["usage"] as? [String: Any] {
            if let input = usage["input_tokens"] as? Int {
                accumulatedInputTokens += input
            }
            if let output = usage["output_tokens"] as? Int {
                accumulatedOutputTokens += output
            }
        }

        // Extract context window size if available
        if let contextWindow = object["context_window"] as? [String: Any],
           let size = contextWindow["context_window_size"] as? Int {
            contextWindowSize = size
        }

        // Track active tool usage
        switch entryType {
        case "tool_use":
            let toolName = object["name"] as? String
                ?? (object["message"] as? [String: Any])
                    .flatMap { msg in
                        (msg["content"] as? [[String: Any]])?
                            .first(where: { ($0["type"] as? String) == "tool_use" })?["name"] as? String
                    }
            currentActiveToolName = toolName

        case "tool_result":
            currentActiveToolName = nil

        case "assistant":
            // Check for tool_use blocks inside assistant message content
            if let message = object["message"] as? [String: Any],
               let content = message["content"] as? [[String: Any]] {
                let toolUseBlock = content.first(where: { ($0["type"] as? String) == "tool_use" })
                if let name = toolUseBlock?["name"] as? String {
                    currentActiveToolName = name
                }
            }

        default:
            break
        }

        // Track hook events
        if entryType == "hook_start" {
            currentActiveHookEvent = object["hook_event"] as? String
                ?? object["event"] as? String
        } else if entryType == "hook_end" || entryType == "hook_result" {
            currentActiveHookEvent = nil
        }
    }

    // MARK: - Private: State Management

    private func resetAccumulatedState() {
        accumulatedInputTokens = 0
        accumulatedOutputTokens = 0
        contextWindowSize = 200_000
        currentActiveToolName = nil
        currentActiveHookEvent = nil
        fileOffset = 0
        lastKnownModificationDate = nil
    }

    private func publishState() {
        activeSession = LiveSessionState(
            inputTokensUsed: accumulatedInputTokens,
            outputTokensUsed: accumulatedOutputTokens,
            contextWindowSize: contextWindowSize,
            activeToolName: currentActiveToolName,
            activeHookEvent: currentActiveHookEvent,
            lastUpdated: nowProvider()
        )
    }

    private func checkInactivity() {
        guard let lastMod = lastKnownModificationDate else { return }

        let elapsed = nowProvider().timeIntervalSince(lastMod)
        if elapsed > inactivityTimeout {
            isLive = false
        }
    }
}

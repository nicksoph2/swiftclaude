import XCTest
@testable import ClaudeConfigManager

// MARK: - Mock File System

private final class MockLiveSessionFileSystem: LiveSessionFileSystem, @unchecked Sendable {
    var existingFiles: Set<String> = []
    var modificationDates: [String: Date] = [:]
    var fileContents: [String: Data] = [:]
    var openedHandles: [String: FileHandle] = [:]

    func fileExists(atPath path: String) -> Bool {
        existingFiles.contains(path)
    }

    func modificationDate(atPath path: String) -> Date? {
        modificationDates[path]
    }

    func openFileHandle(atPath path: String) throws -> FileHandle {
        if let handle = openedHandles[path] {
            return handle
        }
        guard let data = fileContents[path] else {
            throw NSError(domain: "MockFS", code: 1, userInfo: [NSLocalizedDescriptionKey: "File not found: \(path)"])
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jsonl")
        try data.write(to: tempURL)
        let handle = try FileHandle(forReadingFrom: tempURL)
        openedHandles[path] = handle
        return handle
    }

    func fileDescriptor(for handle: FileHandle) -> Int32 {
        handle.fileDescriptor
    }

    func cleanup() {
        for handle in openedHandles.values {
            try? handle.close()
        }
        openedHandles.removeAll()
    }
}

// MARK: - Tests

@MainActor
final class LiveSessionWatcherTests: XCTestCase {

    private var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try await super.tearDown()
    }

    // MARK: - Test: Detects new lines and updates token counts

    func testLiveSessionWatcherDetectsNewLines() async throws {
        let transcriptPath = tempDirectory.appendingPathComponent("session.jsonl")

        // Write initial content
        let line1 = """
        {"type":"human","message":{"role":"user","content":"Hello"}}
        """
        let line2 = """
        {"type":"assistant","message":{"role":"assistant","model":"claude-opus-4-6","content":"Hi there!","usage":{"input_tokens":100,"output_tokens":25}}}
        """
        let initialContent = line1 + "\n" + line2 + "\n"
        try initialContent.write(to: transcriptPath, atomically: true, encoding: .utf8)

        let watcher = LiveSessionWatcher()
        watcher.start(transcriptPath: transcriptPath.path)

        XCTAssertTrue(watcher.isLive)
        XCTAssertNotNil(watcher.activeSession)
        XCTAssertEqual(watcher.activeSession?.inputTokensUsed, 100)
        XCTAssertEqual(watcher.activeSession?.outputTokensUsed, 25)

        watcher.stop()
        XCTAssertFalse(watcher.isLive)
        XCTAssertNil(watcher.activeSession)
    }

    // MARK: - Test: Tracks active tool name

    func testLiveSessionWatcherTracksActiveTool() async throws {
        let transcriptPath = tempDirectory.appendingPathComponent("session.jsonl")

        let lines = [
            #"{"type":"human","message":{"role":"user","content":"Read file"}}"#,
            #"{"type":"tool_use","name":"Read","input":{"path":"/tmp/test.txt"}}"#,
        ]
        let content = lines.joined(separator: "\n") + "\n"
        try content.write(to: transcriptPath, atomically: true, encoding: .utf8)

        let watcher = LiveSessionWatcher()
        watcher.start(transcriptPath: transcriptPath.path)

        XCTAssertEqual(watcher.activeSession?.activeToolName, "Read")

        watcher.stop()
    }

    // MARK: - Test: Tool result clears active tool

    func testLiveSessionWatcherClearsToolOnResult() async throws {
        let transcriptPath = tempDirectory.appendingPathComponent("session.jsonl")

        let lines = [
            #"{"type":"tool_use","name":"Bash","input":{"command":"ls"}}"#,
            #"{"type":"tool_result","content":"file1.txt"}"#,
        ]
        let content = lines.joined(separator: "\n") + "\n"
        try content.write(to: transcriptPath, atomically: true, encoding: .utf8)

        let watcher = LiveSessionWatcher()
        watcher.start(transcriptPath: transcriptPath.path)

        XCTAssertNil(watcher.activeSession?.activeToolName)

        watcher.stop()
    }

    // MARK: - Test: No active session when file doesn't exist

    func testNoActiveSessionWhenFileDoesNotExist() async throws {
        let watcher = LiveSessionWatcher()
        watcher.start(transcriptPath: "/nonexistent/path/session.jsonl")

        XCTAssertFalse(watcher.isLive)
        XCTAssertNil(watcher.activeSession)
    }

    // MARK: - Test: Accumulates tokens across multiple entries

    func testAccumulatesTokensAcrossEntries() async throws {
        let transcriptPath = tempDirectory.appendingPathComponent("session.jsonl")

        let lines = [
            #"{"type":"assistant","message":{"role":"assistant","usage":{"input_tokens":50,"output_tokens":10}}}"#,
            #"{"type":"assistant","message":{"role":"assistant","usage":{"input_tokens":75,"output_tokens":20}}}"#,
        ]
        let content = lines.joined(separator: "\n") + "\n"
        try content.write(to: transcriptPath, atomically: true, encoding: .utf8)

        let watcher = LiveSessionWatcher()
        watcher.start(transcriptPath: transcriptPath.path)

        XCTAssertEqual(watcher.activeSession?.inputTokensUsed, 125)
        XCTAssertEqual(watcher.activeSession?.outputTokensUsed, 30)
        XCTAssertEqual(watcher.activeSession?.totalTokens, 155)

        watcher.stop()
    }

    // MARK: - Test: Handles malformed JSON lines gracefully

    func testHandlesMalformedJsonLines() async throws {
        let transcriptPath = tempDirectory.appendingPathComponent("session.jsonl")

        let lines = [
            #"{"type":"assistant","message":{"role":"assistant","usage":{"input_tokens":50,"output_tokens":10}}}"#,
            "not valid json at all",
            #"{"type":"assistant","message":{"role":"assistant","usage":{"input_tokens":25,"output_tokens":5}}}"#,
        ]
        let content = lines.joined(separator: "\n") + "\n"
        try content.write(to: transcriptPath, atomically: true, encoding: .utf8)

        let watcher = LiveSessionWatcher()
        watcher.start(transcriptPath: transcriptPath.path)

        // Should accumulate tokens from valid lines, ignoring invalid
        XCTAssertEqual(watcher.activeSession?.inputTokensUsed, 75)
        XCTAssertEqual(watcher.activeSession?.outputTokensUsed, 15)

        watcher.stop()
    }

    // MARK: - Test: Stop resets all state

    func testStopResetsState() async throws {
        let transcriptPath = tempDirectory.appendingPathComponent("session.jsonl")
        try #"{"type":"assistant","message":{"usage":{"input_tokens":50,"output_tokens":10}}}"#
            .appending("\n")
            .write(to: transcriptPath, atomically: true, encoding: .utf8)

        let watcher = LiveSessionWatcher()
        watcher.start(transcriptPath: transcriptPath.path)

        XCTAssertTrue(watcher.isLive)
        XCTAssertNotNil(watcher.activeSession)

        watcher.stop()

        XCTAssertFalse(watcher.isLive)
        XCTAssertNil(watcher.activeSession)
        XCTAssertNil(watcher.watchedTranscriptPath)
    }

    // MARK: - Test: Inactivity detection

    func testInactivityDisablesLiveFlag() async throws {
        let transcriptPath = tempDirectory.appendingPathComponent("session.jsonl")
        try #"{"type":"human","message":{"content":"test"}}"#
            .appending("\n")
            .write(to: transcriptPath, atomically: true, encoding: .utf8)

        var currentTime = Date(timeIntervalSince1970: 1000)
        let watcher = LiveSessionWatcher(nowProvider: { currentTime })
        watcher.inactivityTimeout = 10 // 10 seconds for testing

        watcher.start(transcriptPath: transcriptPath.path)
        XCTAssertTrue(watcher.isLive)

        // Advance time past inactivity timeout
        currentTime = Date(timeIntervalSince1970: 1020)
        watcher.checkForUpdates()

        XCTAssertFalse(watcher.isLive)
    }
}

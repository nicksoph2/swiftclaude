import XCTest
@testable import ClaudeConfigManager

final class AtomicFileWriterTests: XCTestCase {
    private var tempDir: URL!
    private var testFileURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Create temp directory for test files
        let tempDirPath = NSTemporaryDirectory().appending("AtomicWriterTests_\(UUID().uuidString)")
        tempDir = URL(fileURLWithPath: tempDirPath, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        testFileURL = tempDir.appendingPathComponent("settings.json")
    }

    override func tearDownWithError() throws {
        // Clean up temp directory
        if let tempDir = tempDir, FileManager.default.fileExists(atPath: tempDir.path) {
            try FileManager.default.removeItem(at: tempDir)
        }

        try super.tearDownWithError()
    }

    // MARK: - FileBackupStore Tests

    func testBackupCreatesBackupFile() throws {
        // Create original file
        let originalContent = "{ \"model\": \"claude-opus\" }"
        try originalContent.write(to: testFileURL, atomically: true, encoding: .utf8)

        let backupStore = FileBackupStore()
        let backupURL = try backupStore.backup(testFileURL)

        // Verify backup file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))

        // Verify backup contains original content
        let backupContent = try String(contentsOf: backupURL, encoding: .utf8)
        XCTAssertEqual(backupContent, originalContent)
    }

    func testRestoreRestoresOriginalFile() throws {
        // Create original file
        let originalContent = "{ \"model\": \"claude-opus\" }"
        try originalContent.write(to: testFileURL, atomically: true, encoding: .utf8)

        let backupStore = FileBackupStore()
        _ = try backupStore.backup(testFileURL)

        // Modify the file
        let modifiedContent = "{ \"model\": \"claude-sonnet\" }"
        try modifiedContent.write(to: testFileURL, atomically: true, encoding: .utf8)

        // Restore from backup
        try backupStore.restore(testFileURL)

        // Verify file is restored
        let restoredContent = try String(contentsOf: testFileURL, encoding: .utf8)
        XCTAssertEqual(restoredContent, originalContent)
    }

    func testClearRemovesBackupFile() throws {
        // Create original file
        let originalContent = "{ \"model\": \"claude-opus\" }"
        try originalContent.write(to: testFileURL, atomically: true, encoding: .utf8)

        let backupStore = FileBackupStore()
        let backupURL = try backupStore.backup(testFileURL)

        // Clear the backup
        backupStore.clear(testFileURL)

        // Verify backup is removed
        XCTAssertFalse(FileManager.default.fileExists(atPath: backupURL.path))
    }

    // MARK: - JSONKeyPathMutator Tests

    func testDotNotationKeyPathSet() throws {
        let mutator = JSONKeyPathMutator()
        let root: JSONValue = .object(["permissions": .object(["allow": .array([])])])

        let change = SettingsChange(
            keyPath: "permissions.deny",
            newValue: .array([.string("Bash(rm -rf /)")]),
            operation: .set
        )

        let result = try mutator.apply(change, to: root)

        guard case let .object(obj) = result else {
            XCTFail("Result should be object")
            return
        }

        guard case let .object(permissions) = obj["permissions"] else {
            XCTFail("permissions should be object")
            return
        }

        let deny = permissions["deny"]
        XCTAssertEqual(deny, .array([.string("Bash(rm -rf /)")]))
    }

    func testDotNotationKeyPathSetCreatesIntermediateObjects() throws {
        let mutator = JSONKeyPathMutator()
        let root: JSONValue = .object([:])

        let change = SettingsChange(
            keyPath: "permissions.deny",
            newValue: .array([.string("Bash(rm -rf /)")]),
            operation: .set
        )

        let result = try mutator.apply(change, to: root)

        guard case let .object(obj) = result else {
            XCTFail("Result should be object")
            return
        }

        guard case let .object(permissions) = obj["permissions"] else {
            XCTFail("permissions should be object")
            return
        }

        let deny = permissions["deny"]
        XCTAssertEqual(deny, .array([.string("Bash(rm -rf /)")]))
    }

    func testArrayAppend() throws {
        let mutator = JSONKeyPathMutator()
        let root: JSONValue = .object(["allowedHTTPHookURLs": .array([.string("https://example.com/a")])])

        let change = SettingsChange(
            keyPath: "allowedHTTPHookURLs",
            newValue: .string("https://example.com/b"),
            operation: .appendToArray(.string("https://example.com/b"))
        )

        let result = try mutator.apply(change, to: root)

        guard case let .object(obj) = result else {
            XCTFail("Result should be object")
            return
        }

        guard case let .array(urls) = obj["allowedHTTPHookURLs"] else {
            XCTFail("allowedHTTPHookURLs should be array")
            return
        }

        XCTAssertEqual(urls.count, 2)
        XCTAssertTrue(urls.contains(.string("https://example.com/a")))
        XCTAssertTrue(urls.contains(.string("https://example.com/b")))
    }

    func testArrayAppendToNonExistentArrayCreatesArray() throws {
        let mutator = JSONKeyPathMutator()
        let root: JSONValue = .object([:])

        let change = SettingsChange(
            keyPath: "allowedHTTPHookURLs",
            newValue: .string("https://example.com/a"),
            operation: .appendToArray(.string("https://example.com/a"))
        )

        let result = try mutator.apply(change, to: root)

        guard case let .object(obj) = result else {
            XCTFail("Result should be object")
            return
        }

        guard case let .array(urls) = obj["allowedHTTPHookURLs"] else {
            XCTFail("allowedHTTPHookURLs should be array")
            return
        }

        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls[0], .string("https://example.com/a"))
    }

    func testArrayRemove() throws {
        let mutator = JSONKeyPathMutator()
        let root: JSONValue = .object([
            "allowedHTTPHookURLs": .array([
                .string("https://example.com/a"),
                .string("https://example.com/b"),
                .string("https://example.com/c")
            ])
        ])

        let change = SettingsChange(
            keyPath: "allowedHTTPHookURLs",
            newValue: .null,
            operation: .removeFromArray(.string("https://example.com/b"))
        )

        let result = try mutator.apply(change, to: root)

        guard case let .object(obj) = result else {
            XCTFail("Result should be object")
            return
        }

        guard case let .array(urls) = obj["allowedHTTPHookURLs"] else {
            XCTFail("allowedHTTPHookURLs should be array")
            return
        }

        XCTAssertEqual(urls.count, 2)
        XCTAssertFalse(urls.contains(.string("https://example.com/b")))
        XCTAssertTrue(urls.contains(.string("https://example.com/a")))
        XCTAssertTrue(urls.contains(.string("https://example.com/c")))
    }

    func testRemoveAtKeyPath() throws {
        let mutator = JSONKeyPathMutator()
        let root: JSONValue = .object([
            "permissions": .object([
                "allow": .array([.string("Bash(ls)")]),
                "deny": .array([.string("Bash(rm)")])
            ])
        ])

        let change = SettingsChange(
            keyPath: "permissions.deny",
            newValue: .null,
            operation: .remove
        )

        let result = try mutator.apply(change, to: root)

        guard case let .object(obj) = result else {
            XCTFail("Result should be object")
            return
        }

        guard case let .object(permissions) = obj["permissions"] else {
            XCTFail("permissions should be object")
            return
        }

        // deny should be removed
        XCTAssertNil(permissions["deny"])
        // allow should still be there
        XCTAssertNotNil(permissions["allow"])
    }

    func testSetNestedDeepPath() throws {
        let mutator = JSONKeyPathMutator()
        let root: JSONValue = .object([:])

        let change = SettingsChange(
            keyPath: "a.b.c.d",
            newValue: .string("value"),
            operation: .set
        )

        let result = try mutator.apply(change, to: root)

        guard case let .object(obj) = result else {
            XCTFail("Result should be object")
            return
        }

        guard case let .object(a) = obj["a"] else {
            XCTFail("a should be object")
            return
        }

        guard case let .object(b) = a["b"] else {
            XCTFail("b should be object")
            return
        }

        guard case let .object(c) = b["c"] else {
            XCTFail("c should be object")
            return
        }

        XCTAssertEqual(c["d"], .string("value"))
    }
}

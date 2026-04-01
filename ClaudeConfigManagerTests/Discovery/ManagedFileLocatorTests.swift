import XCTest
@testable import ClaudeConfigManager

final class ManagedFileLocatorTests: XCTestCase {
    // MARK: - Part A: File Discovery Tests

    func testAllFilesAbsentProducesEmptyResult() {
        let managedRootPath = "/Library/Application Support/ClaudeCode"
        let fileSystem = MockManagedSettingsFileSystem(
            existingPaths: [],
            directoryPaths: [],
            unreadablePaths: [],
            directoryContentsByPath: [:]
        )
        let mdmReader = MockMDMPolicyReader()
        let locator = ManagedFileLocator(fileSystem: fileSystem, mdmReader: mdmReader)

        let result = locator.locate()

        XCTAssertNil(result.settingsFile)
        XCTAssertNil(result.mcpFile)
        XCTAssertNil(result.claudeMdFile)
        XCTAssertTrue(result.settingsOverrideFiles.isEmpty)
        XCTAssertNil(result.mdmResult)
    }

    func testSettingsFileFoundWhenPresent() {
        let managedRootPath = "/Library/Application Support/ClaudeCode"
        let settingsPath = managedRootPath + "/managed-settings.json"
        let fileSystem = MockManagedSettingsFileSystem(
            existingPaths: [settingsPath],
            directoryPaths: [managedRootPath],
            unreadablePaths: [],
            directoryContentsByPath: [:]
        )
        let mdmReader = MockMDMPolicyReader()
        let locator = ManagedFileLocator(fileSystem: fileSystem, mdmReader: mdmReader)

        let result = locator.locate()

        XCTAssertNotNil(result.settingsFile)
        XCTAssertEqual(result.settingsFile?.kind, .managedSettingsJSON)
        XCTAssertEqual(result.settingsFile?.status, .present)
    }

    func testOverrideDirSortedLexicographically() {
        let managedRootPath = "/Library/Application Support/ClaudeCode"
        let dropInDir = managedRootPath + "/managed-settings.d"
        let fileA = dropInDir + "/a-file.json"
        let fileM = dropInDir + "/m-file.json"
        let fileZ = dropInDir + "/z-file.json"

        let fileSystem = MockManagedSettingsFileSystem(
            existingPaths: [managedRootPath, dropInDir, fileA, fileM, fileZ],
            directoryPaths: [managedRootPath, dropInDir],
            unreadablePaths: [],
            directoryContentsByPath: [
                dropInDir: [
                    "z-file.json",
                    "a-file.json",
                    "m-file.json"
                ]
            ]
        )
        let mdmReader = MockMDMPolicyReader()
        let locator = ManagedFileLocator(fileSystem: fileSystem, mdmReader: mdmReader)

        let result = locator.locate()

        XCTAssertEqual(result.settingsOverrideFiles.count, 3)
        let fileNames = result.settingsOverrideFiles.map { $0.url.lastPathComponent }
        XCTAssertEqual(fileNames, ["a-file.json", "m-file.json", "z-file.json"])
    }

    // MARK: - Part B: MDM Reading Tests

    func testMDMReaderReturnsNilWhenDomainAbsent() {
        let fileSystem = MockManagedSettingsFileSystem()
        let mdmReader = MockMDMPolicyReader(policies: nil)
        let locator = ManagedFileLocator(fileSystem: fileSystem, mdmReader: mdmReader)

        let result = locator.locate()

        XCTAssertNil(result.mdmResult)
    }

    func testMDMValueNormalisationBool() {
        let fileSystem = MockManagedSettingsFileSystem()
        let mdmReader = MockMDMPolicyReader(
            policies: ["enable_feature": .bool(true)]
        )
        let locator = ManagedFileLocator(fileSystem: fileSystem, mdmReader: mdmReader)

        let result = locator.locate()

        XCTAssertNotNil(result.mdmResult)
        XCTAssertEqual(result.mdmResult?.source, "MDM (com.anthropic.claudecode)")
        XCTAssertEqual(result.mdmResult?.values["enable_feature"], .bool(true))
    }

    func testMDMValueNormalisationNumber() {
        let fileSystem = MockManagedSettingsFileSystem()
        let mdmReader = MockMDMPolicyReader(
            policies: ["timeout_seconds": .number(30.0)]
        )
        let locator = ManagedFileLocator(fileSystem: fileSystem, mdmReader: mdmReader)

        let result = locator.locate()

        XCTAssertNotNil(result.mdmResult)
        XCTAssertEqual(result.mdmResult?.values["timeout_seconds"], .number(30.0))
    }

    func testMDMValueNormalisationString() {
        let fileSystem = MockManagedSettingsFileSystem()
        let mdmReader = MockMDMPolicyReader(
            policies: ["server_url": .string("https://api.example.com")]
        )
        let locator = ManagedFileLocator(fileSystem: fileSystem, mdmReader: mdmReader)

        let result = locator.locate()

        XCTAssertNotNil(result.mdmResult)
        XCTAssertEqual(result.mdmResult?.values["server_url"], .string("https://api.example.com"))
    }

    func testMDMValueNormalisationArray() {
        let fileSystem = MockManagedSettingsFileSystem()
        let mdmReader = MockMDMPolicyReader(
            policies: ["allowed_domains": .array([.string("example.com"), .string("test.org")])]
        )
        let locator = ManagedFileLocator(fileSystem: fileSystem, mdmReader: mdmReader)

        let result = locator.locate()

        XCTAssertNotNil(result.mdmResult)
        XCTAssertEqual(
            result.mdmResult?.values["allowed_domains"],
            .array([.string("example.com"), .string("test.org")])
        )
    }

    func testMDMValueNormalisationObject() {
        let fileSystem = MockManagedSettingsFileSystem()
        let mdmReader = MockMDMPolicyReader(
            policies: [
                "settings": .object([
                    "key1": .string("value1"),
                    "key2": .number(42.0)
                ])
            ]
        )
        let locator = ManagedFileLocator(fileSystem: fileSystem, mdmReader: mdmReader)

        let result = locator.locate()

        XCTAssertNotNil(result.mdmResult)
        XCTAssertEqual(
            result.mdmResult?.values["settings"],
            .object([
                "key1": .string("value1"),
                "key2": .number(42.0)
            ])
        )
    }

    func testMDMReturnsNilWhenPoliciesAreEmpty() {
        let fileSystem = MockManagedSettingsFileSystem()
        let mdmReader = MockMDMPolicyReader(policies: [:])
        let locator = ManagedFileLocator(fileSystem: fileSystem, mdmReader: mdmReader)

        let result = locator.locate()

        XCTAssertNil(result.mdmResult)
    }

    // MARK: - Helpers
}

// MARK: - Mocks

private struct MockManagedSettingsFileSystem: ManagedSettingsFileSystem {
    private let existingPaths: Set<String>
    private let directoryPaths: Set<String>
    private let unreadablePaths: Set<String>
    private let directoryContentsByPath: [String: [String]]

    init(baseURL: URL? = nil) {
        self.existingPaths = []
        self.directoryPaths = []
        self.unreadablePaths = []
        self.directoryContentsByPath = [:]
    }

    init(
        existingPaths: Set<String> = [],
        directoryPaths: Set<String> = [],
        unreadablePaths: Set<String> = [],
        directoryContentsByPath: [String: [String]] = [:]
    ) {
        self.existingPaths = Set(existingPaths.map { RootLocator.normalizedIdentityPath($0) })
        self.directoryPaths = Set(directoryPaths.map { RootLocator.normalizedIdentityPath($0) })
        self.unreadablePaths = Set(unreadablePaths.map { RootLocator.normalizedIdentityPath($0) })
        self.directoryContentsByPath = Dictionary(
            uniqueKeysWithValues: directoryContentsByPath.map { (RootLocator.normalizedIdentityPath($0.key), $0.value) }
        )
    }

    func fileExists(atPath: String) -> Bool {
        existingPaths.contains(normalized(atPath))
    }

    func isReadable(atPath: String) -> Bool {
        existingPaths.contains(normalized(atPath)) && !unreadablePaths.contains(normalized(atPath))
    }

    func contentsOfDirectory(atPath: String, error: inout NSError?) -> [String] {
        directoryContentsByPath[normalized(atPath)] ?? []
    }

    func fileExists(atPath: String, isDirectory: inout ObjCBool) -> Bool {
        let path = normalized(atPath)
        let exists = existingPaths.contains(path)
        isDirectory = ObjCBool(directoryPaths.contains(path))
        return exists
    }

    private func normalized(_ path: String) -> String {
        RootLocator.normalizedIdentityPath(path)
    }
}

private struct MockMDMPolicyReader: MDMPolicyReading {
    private let policies: [String: JSONValue]?

    init(policies: [String: JSONValue]? = nil) {
        self.policies = policies
    }

    func readPolicies() -> ParseResult<[String: JSONValue]> {
        ParseResult(value: policies ?? [:], issues: [])
    }
}

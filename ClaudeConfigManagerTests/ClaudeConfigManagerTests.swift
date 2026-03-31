import XCTest
@testable import ClaudeConfigManager

final class ClaudeConfigManagerTests: XCTestCase {
    func testSidebarDestinationsExposeExpectedOrder() {
        XCTAssertEqual(
            SidebarDestination.allCases,
            [.managed, .user, .project, .session]
        )
    }

    func testScopeScreenModelUsesSidebarCopy() {
        let model = ScopeScreenModel(destination: .session)

        XCTAssertEqual(model.title, "Session")
        XCTAssertTrue(model.subtitle.contains("read-only"))
    }
}

final class FixtureLayoutContractTests: XCTestCase {
    func testFixtureContractContainsAllRequiredTopLevelFamilies() {
        let loader = FixtureLoader.shared
        let requiredFamilies = ["parsers", "resolvers", "validation", "session", "shared"]

        for family in requiredFamilies {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: loader.rootURL.appendingPathComponent(family).path),
                "Missing fixture family directory: \(family)"
            )
        }
    }

    func testParserFixtureSetIncludesValidAndInvalidPairedCases() throws {
        let loader = FixtureLoader.shared
        let validDescriptor = try loader.descriptor(familyPath: "parsers/settings", caseID: "valid_basic")
        let invalidDescriptor = try loader.descriptor(familyPath: "parsers/settings", caseID: "invalid_json_trailing_comma")

        XCTAssertTrue(FileManager.default.fileExists(atPath: validDescriptor.inputDirectoryURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: validDescriptor.expectedDirectoryURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: invalidDescriptor.inputDirectoryURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: invalidDescriptor.expectedDirectoryURL.path))
    }

    func testExpectedIssueSetLoadsDeterministicallyFromValidationFixture() throws {
        let loader = FixtureLoader.shared
        let issueSet = try loader.loadExpectedIssueSet(
            familyPath: "validation/settings",
            caseID: "permissions_allow_deny_overlap",
            fileName: "validation_issues.json"
        )
        XCTAssertEqual(
            issueSet.codes,
            ["schema.settings.permissionsAllowDenyOverlap", "schema.settings.permissionsModeWithAllowDeny"]
        )
    }

    func testResolverAndSessionFixtureExamplesArePresent() throws {
        let loader = FixtureLoader.shared
        let resolverDescriptor = try loader.descriptor(familyPath: "resolvers/settings", caseID: "override_project_wins")
        let sessionDescriptor = try loader.descriptor(familyPath: "session", caseID: "mixed_valid_invalid")

        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: resolverDescriptor.expectedSnapshot(named: "resolved_snapshot.json").url.path
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: sessionDescriptor.expectedSnapshot(named: "projection_summary.json").url.path
            )
        )
    }
}

struct FixtureCaseID: RawRepresentable, Hashable, Codable, ExpressibleByStringLiteral, CustomStringConvertible {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: String) {
        self.rawValue = value
    }

    var description: String {
        rawValue
    }
}

struct ExpectedSnapshotReference: Equatable {
    enum Format: String {
        case json
        case text
    }

    let url: URL
    let format: Format
}

struct ExpectedIssueSet: Codable, Equatable {
    let codes: [String]
}

struct FixtureDescriptor: Equatable {
    let familyPath: String
    let caseID: FixtureCaseID
    let caseURL: URL
    let inputDirectoryURL: URL
    let expectedDirectoryURL: URL

    func inputFileURL(named fileName: String) -> URL {
        inputDirectoryURL.appendingPathComponent(fileName, isDirectory: false)
    }

    func expectedSnapshot(named fileName: String) -> ExpectedSnapshotReference {
        let url = expectedDirectoryURL.appendingPathComponent(fileName, isDirectory: false)
        let format: ExpectedSnapshotReference.Format = url.pathExtension.lowercased() == "json" ? .json : .text
        return ExpectedSnapshotReference(url: url, format: format)
    }
}

final class FixtureLoader {
    static let shared = FixtureLoader()

    let rootURL: URL
    private let fileManager: FileManager

    init(
        rootURL: URL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true),
        fileManager: FileManager = .default
    ) {
        self.rootURL = rootURL
        self.fileManager = fileManager
    }

    func descriptor(familyPath: String, caseID: FixtureCaseID) throws -> FixtureDescriptor {
        let familyURL = rootURL.appendingPathComponent(familyPath, isDirectory: true)
        let caseURL = familyURL.appendingPathComponent(caseID.rawValue, isDirectory: true)
        let inputDirectoryURL = caseURL.appendingPathComponent("input", isDirectory: true)
        let expectedDirectoryURL = caseURL.appendingPathComponent("expected", isDirectory: true)

        guard fileManager.fileExists(atPath: caseURL.path) else {
            throw NSError(
                domain: "FixtureLoader",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Fixture case not found at \(caseURL.path)"]
            )
        }
        guard fileManager.fileExists(atPath: inputDirectoryURL.path) else {
            throw NSError(
                domain: "FixtureLoader",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Fixture input directory missing at \(inputDirectoryURL.path)"]
            )
        }
        guard fileManager.fileExists(atPath: expectedDirectoryURL.path) else {
            throw NSError(
                domain: "FixtureLoader",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Fixture expected directory missing at \(expectedDirectoryURL.path)"]
            )
        }

        return FixtureDescriptor(
            familyPath: familyPath,
            caseID: caseID,
            caseURL: caseURL,
            inputDirectoryURL: inputDirectoryURL,
            expectedDirectoryURL: expectedDirectoryURL
        )
    }

    func loadString(familyPath: String, caseID: FixtureCaseID, section: String, fileName: String) throws -> String {
        let descriptor = try descriptor(familyPath: familyPath, caseID: caseID)
        let fileURL: URL
        switch section {
        case "input":
            fileURL = descriptor.inputFileURL(named: fileName)
        case "expected":
            fileURL = descriptor.expectedSnapshot(named: fileName).url
        default:
            throw NSError(
                domain: "FixtureLoader",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Unsupported fixture section '\(section)'"]
            )
        }
        return try String(contentsOf: fileURL, encoding: .utf8)
    }

    func loadExpectedIssueSet(familyPath: String, caseID: FixtureCaseID, fileName: String) throws -> ExpectedIssueSet {
        let content = try loadString(
            familyPath: familyPath,
            caseID: caseID,
            section: "expected",
            fileName: fileName
        )
        let data = Data(content.utf8)
        return try JSONDecoder().decode(ExpectedIssueSet.self, from: data)
    }
}

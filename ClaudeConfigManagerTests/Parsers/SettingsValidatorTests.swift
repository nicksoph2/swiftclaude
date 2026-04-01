import XCTest
@testable import ClaudeConfigManager

final class SettingsValidatorTests: XCTestCase {
    private let validator = SettingsValidator()
    private let sourceURL = URL(fileURLWithPath: "/tmp/settings.json", isDirectory: false)
    private let parser = SettingsParser()

    /// Test that a managed-only key at user scope emits scopeRestrictionViolated
    func testManagedOnlyKeyAtUserScope() throws {
        let jsonString = """
        {
            "allowManagedPermissionRulesOnly": true
        }
        """
        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL, scope: .user)

        let document = try XCTUnwrap(result.value)
        let scopeViolationIssue = result.issues.first(where: { $0.code == .scopeRestrictionViolated })

        XCTAssertNotNil(scopeViolationIssue)
        XCTAssertEqual(scopeViolationIssue?.severity, .error)
        XCTAssertEqual(scopeViolationIssue?.keyPath, "allowManagedPermissionRulesOnly")
    }

    /// Test that an invalid enum value emits invalidEnumValue
    func testInvalidEnumValue() throws {
        let jsonString = """
        {
            "outputStyle": "xml"
        }
        """
        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL, scope: .user)

        let enumValueIssue = result.issues.first(where: { $0.code == .invalidEnumValue })

        XCTAssertNotNil(enumValueIssue)
        XCTAssertEqual(enumValueIssue?.severity, .error)
        XCTAssertEqual(enumValueIssue?.keyPath, "outputStyle")
    }

    /// Test that an unknown key emits unknownKey at info level
    func testUnknownKeyEmitsInfoIssue() throws {
        let jsonString = """
        {
            "unknownProperty": "value"
        }
        """
        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL, scope: .user)

        let unknownKeyIssue = result.issues.first(where: { $0.code == .unknownKey })

        XCTAssertNotNil(unknownKeyIssue)
        XCTAssertEqual(unknownKeyIssue?.severity, .info)
        XCTAssertEqual(unknownKeyIssue?.keyPath, "unknownProperty")
    }

    /// Test that deprecated key emits deprecatedKey at info level
    func testDeprecatedKeyEmitsInfo() throws {
        let jsonString = """
        {
            "includeCoAuthoredBy": true
        }
        """
        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL, scope: .user)

        let deprecatedKeyIssue = result.issues.first(where: { $0.code == .deprecatedKey })

        XCTAssertNotNil(deprecatedKeyIssue)
        XCTAssertEqual(deprecatedKeyIssue?.severity, .info)
        XCTAssertEqual(deprecatedKeyIssue?.keyPath, "includeCoAuthoredBy")
    }

    /// Test that mutually exclusive keys emit mutuallyExclusiveKeys error
    func testMutuallyExclusiveKeys() throws {
        let jsonString = """
        {
            "includeCoAuthoredBy": true,
            "attribution": {
                "commit": "Co-authored-by: {name} <{email}>"
            }
        }
        """
        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL, scope: .user)

        let mutualExclusiveIssue = result.issues.first(where: { $0.code == .mutuallyExclusiveKeys })

        XCTAssertNotNil(mutualExclusiveIssue)
        XCTAssertEqual(mutualExclusiveIssue?.severity, .error)
    }

    /// Test that a valid document at appropriate scope emits no error/warning issues
    func testValidDocumentEmitsNoErrors() throws {
        let jsonString = """
        {
            "schema": "https://example.com/schema",
            "model": "claude-sonnet-4-6",
            "autoMode": true
        }
        """
        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL, scope: .user)

        let errorIssues = result.issues.filter { $0.severity == .error || $0.severity == .warning }

        XCTAssertTrue(errorIssues.isEmpty)
    }

    /// Test that enum validation (bespoke key) only runs when scope is provided
    func testValidationRequiresScope() throws {
        // outputStyle is in the parser's bespoke validation list — type/enum
        // validation for it is deferred to SettingsValidator (scope-dependent)
        let jsonString = """
        {
            "outputStyle": "xml"
        }
        """
        let resultWithoutScope = parser.parse(jsonString: jsonString, sourceURL: sourceURL, scope: nil)
        let resultWithScope = parser.parse(jsonString: jsonString, sourceURL: sourceURL, scope: .user)

        // Without scope, SettingsValidator doesn't run — no invalidEnumValue
        let enumIssuesWithoutScope = resultWithoutScope.issues.filter { $0.code == .invalidEnumValue }
        XCTAssertTrue(enumIssuesWithoutScope.isEmpty)

        // With scope, SettingsValidator runs and catches the invalid enum value
        let enumIssuesWithScope = resultWithScope.issues.filter { $0.code == .invalidEnumValue }
        XCTAssertFalse(enumIssuesWithScope.isEmpty)
    }

    /// Test that managed scope allows managed-only keys
    func testManagedOnlyKeyAtManagedScope() throws {
        let jsonString = """
        {
            "allowManagedPermissionRulesOnly": true
        }
        """
        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL, scope: .managed)

        let scopeViolationIssue = result.issues.first(where: { $0.code == .scopeRestrictionViolated })

        XCTAssertNil(scopeViolationIssue)
    }

    /// Test that invalid type emits invalidFieldType error
    func testInvalidFieldType() throws {
        let jsonString = """
        {
            "autoMode": "true"
        }
        """
        let result = parser.parse(jsonString: jsonString, sourceURL: sourceURL, scope: .user)

        let typeIssue = result.issues.first(where: { $0.code == .invalidFieldType })

        XCTAssertNotNil(typeIssue)
        XCTAssertEqual(typeIssue?.severity, .error)
        XCTAssertEqual(typeIssue?.keyPath, "autoMode")
    }
}

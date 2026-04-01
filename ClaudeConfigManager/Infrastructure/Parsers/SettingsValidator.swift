import Foundation

struct SettingsValidator {
    private let registry: SettingsKeyRegistry

    init(registry: SettingsKeyRegistry = .shared) {
        self.registry = registry
    }

    /// Validate a parsed SettingsDocument against the key registry.
    /// Returns an array of SyntaxIssues — does not throw.
    func validate(_ document: ParsedSettingsDocument, at scope: ResolutionScope) -> [SyntaxIssue] {
        var issues: [SyntaxIssue] = []
        let sourcePath = document.source.displayPath

        // Validate each key against the registry
        for (key, value) in document.rawTopLevelObject {
            // Check if key is known
            if let definition = registry.definition(for: key) {
                // Validate scope restriction
                if definition.isManagedOnly && scope != .managed {
                    issues.append(SyntaxIssue(
                        code: .scopeRestrictionViolated,
                        severity: .error,
                        message: "Key '\(key)' is managed-only but found at scope '\(scope.rawValue)'",
                        sourcePath: sourcePath,
                        keyPath: key
                    ))
                }

                // Validate type matches
                if !definition.type.matches(value) {
                    issues.append(SyntaxIssue(
                        code: .invalidFieldType,
                        severity: .error,
                        message: "Key '\(key)' has invalid type. Expected \(definition.type.displayName), got \(JSONValue.typeDescription(value))",
                        sourcePath: sourcePath,
                        keyPath: key
                    ))
                }

                // Validate enum values for specific keys
                if let enumIssue = validateEnumValue(for: key, value: value, definition: definition, sourcePath: sourcePath) {
                    issues.append(enumIssue)
                }
            } else {
                // Unknown key — emit as info level
                issues.append(SyntaxIssue(
                    code: .unknownKey,
                    severity: .info,
                    message: "Unknown key '\(key)'",
                    sourcePath: sourcePath,
                    keyPath: key
                ))
            }
        }

        // Check for mutually exclusive keys
        if document.value.includeCoAuthoredBy != nil && document.value.attribution != nil {
            issues.append(SyntaxIssue(
                code: .mutuallyExclusiveKeys,
                severity: .error,
                message: "Keys 'includeCoAuthoredBy' and 'attribution' cannot both be present",
                sourcePath: sourcePath,
                keyPath: "includeCoAuthoredBy"
            ))
        }

        return issues
    }

    /// Validate enum values for specific keys that have known valid values.
    private func validateEnumValue(
        for key: String,
        value: JSONValue,
        definition: SettingsKeyDefinition,
        sourcePath: String
    ) -> SyntaxIssue? {
        switch key {
        case "outputStyle":
            guard case .string(let str) = value else { return nil }
            let validValues = ["default", "md", "json"]
            if !validValues.contains(str) {
                return SyntaxIssue(
                    code: .invalidEnumValue,
                    severity: .error,
                    message: "Key 'outputStyle' must be one of: \(validValues.joined(separator: ", ")). Got '\(str)'",
                    sourcePath: sourcePath,
                    keyPath: key
                )
            }
            return nil

        case "permissions.defaultMode":
            guard case .string(let str) = value else { return nil }
            let validValues = ["default", "acceptEdits", "plan", "auto", "dontAsk", "bypassPermissions"]
            if !validValues.contains(str) {
                return SyntaxIssue(
                    code: .invalidEnumValue,
                    severity: .error,
                    message: "Key 'permissions.defaultMode' must be one of: \(validValues.joined(separator: ", ")). Got '\(str)'",
                    sourcePath: sourcePath,
                    keyPath: key
                )
            }
            return nil

        case "permissions.disableBypassPermissionsMode":
            guard case .string(let str) = value else { return nil }
            let validValues = ["disable"]
            if !validValues.contains(str) {
                return SyntaxIssue(
                    code: .invalidEnumValue,
                    severity: .error,
                    message: "Key 'permissions.disableBypassPermissionsMode' must be one of: \(validValues.joined(separator: ", ")). Got '\(str)'",
                    sourcePath: sourcePath,
                    keyPath: key
                )
            }
            return nil

        case "effortLevel":
            guard case .string(let str) = value else { return nil }
            let validValues = ["low", "medium", "high"]
            if !validValues.contains(str) {
                return SyntaxIssue(
                    code: .invalidEnumValue,
                    severity: .error,
                    message: "Key 'effortLevel' must be one of: \(validValues.joined(separator: ", ")). Got '\(str)'",
                    sourcePath: sourcePath,
                    keyPath: key
                )
            }
            return nil

        case "reasoning":
            guard case .string(let str) = value else { return nil }
            let validValues = ["disabled", "standard", "extended"]
            if !validValues.contains(str) {
                return SyntaxIssue(
                    code: .invalidEnumValue,
                    severity: .error,
                    message: "Key 'reasoning' must be one of: \(validValues.joined(separator: ", ")). Got '\(str)'",
                    sourcePath: sourcePath,
                    keyPath: key
                )
            }
            return nil

        default:
            return nil
        }
    }
}

extension JSONValue {
    static func typeDescription(_ value: JSONValue) -> String {
        switch value {
        case .string:
            return "string"
        case .number:
            return "number"
        case .bool:
            return "bool"
        case .object:
            return "object"
        case .array:
            return "array"
        case .null:
            return "null"
        }
    }
}

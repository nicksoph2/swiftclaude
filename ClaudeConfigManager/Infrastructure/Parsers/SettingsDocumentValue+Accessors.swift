import Foundation

extension SettingsDocumentValue {
    func string(for keyPath: String) -> String? {
        guard case .string(let value)? = jsonValue(for: keyPath) else {
            return nil
        }
        return value
    }

    func bool(for keyPath: String) -> Bool? {
        guard case .bool(let value)? = jsonValue(for: keyPath) else {
            return nil
        }
        return value
    }

    func int(for keyPath: String) -> Int? {
        guard case .number(let value)? = jsonValue(for: keyPath), floor(value) == value else {
            return nil
        }
        return Int(value)
    }

    func number(for keyPath: String) -> Double? {
        guard case .number(let value)? = jsonValue(for: keyPath) else {
            return nil
        }
        return value
    }

    func stringArray(for keyPath: String) -> [String]? {
        guard case .array(let values)? = jsonValue(for: keyPath) else {
            return nil
        }

        var output: [String] = []
        output.reserveCapacity(values.count)

        for value in values {
            guard case .string(let stringValue) = value else {
                return nil
            }
            output.append(stringValue)
        }

        return output
    }

    func object(for keyPath: String) -> [String: JSONValue]? {
        guard case .object(let value)? = jsonValue(for: keyPath) else {
            return nil
        }
        return value
    }

    func jsonValue(for keyPath: String) -> JSONValue? {
        rawValue(for: keyPath)
    }

    var modelSettings: [String: JSONValue] {
        values(in: [.modelReasoning])
    }

    var permissionSettings: [String: JSONValue] {
        values(in: [.permissions])
    }

    var hookPolicySettings: [String: JSONValue] {
        values(in: [.hooksHookPolicy])
    }

    var mcpSettings: [String: JSONValue] {
        values(in: [.mcpControls])
    }

    var sandboxSettings: [String: JSONValue] {
        values(in: [.sandbox])
    }

    var pluginAndMarketplaceSettings: [String: JSONValue] {
        values(in: [.pluginsMarketplaces])
    }

    var authenticationAndHelperSettings: [String: JSONValue] {
        values(in: [.authenticationIdentity, .environmentHelpers])
    }

    var uiSessionSettings: [String: JSONValue] {
        values(in: [.uiSessionExperience])
    }

    var worktreeSettings: [String: JSONValue] {
        values(in: [.worktree])
    }

    var memoryAndClaudeMdSettings: [String: JSONValue] {
        values(in: [.memoryClaudeMd])
    }

    private func values(in categories: Set<SettingsKeyCategory>) -> [String: JSONValue] {
        var values: [String: JSONValue] = [:]
        let topLevelKeys = Set(
            SettingsKeyRegistry.shared.allDefinitions
                .filter { categories.contains($0.category) }
                .map(\.keyPath)
                .compactMap { $0.split(separator: ".").first.map(String.init) }
        )

        for key in topLevelKeys.sorted() {
            guard let value = keyedStorage[key] else {
                continue
            }
            values[key] = value
        }

        return values
    }
}

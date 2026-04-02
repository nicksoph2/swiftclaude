import Foundation

struct JSONKeyPathMutator {
    enum MutationError: Error {
        case invalidPath(String)
        case typeMismatch(String, String)
        case appendToNonArray(String)
        case removeFromNonArray(String)
    }

    func apply(_ change: SettingsChange, to root: JSONValue) throws -> JSONValue {
        switch change.operation {
        case .set:
            return try setAtKeyPath(change.keyPath, value: change.newValue, in: root)
        case .remove:
            return try removeAtKeyPath(change.keyPath, in: root)
        case .appendToArray(let element):
            return try appendToArrayAtKeyPath(change.keyPath, element: element, in: root)
        case .removeFromArray(let element):
            return try removeFromArrayAtKeyPath(change.keyPath, element: element, in: root)
        }
    }

    // MARK: - Set Operation

    private func setAtKeyPath(_ keyPath: String, value: JSONValue, in root: JSONValue) throws -> JSONValue {
        let keys = keyPath.split(separator: ".").map(String.init)
        guard !keys.isEmpty else {
            throw MutationError.invalidPath(keyPath)
        }

        return try setAtKeys(keys, value: value, in: root)
    }

    private func setAtKeys(_ keys: [String], value: JSONValue, in root: JSONValue) throws -> JSONValue {
        guard !keys.isEmpty else {
            return value
        }

        let firstKey = keys[0]
        let remainingKeys = Array(keys.dropFirst())

        guard case var .object(dict) = root else {
            throw MutationError.typeMismatch(String(describing: root), "object")
        }

        if remainingKeys.isEmpty {
            dict[firstKey] = value
        } else {
            let existingValue = dict[firstKey] ?? .object([:])
            dict[firstKey] = try setAtKeys(remainingKeys, value: value, in: existingValue)
        }

        return .object(dict)
    }

    // MARK: - Remove Operation

    private func removeAtKeyPath(_ keyPath: String, in root: JSONValue) throws -> JSONValue {
        let keys = keyPath.split(separator: ".").map(String.init)
        guard !keys.isEmpty else {
            throw MutationError.invalidPath(keyPath)
        }

        return try removeAtKeys(keys, in: root)
    }

    private func removeAtKeys(_ keys: [String], in root: JSONValue) throws -> JSONValue {
        guard !keys.isEmpty else {
            return root
        }

        let firstKey = keys[0]
        let remainingKeys = Array(keys.dropFirst())

        guard case var .object(dict) = root else {
            throw MutationError.typeMismatch(String(describing: root), "object")
        }

        if remainingKeys.isEmpty {
            dict.removeValue(forKey: firstKey)
        } else {
            if let existingValue = dict[firstKey] {
                dict[firstKey] = try removeAtKeys(remainingKeys, in: existingValue)
            }
        }

        return .object(dict)
    }

    // MARK: - Append to Array Operation

    private func appendToArrayAtKeyPath(_ keyPath: String, element: JSONValue, in root: JSONValue) throws -> JSONValue {
        let keys = keyPath.split(separator: ".").map(String.init)
        guard !keys.isEmpty else {
            throw MutationError.invalidPath(keyPath)
        }

        return try appendToArrayAtKeys(keys, element: element, in: root)
    }

    private func appendToArrayAtKeys(_ keys: [String], element: JSONValue, in root: JSONValue) throws -> JSONValue {
        guard !keys.isEmpty else {
            return root
        }

        let firstKey = keys[0]
        let remainingKeys = Array(keys.dropFirst())

        guard case var .object(dict) = root else {
            throw MutationError.typeMismatch(String(describing: root), "object")
        }

        if remainingKeys.isEmpty {
            let existing = dict[firstKey] ?? .array([])
            guard case var .array(arr) = existing else {
                throw MutationError.appendToNonArray(firstKey)
            }
            arr.append(element)
            dict[firstKey] = .array(arr)
        } else {
            let existingValue = dict[firstKey] ?? .object([:])
            dict[firstKey] = try appendToArrayAtKeys(remainingKeys, element: element, in: existingValue)
        }

        return .object(dict)
    }

    // MARK: - Remove from Array Operation

    private func removeFromArrayAtKeyPath(_ keyPath: String, element: JSONValue, in root: JSONValue) throws -> JSONValue {
        let keys = keyPath.split(separator: ".").map(String.init)
        guard !keys.isEmpty else {
            throw MutationError.invalidPath(keyPath)
        }

        return try removeFromArrayAtKeys(keys, element: element, in: root)
    }

    private func removeFromArrayAtKeys(_ keys: [String], element: JSONValue, in root: JSONValue) throws -> JSONValue {
        guard !keys.isEmpty else {
            return root
        }

        let firstKey = keys[0]
        let remainingKeys = Array(keys.dropFirst())

        guard case var .object(dict) = root else {
            throw MutationError.typeMismatch(String(describing: root), "object")
        }

        if remainingKeys.isEmpty {
            if let existing = dict[firstKey] {
                guard case var .array(arr) = existing else {
                    throw MutationError.removeFromNonArray(firstKey)
                }
                arr.removeAll { $0 == element }
                dict[firstKey] = .array(arr)
            }
        } else {
            if let existingValue = dict[firstKey] {
                dict[firstKey] = try removeFromArrayAtKeys(remainingKeys, element: element, in: existingValue)
            }
        }

        return .object(dict)
    }
}

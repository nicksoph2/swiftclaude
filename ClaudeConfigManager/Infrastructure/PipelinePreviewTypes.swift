import Foundation

// MARK: - PreviewResult

/// The projected outcome of applying a SettingsChange in memory without writing to disk.
struct PreviewResult {
    /// The resolved configuration state that would result from the change.
    let proposedProjection: SessionProjection
    /// Keys whose resolved effective values would change.
    let affectedKeys: [KeyDelta]
    /// The canonical JSON string that would be written to the target file.
    let targetFilePreview: String
    /// Non-nil if the change is invalid and cannot be saved.
    let error: WriteError?
}

// MARK: - KeyDelta

/// Describes a single key whose resolved value would change as a result of a proposed edit.
struct KeyDelta {
    /// The dotted key path (e.g. "permissions.allow").
    let keyPath: String
    /// The current effective resolved value, or nil if the key is not currently set.
    let before: JSONValue?
    /// The projected effective resolved value after the change, or nil if it would be removed.
    let after: JSONValue?
    /// The scope whose value would win in the proposed projection.
    let winningScope: ResolutionScope
}

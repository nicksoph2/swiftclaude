import SwiftUI

/// Tracks edit mode state for configuration views
@MainActor
class EditModeState: ObservableObject {
    @Published var isEditModeActive: Bool = false
    @Published var editingKeyPath: String?
    @Published var showsManagedLockPopover: Bool = false

    func toggleEditMode() {
        isEditModeActive.toggle()
        if !isEditModeActive {
            editingKeyPath = nil
            showsManagedLockPopover = false
        }
    }

    func startEditing(_ keyPath: String) {
        editingKeyPath = keyPath
        showsManagedLockPopover = false
    }

    func startShowingLock(for keyPath: String) {
        editingKeyPath = keyPath
        showsManagedLockPopover = true
    }

    func closePopovers() {
        editingKeyPath = nil
        showsManagedLockPopover = false
    }
}

/// Represents a change pending write
struct PendingSettingChange {
    let keyPath: String
    let newValue: JSONValue
    let targetScope: ResolutionScope
    let recommendation: ScopeRecommendation
}

/// Represents the result of a write operation
enum WriteResult {
    case pending
    case success
    case failure(WriteError)

    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }

    var isFailure: Bool {
        if case .failure = self {
            return true
        }
        return false
    }

    var error: WriteError? {
        if case let .failure(error) = self {
            return error
        }
        return nil
    }
}

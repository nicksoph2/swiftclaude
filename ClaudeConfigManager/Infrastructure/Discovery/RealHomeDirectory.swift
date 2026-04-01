import Foundation

/// Returns the real user home directory, bypassing the macOS App Sandbox container.
///
/// In a sandboxed app `FileManager.default.homeDirectoryForCurrentUser` returns the
/// container path (e.g. `~/Library/Containers/<bundle-id>/Data/`).  Claude Code stores
/// its configuration under the *real* home directory (`~/.claude`), so we need to
/// resolve the actual path via the POSIX password database.
enum RealHomeDirectory {
    /// The real home directory URL (e.g. `/Users/joe`).
    static let url: URL = {
        if let pw = getpwuid(getuid()) {
            let path = String(cString: pw.pointee.pw_dir)
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        // Fallback — should never happen on macOS, but keeps us safe.
        return FileManager.default.homeDirectoryForCurrentUser
    }()
}

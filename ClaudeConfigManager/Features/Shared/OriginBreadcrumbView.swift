import SwiftUI

/// A small, de-emphasised breadcrumb showing the file path origin of a config value.
///
/// Displays the file path in a compact format. Tapping copies the full path.
/// Only shown when the user wants to know "which file is this from?".
struct OriginBreadcrumbView: View {

    let sourcePath: String?
    let scope: ResolutionScope

    @State private var showCopied = false

    var body: some View {
        if let path = sourcePath {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(path, forType: .string)
                showCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showCopied = false
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 7))
                    Text(showCopied ? "Copied" : abbreviatedPath(path))
                        .font(.system(size: 9, design: .monospaced))
                }
                .foregroundStyle(ScopeColorScheme.color(for: scope).opacity(0.5))
            }
            .buttonStyle(.plain)
            .help(path)
        }
    }

    private func abbreviatedPath(_ path: String) -> String {
        let components = path.split(separator: "/")
        guard components.count > 2 else { return path }

        // Show scope hint + filename: "~/.claude/settings.json" or ".claude/settings.json"
        if path.hasPrefix("/Users") || path.contains("/.claude/") {
            let last2 = components.suffix(2).joined(separator: "/")
            return "…/\(last2)"
        }

        let last = components.suffix(2).joined(separator: "/")
        return "…/\(last)"
    }
}

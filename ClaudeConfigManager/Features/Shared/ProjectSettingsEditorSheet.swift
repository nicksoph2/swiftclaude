import SwiftUI

/// Sheet wrapper for ProjectSettingsEditorView that handles file loading
struct ProjectSettingsEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    let projectRootURL: URL
    
    private var teamFileURL: URL {
        projectRootURL.appendingPathComponent(".claude").appendingPathComponent("settings.json")
    }
    
    private var personalFileURL: URL {
        projectRootURL.appendingPathComponent(".claude").appendingPathComponent("settings.local.json")
    }
    
    var body: some View {
        ProjectSettingsEditorView(
            teamFileURL: teamFileURL,
            personalFileURL: personalFileURL,
            teamDocument: loadDocument(teamFileURL),
            personalDocument: loadDocument(personalFileURL)
        )
    }
    
    private func loadDocument(_ fileURL: URL) -> ParsedSettingsDocument? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            guard let data = content.data(using: .utf8) else { return nil }
            let parser = SettingsParser()
            let scope: ResolutionScope = fileURL.lastPathComponent == "settings.local.json" ? .projectLocal : .project
            let result = parser.parse(data: data, sourceURL: fileURL, scope: scope)
            return result.value
        } catch {
            return nil
        }
    }
}

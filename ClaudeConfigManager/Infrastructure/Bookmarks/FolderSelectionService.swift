import AppKit
import Foundation

@MainActor
protocol FolderSelecting {
    func selectFolder(
        title: String,
        message: String,
        prompt: String,
        initialDirectory: URL?
    ) -> URL?
}

@MainActor
final class OpenPanelFolderSelector: FolderSelecting {
    func selectFolder(
        title: String,
        message: String,
        prompt: String = "Select Folder",
        initialDirectory: URL? = nil
    ) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.resolvesAliases = true
        panel.prompt = prompt
        panel.title = title
        panel.message = message
        panel.directoryURL = initialDirectory

        let response = panel.runModal()
        guard response == .OK else {
            return nil
        }

        return panel.url
    }
}

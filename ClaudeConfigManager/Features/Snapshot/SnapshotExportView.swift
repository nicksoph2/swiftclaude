import SwiftUI
import AppKit

// MARK: - Snapshot Export Sheet

@MainActor
struct SnapshotExportView: View {
    @EnvironmentObject private var pipeline: ConfigurationPipeline
    @Environment(\.dismiss) private var dismiss

    @State private var exportFormat: SnapshotExportFormat = .json
    @State private var exportError: String?
    @State private var isExporting = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Export Configuration Snapshot")
                .font(.headline)

            Text("Save the current resolved configuration state to a file. Sensitive values (env vars, tokens, keys, secrets, passwords) will be redacted.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Picker("Format", selection: $exportFormat) {
                Text("JSON").tag(SnapshotExportFormat.json)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)

            if let error = exportError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Export…") {
                    performExport()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(pipeline.projection == nil || isExporting)
            }
        }
        .padding(24)
        .frame(minWidth: 400)
    }

    private func performExport() {
        guard let projection = pipeline.projection,
              let scanResult = pipeline.scanResult else {
            exportError = "No pipeline data available. Run the pipeline first."
            return
        }

        isExporting = true
        exportError = nil

        let exporter = ConfigurationSnapshotExporter()
        let snapshot = exporter.export(projection, scanResult: scanResult)

        do {
            let data = try exporter.serializeToJSON(snapshot)

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: Date())

            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "claude-config-snapshot-\(dateString).json"
            panel.title = "Export Configuration Snapshot"
            panel.canCreateDirectories = true

            let response = panel.runModal()
            if response == .OK, let url = panel.url {
                try data.write(to: url)
                dismiss()
            }
        } catch {
            exportError = "Export failed: \(error.localizedDescription)"
        }

        isExporting = false
    }
}

enum SnapshotExportFormat: String, CaseIterable {
    case json = "JSON"
}

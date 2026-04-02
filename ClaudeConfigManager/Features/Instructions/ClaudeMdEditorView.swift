import SwiftUI

/// Markdown text editor for CLAUDE.md files at any scope
struct ClaudeMdEditorView: View {
    @Environment(\.dismiss) var dismiss
    @State private var editedContent: String
    @State private var isSaving = false
    @State private var showSaveConfirmation = false
    @State private var tokenCount: Int = 0
    @State private var debounceTask: Task<Void, Never>?
    
    let fileURL: URL
    let fileName: String
    let scope: ResolutionScope
    let initialContent: String
    let loadOrderIndex: Int?
    
    init(
        fileURL: URL,
        fileName: String,
        scope: ResolutionScope,
        initialContent: String,
        loadOrderIndex: Int? = nil
    ) {
        self.fileURL = fileURL
        self.fileName = fileName
        self.scope = scope
        self.initialContent = initialContent
        self.loadOrderIndex = loadOrderIndex
        _editedContent = State(initialValue: initialContent)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                toolbarArea
                
                TextEditor(text: $editedContent)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: editedContent) { _, newValue in
                        updateTokenCount(newValue)
                    }
                
                if tokenCountExceeded {
                    warningPanel
                }
                
                importReferencesSection
            }
            .navigationTitle("Edit Instructions")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            showSaveConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .automatic) {
                    HStack(spacing: 12) {
                        if isSaving {
                            ProgressView("Saving…")
                                .controlSize(.small)
                        }
                        Button("Save") {
                            performSave()
                        }
                        .disabled(!hasUnsavedChanges || isSaving)
                    }
                }
            }
            .alert("Discard Changes?", isPresented: $showSaveConfirmation) {
                Button("Cancel") { }
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Save First") {
                    performSave()
                }
            } message: {
                Text("You have unsaved changes to this file.")
            }
        }
    }
    
    private var toolbarArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(fileName)
                        .font(.headline)
                    HStack(spacing: 8) {
                        Text(scope.rawValue.localizedCapitalized)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ScopeColorScheme.color(for: scope).opacity(0.2))
                            .cornerRadius(4)
                        
                        if let index = loadOrderIndex {
                            Text("Position: #\(index)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("~\(tokenCount) tokens")
                        .font(.body.weight(.semibold))
                    HStack(spacing: 4) {
                        Circle()
                            .fill(tokenCountExceeded ? Color.orange : Color.green)
                            .frame(width: 8, height: 8)
                        Text(tokenCountExceeded ? "Over budget" : "OK")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.controlBackgroundColor))
        }
    }
    
    private var warningPanel: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Large file")
                    .font(.caption.weight(.semibold))
                Text("This file is large. Consider splitting it or using @import to load sections conditionally.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .padding(12)
    }
    
    private var importReferencesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup("Imported files") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(extractedImports, id: \.self) { importPath in
                        HStack(spacing: 6) {
                            Image(systemName: importFileExists(importPath) ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(importFileExists(importPath) ? .green : .red)
                            Text(importPath)
                                .font(.system(.caption, design: .monospaced))
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(8)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(6)
            }
            .font(.caption)
            .padding(12)
        }
        .background(Color(.controlBackgroundColor).opacity(0.5))
    }
    
    private var extractedImports: [String] {
        let lines = editedContent.split(separator: "\n", omittingEmptySubsequences: false)
        return lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("@import ") {
                let path = String(trimmed.dropFirst("@import ".count)).trimmingCharacters(in: .whitespaces)
                return path.isEmpty ? nil : path
            }
            return nil
        }
    }
    
    private func importFileExists(_ path: String) -> Bool {
        let resolvedPath = (fileURL.deletingLastPathComponent().path as NSString).appendingPathComponent(path)
        return FileManager.default.fileExists(atPath: resolvedPath)
    }
    
    private var hasUnsavedChanges: Bool {
        editedContent != initialContent
    }
    
    private var tokenCountExceeded: Bool {
        tokenCount > 50000
    }
    
    private func updateTokenCount(_ text: String) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            if !Task.isCancelled {
                DispatchQueue.main.async {
                    tokenCount = TokenEstimator.estimateTokenCount(text)
                }
            }
        }
    }
    
    private func performSave() {
        isSaving = true
        Task {
            do {
                try editedContent.write(to: fileURL, atomically: true, encoding: .utf8)
                try await Task.sleep(nanoseconds: 500_000_000) // Brief visual feedback
                dismiss()
            } catch {
                isSaving = false
                // Error handling would be integrated with AtomicFileWriter
            }
        }
    }
}

#Preview {
    ClaudeMdEditorView(
        fileURL: URL(fileURLWithPath: "/Users/test/.claude/CLAUDE.md"),
        fileName: "CLAUDE.md",
        scope: .user,
        initialContent: "# My Instructions\n\nBe helpful and harmless.",
        loadOrderIndex: 2
    )
}

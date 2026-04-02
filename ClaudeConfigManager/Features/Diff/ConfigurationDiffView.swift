import SwiftUI
import AppKit

// MARK: - Diff Entry Model

enum DiffChangeKind: String, CaseIterable {
    case added
    case removed
    case changed
    case unchanged
}

struct ConfigurationDiffEntry: Identifiable, Equatable {
    let id: String
    let keyPath: String
    let changeKind: DiffChangeKind
    let oldValue: JSONValue?
    let newValue: JSONValue?

    init(keyPath: String, changeKind: DiffChangeKind, oldValue: JSONValue? = nil, newValue: JSONValue? = nil) {
        self.id = "\(changeKind.rawValue)::\(keyPath)"
        self.keyPath = keyPath
        self.changeKind = changeKind
        self.oldValue = oldValue
        self.newValue = newValue
    }
}

// MARK: - Diff Engine

struct ConfigurationDiffEngine {

    /// Diff two snapshots by their resolved settings.
    static func diffSnapshots(
        old: ConfigurationSnapshot,
        new: ConfigurationSnapshot
    ) -> [ConfigurationDiffEntry] {
        let oldMap = Dictionary(uniqueKeysWithValues: old.resolvedSettings.map { ($0.keyPath, $0) })
        let newMap = Dictionary(uniqueKeysWithValues: new.resolvedSettings.map { ($0.keyPath, $0) })

        let allKeys = Set(oldMap.keys).union(Set(newMap.keys)).sorted()
        var entries: [ConfigurationDiffEntry] = []

        for key in allKeys {
            let oldEntry = oldMap[key]
            let newEntry = newMap[key]

            switch (oldEntry, newEntry) {
            case (nil, .some(let n)):
                entries.append(ConfigurationDiffEntry(
                    keyPath: key,
                    changeKind: .added,
                    oldValue: nil,
                    newValue: n.resolvedValue
                ))
            case (.some(let o), nil):
                entries.append(ConfigurationDiffEntry(
                    keyPath: key,
                    changeKind: .removed,
                    oldValue: o.resolvedValue,
                    newValue: nil
                ))
            case (.some(let o), .some(let n)):
                if o.resolvedValue != n.resolvedValue {
                    entries.append(ConfigurationDiffEntry(
                        keyPath: key,
                        changeKind: .changed,
                        oldValue: o.resolvedValue,
                        newValue: n.resolvedValue
                    ))
                } else {
                    entries.append(ConfigurationDiffEntry(
                        keyPath: key,
                        changeKind: .unchanged,
                        oldValue: o.resolvedValue,
                        newValue: n.resolvedValue
                    ))
                }
            case (nil, nil):
                break
            }
        }

        return entries
    }

    /// Diff a profile against the current resolved settings.
    static func diffProfileAgainstProjection(
        profile: ConfigurationProfile,
        projection: SessionProjection
    ) -> [ConfigurationDiffEntry] {
        let profileSettings = profile.settings
        var currentSettings: [String: JSONValue] = [:]
        if let settings = projection.settings {
            for entry in settings.entries {
                if let value = entry.value.effectiveValue {
                    currentSettings[entry.keyPath] = value
                }
            }
        }

        let allKeys = Set(profileSettings.keys).union(Set(currentSettings.keys)).sorted()
        var entries: [ConfigurationDiffEntry] = []

        for key in allKeys {
            let profileValue = profileSettings[key]
            let currentValue = currentSettings[key]

            switch (profileValue, currentValue) {
            case (nil, .some(let c)):
                entries.append(ConfigurationDiffEntry(
                    keyPath: key,
                    changeKind: .added,
                    oldValue: nil,
                    newValue: c
                ))
            case (.some(let p), nil):
                entries.append(ConfigurationDiffEntry(
                    keyPath: key,
                    changeKind: .removed,
                    oldValue: p,
                    newValue: nil
                ))
            case (.some(let p), .some(let c)):
                if p != c {
                    entries.append(ConfigurationDiffEntry(
                        keyPath: key,
                        changeKind: .changed,
                        oldValue: p,
                        newValue: c
                    ))
                } else {
                    entries.append(ConfigurationDiffEntry(
                        keyPath: key,
                        changeKind: .unchanged,
                        oldValue: p,
                        newValue: c
                    ))
                }
            case (nil, nil):
                break
            }
        }

        return entries
    }

    /// Generate a Markdown diff report.
    static func exportDiffAsMarkdown(_ entries: [ConfigurationDiffEntry], title: String) -> String {
        var lines: [String] = []
        lines.append("# Configuration Diff Report")
        lines.append("")
        lines.append("**\(title)**")
        lines.append("")
        lines.append("Generated: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("")

        let added = entries.filter { $0.changeKind == .added }
        let removed = entries.filter { $0.changeKind == .removed }
        let changed = entries.filter { $0.changeKind == .changed }
        let unchanged = entries.filter { $0.changeKind == .unchanged }

        lines.append("## Summary")
        lines.append("")
        lines.append("- Added: \(added.count)")
        lines.append("- Removed: \(removed.count)")
        lines.append("- Changed: \(changed.count)")
        lines.append("- Unchanged: \(unchanged.count)")
        lines.append("")

        if !added.isEmpty {
            lines.append("## Added Settings")
            lines.append("")
            for entry in added {
                lines.append("- **`\(entry.keyPath)`**: \(formatValue(entry.newValue))")
            }
            lines.append("")
        }

        if !removed.isEmpty {
            lines.append("## Removed Settings")
            lines.append("")
            for entry in removed {
                lines.append("- ~~`\(entry.keyPath)`~~: \(formatValue(entry.oldValue))")
            }
            lines.append("")
        }

        if !changed.isEmpty {
            lines.append("## Changed Settings")
            lines.append("")
            for entry in changed {
                lines.append("- **`\(entry.keyPath)`**: \(formatValue(entry.oldValue)) → \(formatValue(entry.newValue))")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private static func formatValue(_ value: JSONValue?) -> String {
        guard let value else { return "(none)" }
        return DashboardDataHelpers.formatValue(value)
    }
}

// MARK: - Configuration Diff View

@MainActor
struct ConfigurationDiffView: View {
    @EnvironmentObject private var pipeline: ConfigurationPipeline

    enum DiffMode: String, CaseIterable {
        case snapshotVsSnapshot = "Snapshot vs Snapshot"
        case currentVsProfile = "Current vs Profile"
    }

    @State private var diffMode: DiffMode = .snapshotVsSnapshot
    @State private var diffEntries: [ConfigurationDiffEntry] = []
    @State private var showOnlyChanged = true
    @State private var showUnchanged = false
    @State private var errorMessage: String?
    @State private var snapshotAName: String?
    @State private var snapshotBName: String?

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            Divider()

            if diffEntries.isEmpty {
                emptyState
            } else {
                diffList
            }
        }
        .navigationTitle("Configuration Diff")
    }

    private var controlBar: some View {
        VStack(spacing: 10) {
            Picker("Comparison Mode", selection: $diffMode) {
                ForEach(DiffMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 350)

            HStack(spacing: 12) {
                switch diffMode {
                case .snapshotVsSnapshot:
                    Button("Load Snapshots…") {
                        loadSnapshotsForDiff()
                    }
                case .currentVsProfile:
                    Button("Load Profile…") {
                        loadProfileForDiff()
                    }
                    .disabled(pipeline.projection == nil)
                }

                Spacer()

                Toggle("Show only changes", isOn: $showOnlyChanged)
                    .toggleStyle(.checkbox)

                Button {
                    exportDiffMarkdown()
                } label: {
                    Label("Export as Markdown", systemImage: "doc.text")
                }
                .disabled(diffEntries.isEmpty)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "arrow.left.arrow.right")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No Diff Loaded")
                .font(.title3.weight(.medium))
            Text("Select two snapshots or a profile to compare.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var diffList: some View {
        let filteredEntries = showOnlyChanged
            ? diffEntries.filter { $0.changeKind != .unchanged }
            : diffEntries

        let changedEntries = filteredEntries.filter { $0.changeKind != .unchanged }
        let unchangedEntries = filteredEntries.filter { $0.changeKind == .unchanged }

        return List {
            if !changedEntries.isEmpty {
                Section {
                    ForEach(changedEntries) { entry in
                        diffRow(entry)
                    }
                } header: {
                    Text("Changes (\(changedEntries.count))")
                }
            }

            if !showOnlyChanged && !unchangedEntries.isEmpty {
                DisclosureGroup("Unchanged (\(unchangedEntries.count) settings)") {
                    ForEach(unchangedEntries) { entry in
                        diffRow(entry)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private func diffRow(_ entry: ConfigurationDiffEntry) -> some View {
        HStack(spacing: 10) {
            changeBadge(entry.changeKind)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.keyPath)
                    .font(.callout.monospaced().weight(.medium))
                    .strikethrough(entry.changeKind == .removed)

                HStack(spacing: 6) {
                    if let oldVal = entry.oldValue, entry.changeKind == .changed || entry.changeKind == .removed {
                        Text(DashboardDataHelpers.formatValue(oldVal))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .strikethrough(entry.changeKind == .removed)
                    }

                    if entry.changeKind == .changed {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let newVal = entry.newValue, entry.changeKind == .changed || entry.changeKind == .added {
                        Text(DashboardDataHelpers.formatValue(newVal))
                            .font(.caption.monospaced())
                            .foregroundStyle(entry.changeKind == .added ? .green : .primary)
                    }

                    if entry.changeKind == .unchanged, let val = entry.newValue {
                        Text(DashboardDataHelpers.formatValue(val))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 3)
    }

    private func changeBadge(_ kind: DiffChangeKind) -> some View {
        let (symbol, color): (String, Color) = {
            switch kind {
            case .added: return ("+", .green)
            case .removed: return ("-", .red)
            case .changed: return ("~", .orange)
            case .unchanged: return ("=", .secondary)
            }
        }()

        return Text(symbol)
            .font(.caption.monospaced().weight(.bold))
            .foregroundStyle(color)
            .frame(width: 20, height: 20)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Actions

    private func loadSnapshotsForDiff() {
        errorMessage = nil

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = true
        panel.title = "Select Two Snapshot Files"
        panel.message = "Select exactly two snapshot JSON files to compare."

        let response = panel.runModal()
        guard response == .OK, panel.urls.count == 2 else {
            if response == .OK {
                errorMessage = "Please select exactly two snapshot files."
            }
            return
        }

        do {
            let dataA = try Data(contentsOf: panel.urls[0])
            let dataB = try Data(contentsOf: panel.urls[1])
            let snapshotA = try ConfigurationSnapshotExporter.deserializeFromJSON(dataA)
            let snapshotB = try ConfigurationSnapshotExporter.deserializeFromJSON(dataB)

            snapshotAName = panel.urls[0].lastPathComponent
            snapshotBName = panel.urls[1].lastPathComponent

            diffEntries = ConfigurationDiffEngine.diffSnapshots(old: snapshotA, new: snapshotB)
        } catch {
            errorMessage = "Failed to load snapshots: \(error.localizedDescription)"
        }
    }

    private func loadProfileForDiff() {
        errorMessage = nil

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.title = "Select a Profile File"

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let profiles = try decoder.decode([ConfigurationProfile].self, from: data)

            guard let profile = profiles.first else {
                errorMessage = "No profiles found in file."
                return
            }

            guard let projection = pipeline.projection else {
                errorMessage = "No pipeline data available."
                return
            }

            diffEntries = ConfigurationDiffEngine.diffProfileAgainstProjection(
                profile: profile,
                projection: projection
            )
        } catch {
            errorMessage = "Failed to load profile: \(error.localizedDescription)"
        }
    }

    private func exportDiffMarkdown() {
        let title: String
        if let a = snapshotAName, let b = snapshotBName {
            title = "\(a) vs \(b)"
        } else {
            title = "Configuration Diff"
        }

        let markdown = ConfigurationDiffEngine.exportDiffAsMarkdown(diffEntries, title: title)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "config-diff-report.md"
        panel.title = "Export Diff Report"

        let response = panel.runModal()
        if response == .OK, let url = panel.url {
            try? markdown.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

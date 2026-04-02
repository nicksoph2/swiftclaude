import SwiftUI

/// Stage 1 — Discovery detail view.
///
/// Renders a tree of `DiscoveryTreeNode` items using recursive `DisclosureGroup`,
/// grouped by scope: Managed Tier → User Scope → Project Scope.
/// Each leaf shows file name, status badge, and full path. Tappable nodes for
/// found files display a file detail popover with metadata, raw content, and parsed keys.
struct TreeDiscoveryView: View {

    @EnvironmentObject private var pipeline: ConfigurationPipeline
    @StateObject private var viewModel = TreeDiscoveryViewModel()

    /// Optional cross-stage navigation callback.
    var onNavigate: ((TreeNavigationTarget) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StageExplanationView(stage: .discovery)

            if viewModel.rootNodes.isEmpty {
                noDataPlaceholder
            } else {
                managedTierBanner
                discoveryTree
            }
        }
        .onAppear {
            Task { @MainActor in viewModel.bind(to: pipeline) }
        }
    }

    // MARK: - No Data

    @ViewBuilder
    private var noDataPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No discovery data available")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Run the pipeline to discover configuration files on disk.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    // MARK: - Managed Tier Banner

    @ViewBuilder
    private var managedTierBanner: some View {
        switch viewModel.activeManagedTier {
        case .serverManaged:
            tierInfoBanner(
                "Server-managed tier is active. MDM and file-based tiers are suppressed.",
                icon: "lock.shield"
            )
        case .mdm:
            tierInfoBanner(
                "MDM tier is active. File-based tier is suppressed.",
                icon: "lock.shield"
            )
        case .fileBased, .none:
            EmptyView()
        }
    }

    private func tierInfoBanner(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.orange.opacity(0.08))
        )
    }

    // MARK: - Discovery Tree

    @ViewBuilder
    private var discoveryTree: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(viewModel.rootNodes) { node in
                DiscoveryNodeView(
                    node: node,
                    viewModel: viewModel,
                    isSuppressed: isSuppressed(node),
                    onNavigate: onNavigate
                )
            }
        }
    }

    /// Determines if a managed sub-tier node should be dimmed as suppressed.
    private func isSuppressed(_ node: DiscoveryTreeNode) -> Bool {
        guard node.scope == .managed else { return false }
        switch viewModel.activeManagedTier {
        case .serverManaged:
            return node.id == "managed-mdm" || node.id == "managed-filebased"
        case .mdm:
            return node.id == "managed-filebased"
        default:
            return false
        }
    }
}

// MARK: - Recursive Node View

/// Renders a single `DiscoveryTreeNode` and its children recursively.
private struct DiscoveryNodeView: View {

    let node: DiscoveryTreeNode
    let viewModel: TreeDiscoveryViewModel
    let isSuppressed: Bool
    let onNavigate: ((TreeNavigationTarget) -> Void)?

    @State private var showingPopover = false

    var body: some View {
        if node.children.isEmpty {
            leafView
        } else {
            branchView
        }
    }

    // MARK: - Branch (has children)

    @ViewBuilder
    private var branchView: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(node.children) { child in
                    DiscoveryNodeView(
                        node: child,
                        viewModel: viewModel,
                        isSuppressed: isSuppressed || isSuppressedChild(child),
                        onNavigate: onNavigate
                    )
                }
            }
            .padding(.leading, 4)
        } label: {
            branchLabel
        }
    }

    @ViewBuilder
    private var branchLabel: some View {
        HStack(spacing: 6) {
            if let scope = node.scope {
                ScopeColorScheme.scopeBadge(for: scope)
            }

            Text(node.label)
                .font(.subheadline.weight(.medium))

            if isSuppressed {
                Text("Suppressed")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.orange.opacity(0.12))
                    )
            }
        }
        .opacity(isSuppressed ? 0.5 : 1.0)
    }

    /// Determines if a child of a suppressed parent should also be suppressed.
    private func isSuppressedChild(_ child: DiscoveryTreeNode) -> Bool {
        // Children inherit suppression from their parent
        false
    }

    // MARK: - Leaf (file node)

    @ViewBuilder
    private var leafView: some View {
        Button {
            if node.status == .present && node.fileReference != nil {
                showingPopover = true
            }
        } label: {
            leafLabel
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPopover) {
            if let fileURL = node.fileReference {
                FileDetailPopoverView(
                    node: node,
                    fileURL: fileURL,
                    viewModel: viewModel,
                    onNavigateToParsing: {
                        showingPopover = false
                        onNavigate?(.parsingFile(fileURL))
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var leafLabel: some View {
        HStack(spacing: 6) {
            statusIndicator(for: node.status)

            Text(node.label)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)

            if let scope = node.scope {
                ScopeColorScheme.scopeBadge(for: scope)
            }

            Spacer()

            if let path = node.path {
                Text(path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .opacity(isSuppressed ? 0.5 : 1.0)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func statusIndicator(for status: DiscoveredFileStatus?) -> some View {
        switch status {
        case .present:
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
                .help("File found on disk")
        case .notFound:
            Circle()
                .fill(.gray)
                .frame(width: 8, height: 8)
                .help("File not found")
        case .unreadable:
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .help("File exists but is unreadable")
        case .inaccessible:
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .help("File is inaccessible (permissions)")
        case nil:
            Circle()
                .strokeBorder(.gray.opacity(0.5), lineWidth: 1)
                .frame(width: 8, height: 8)
        }
    }
}

// MARK: - File Detail Popover

/// Popover shown when tapping a discovered file that is present on disk.
/// Shows file metadata, raw content, and parsed keys.
private struct FileDetailPopoverView: View {

    let node: DiscoveryTreeNode
    let fileURL: URL
    let viewModel: TreeDiscoveryViewModel
    let onNavigateToParsing: (() -> Void)?

    @State private var fileSize: String = "—"
    @State private var lastModified: String = "—"
    @State private var showRawContent = false
    @State private var showParsedKeys = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // File path
                VStack(alignment: .leading, spacing: 4) {
                    Text("Path")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(fileURL.path)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }

                Divider()

                // Metadata
                HStack(spacing: 16) {
                    metadataItem(label: "Size", value: fileSize)
                    metadataItem(label: "Modified", value: lastModified)
                }

                // Scope badge
                if let scope = node.scope {
                    HStack(spacing: 6) {
                        Text("Scope")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ScopeColorScheme.scopeBadge(for: scope)
                    }
                }

                // Cross-stage navigation
                if viewModel.parseRecord(for: fileURL) != nil, let onNav = onNavigateToParsing {
                    Button {
                        onNav()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right.circle")
                                .font(.caption)
                            Text("View in Parsing")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                // Raw content disclosure
                rawContentSection

                // Parsed keys disclosure
                parsedKeysSection
            }
            .padding(16)
        }
        .frame(width: 420, height: 480)
        .onAppear { loadFileMetadata() }
    }

    // MARK: - Metadata

    private func metadataItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
        }
    }

    private func loadFileMetadata() {
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let size = attrs[.size] as? Int64 {
                fileSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            }
            if let date = attrs[.modificationDate] as? Date {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                lastModified = formatter.string(from: date)
            }
        } catch {
            fileSize = "unavailable"
            lastModified = "unavailable"
        }
    }

    // MARK: - Raw Content

    @ViewBuilder
    private var rawContentSection: some View {
        DisclosureGroup("View Raw", isExpanded: $showRawContent) {
            rawContentBody
                .padding(.top, 4)
        }
        .font(.caption.weight(.medium))
    }

    @ViewBuilder
    private var rawContentBody: some View {
        if let record = viewModel.parseRecord(for: fileURL) {
            if let rawText = record.rawTextContent {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(rawText)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
            } else if let rawJSON = record.rawContent {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(jsonDisplayString(rawJSON))
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
            } else {
                Text("No raw content available")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        } else {
            // Fall back to reading from disk
            DiskFileContentView(fileURL: fileURL)
        }
    }

    // MARK: - Parsed Keys

    @ViewBuilder
    private var parsedKeysSection: some View {
        if let record = viewModel.parseRecord(for: fileURL) {
            DisclosureGroup("View Parsed", isExpanded: $showParsedKeys) {
                parsedKeysBody(record: record)
                    .padding(.top, 4)
            }
            .font(.caption.weight(.medium))
        }
    }

    @ViewBuilder
    private func parsedKeysBody(record: ParseResultRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // File type
            HStack(spacing: 4) {
                Text("Type:")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(record.fileType.rawValue)
                    .font(.caption)
            }

            // Issue count
            if !record.parseIssues.isEmpty {
                HStack(spacing: 4) {
                    Text("Issues:")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(record.parseIssues.count)")
                        .font(.caption)
                        .foregroundStyle(record.parseIssues.contains { $0.severity == .error } ? .red : .orange)
                }
            }

            // Show keys from raw JSON content
            if let rawJSON = record.rawContent {
                keysFromJSON(rawJSON)
            }

            // Show parse issues
            if !record.parseIssues.isEmpty {
                Divider()
                Text("Parse Issues")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(record.parseIssues) { issue in
                    HStack(spacing: 4) {
                        issueIcon(for: issue.severity)
                        Text(issue.message)
                            .font(.caption2)
                            .lineLimit(2)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keysFromJSON(_ json: JSONValue) -> some View {
        if case .object(let dict) = json {
            let keys = dict.keys.sorted()
            if !keys.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keys (\(keys.count))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(keys, id: \.self) { key in
                        Text(key)
                            .font(.system(.caption2, design: .monospaced))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func issueIcon(for severity: IssueSeverity) -> some View {
        switch severity {
        case .error:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption2)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption2)
        case .info:
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
                .font(.caption2)
        }
    }

    // MARK: - Helpers

    private func jsonDisplayString(_ value: JSONValue) -> String {
        switch value {
        case .null: return "null"
        case .bool(let b): return b ? "true" : "false"
        case .number(let n): return "\(n)"
        case .string(let s): return "\"\(s)\""
        case .array(let arr): return "[\(arr.count) items]"
        case .object(let dict):
            let lines = dict.keys.sorted().map { key in
                "  \"\(key)\": ..."
            }
            return "{\n\(lines.joined(separator: ",\n"))\n}"
        }
    }
}

// MARK: - Disk File Content (fallback)

/// Reads and displays file content from disk when no parse record is available.
private struct DiskFileContentView: View {

    let fileURL: URL
    @State private var content: String?

    var body: some View {
        Group {
            if let content {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(content)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
            } else {
                Text("Unable to read file content")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .onAppear { loadContent() }
    }

    private func loadContent() {
        do {
            let data = try Data(contentsOf: fileURL)
            content = String(data: data, encoding: .utf8) ?? "Binary content"
        } catch {
            content = nil
        }
    }
}

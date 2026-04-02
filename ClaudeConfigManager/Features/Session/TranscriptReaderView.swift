import SwiftUI

// MARK: - Transcript Reader View

/// A chat-style transcript reader with search, jump-to-turn, and export capabilities.
/// Loads turns incrementally for large files: first 100 turns, then more on scroll.
@MainActor
struct TranscriptReaderView: View {
    let metadata: TranscriptMetadata
    @ObservedObject var scanner: TranscriptScanner

    @State private var allEntries: [TranscriptEntry] = []
    @State private var displayedEntries: [TranscriptEntry] = []
    @State private var isLoading = true
    @State private var loadIssues: [TranscriptDiscoveryError] = []

    // Jump-to-turn
    @State private var jumpToTurnText = ""

    // Full-text search
    @State private var searchText = ""
    @State private var searchMatches: [UUID] = []
    @State private var currentMatchIndex = 0

    // Export
    @State private var isExporting = false

    // Scroll
    @State private var scrollProxy: ScrollViewProxy?

    private let incrementalBatchSize = 100
    private let parser = TranscriptParser()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            toolbarSection
            Divider()
            transcriptContent
        }
        .task {
            await loadTranscript()
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(metadata.sessionId ?? "Unknown Session", systemImage: "bubble.left.and.bubble.right")
                    .font(.title3.weight(.semibold))

                Spacer()

                if let model = metadata.model {
                    Text(model)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.12), in: Capsule())
                }
            }

            HStack(spacing: 16) {
                metricLabel("Turns", value: "\(metadata.lineCount)")
                metricLabel("Tokens", value: formatTokenCount(
                    (metadata.totalTokensIn ?? 0) + (metadata.totalTokensOut ?? 0)
                ))

                let cost = TranscriptCostEstimation.estimateCost(
                    inputTokens: metadata.totalTokensIn ?? 0,
                    outputTokens: metadata.totalTokensOut ?? 0,
                    model: metadata.model
                )
                metricLabel("Est. Cost", value: String(format: "$%.4f", cost))

                metricLabel("Date", value: metadata.modifiedAt.formatted(date: .abbreviated, time: .shortened))

                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.background)
    }

    @ViewBuilder
    private func metricLabel(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .foregroundStyle(.tertiary)
                .font(.caption2)
            Text(value)
                .font(.caption.monospacedDigit())
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbarSection: some View {
        HStack(spacing: 12) {
            // Jump to turn
            HStack(spacing: 4) {
                Image(systemName: "arrow.right.circle")
                    .foregroundStyle(.secondary)
                TextField("Go to turn #", text: $jumpToTurnText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .onSubmit { jumpToTurn() }
            }

            Divider().frame(height: 20)

            // Search
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search transcript...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 180)
                    .onChange(of: searchText) { _, _ in performSearch() }

                if !searchMatches.isEmpty {
                    Text("\(currentMatchIndex + 1)/\(searchMatches.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Button { navigateSearch(direction: -1) } label: {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(.borderless)

                    Button { navigateSearch(direction: 1) } label: {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.borderless)
                }
            }

            Spacer()

            // Export
            Button {
                exportSummary()
            } label: {
                Label("Export Summary", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .disabled(isLoading)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(.background)
    }

    // MARK: - Transcript Content

    @ViewBuilder
    private var transcriptContent: some View {
        if isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading transcript...")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if displayedEntries.isEmpty {
            Text("No entries found in this transcript.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(displayedEntries) { entry in
                            turnBubble(entry)
                                .id(entry.id)
                        }

                        if displayedEntries.count < allEntries.count {
                            loadMoreButton
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
                .onAppear { scrollProxy = proxy }
            }
        }

        if !loadIssues.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(loadIssues.prefix(3).enumerated()), id: \.offset) { _, issue in
                    Text(issue.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Turn Bubble

    @ViewBuilder
    private func turnBubble(_ entry: TranscriptEntry) -> some View {
        let isUser = entry.type == "human" || entry.type == "user"
        let isAssistant = entry.type == "assistant"
        let isTool = entry.type == "tool_use" || entry.type == "tool_result"
        let isSearchMatch = searchMatches.contains(entry.id)
        let isCurrentMatch = !searchMatches.isEmpty && currentMatchIndex < searchMatches.count && searchMatches[currentMatchIndex] == entry.id

        HStack(alignment: .top, spacing: 0) {
            if isUser { Spacer(minLength: 80) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                // Role badge + timestamp
                HStack(spacing: 6) {
                    if !isUser {
                        roleBadge(entry)
                    }

                    if let timestamp = entry.timestamp {
                        Text(timestamp.formatted(date: .omitted, time: .standard))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Text("#\(entry.lineNumber)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.quaternary)

                    if isUser {
                        roleBadge(entry)
                    }
                }

                // Content
                if isTool {
                    toolBlock(entry)
                } else {
                    Text(highlightedText(entry.displayText))
                        .font(.body)
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
                        .background(
                            isUser
                                ? Color.blue.opacity(0.12)
                                : Color(.controlBackgroundColor),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .overlay(
                            isSearchMatch
                                ? RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(isCurrentMatch ? .orange : .yellow, lineWidth: isCurrentMatch ? 2 : 1)
                                : nil
                        )
                }

                // Token usage (assistant turns)
                if isAssistant, let usage = entry.usage {
                    let tokIn = usage.inputTokens ?? 0
                    let tokOut = usage.outputTokens ?? 0
                    if tokIn > 0 || tokOut > 0 {
                        Text("\(formatTokenCount(tokIn)) in / \(formatTokenCount(tokOut)) out")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if !isUser { Spacer(minLength: isTool ? 20 : 80) }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func roleBadge(_ entry: TranscriptEntry) -> some View {
        let (label, color) = roleLabelAndColor(entry)
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }

    @ViewBuilder
    private func toolBlock(_ entry: TranscriptEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if entry.type == "tool_use" {
                let toolName = entry.rawJson["name"]?.stringValue ?? "Unknown Tool"
                HStack(spacing: 6) {
                    Image(systemName: "hammer")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text(toolName)
                        .font(.caption.weight(.bold).monospaced())
                }

                if let input = entry.rawJson["input"]?.objectValue {
                    let paramText = input.map { "\($0.key): \($0.value.stringValue ?? String(describing: $0.value))" }
                        .joined(separator: "\n")
                    Text(paramText)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                }
            } else {
                // tool_result
                HStack(spacing: 6) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.caption)
                        .foregroundStyle(.mint)
                    Text("Result")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.mint)
                }

                Text(entry.displayText)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(8)
                    .textSelection(.enabled)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.separator.opacity(0.3))
        )
        .padding(.leading, 24)
    }

    private var loadMoreButton: some View {
        Button {
            loadMoreEntries()
        } label: {
            HStack {
                Spacer()
                Text("Load more (\(allEntries.count - displayedEntries.count) remaining)")
                    .font(.subheadline)
                Spacer()
            }
            .padding(12)
            .background(.quaternary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func loadTranscript() async {
        isLoading = true
        defer { isLoading = false }

        let (entries, issues) = await scanner.loadTranscriptContent(path: metadata.transcriptPath)
        allEntries = entries
        loadIssues = issues
        displayedEntries = Array(allEntries.prefix(incrementalBatchSize))
    }

    private func loadMoreEntries() {
        let currentCount = displayedEntries.count
        let nextBatch = Array(allEntries[currentCount..<min(currentCount + incrementalBatchSize, allEntries.count)])
        displayedEntries.append(contentsOf: nextBatch)
    }

    private func jumpToTurn() {
        guard let turnNumber = Int(jumpToTurnText),
              turnNumber >= 1 else { return }

        // Ensure turn is loaded
        if turnNumber > displayedEntries.count {
            let needed = min(turnNumber + 10, allEntries.count)
            displayedEntries = Array(allEntries.prefix(needed))
        }

        if let entry = displayedEntries.first(where: { $0.lineNumber == turnNumber }) {
            withAnimation {
                scrollProxy?.scrollTo(entry.id, anchor: .center)
            }
        }
    }

    private func performSearch() {
        let query = searchText.lowercased()
        guard !query.isEmpty else {
            searchMatches = []
            currentMatchIndex = 0
            return
        }

        // Search all entries, not just displayed ones
        searchMatches = allEntries.filter { entry in
            entry.displayText.lowercased().contains(query)
        }.map(\.id)

        currentMatchIndex = 0

        // Ensure first match is visible
        if let firstMatchId = searchMatches.first {
            ensureEntryDisplayed(id: firstMatchId)
            withAnimation {
                scrollProxy?.scrollTo(firstMatchId, anchor: .center)
            }
        }
    }

    private func navigateSearch(direction: Int) {
        guard !searchMatches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex + direction + searchMatches.count) % searchMatches.count
        let matchId = searchMatches[currentMatchIndex]
        ensureEntryDisplayed(id: matchId)
        withAnimation {
            scrollProxy?.scrollTo(matchId, anchor: .center)
        }
    }

    private func ensureEntryDisplayed(id: UUID) {
        guard let entryIndex = allEntries.firstIndex(where: { $0.id == id }) else { return }
        if entryIndex >= displayedEntries.count {
            displayedEntries = Array(allEntries.prefix(entryIndex + 20))
        }
    }

    private func exportSummary() {
        let summary = parser.parseSummary(fileURL: URL(fileURLWithPath: metadata.transcriptPath))
        let markdown = TranscriptParser.markdownSummary(
            metadata: metadata,
            entries: allEntries,
            summary: summary
        )

        let panel = NSSavePanel()
        panel.title = "Export Transcript Summary"
        panel.nameFieldStringValue = "\(metadata.sessionId ?? "transcript")-summary.md"
        panel.allowedContentTypes = [.plainText]

        if panel.runModal() == .OK, let url = panel.url {
            try? markdown.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Helpers

    private func highlightedText(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        let query = searchText.lowercased()
        guard !query.isEmpty else { return attributed }

        let lowerText = text.lowercased()
        var searchStart = lowerText.startIndex

        while let range = lowerText[searchStart...].range(of: query) {
            let attrStart = AttributedString.Index(range.lowerBound, within: attributed)
            let attrEnd = AttributedString.Index(range.upperBound, within: attributed)
            if let attrStart, let attrEnd {
                attributed[attrStart..<attrEnd].backgroundColor = .yellow.opacity(0.4)
            }
            searchStart = range.upperBound
        }

        return attributed
    }

    private func roleLabelAndColor(_ entry: TranscriptEntry) -> (String, Color) {
        switch entry.type {
        case "human", "user":
            return ("You", .blue)
        case "assistant":
            return ("Claude", .green)
        case "tool_use":
            return ("Tool", .blue)
        case "tool_result":
            return ("Result", .mint)
        default:
            return (entry.type ?? "Unknown", .gray)
        }
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - Transcript List View

/// Lists discovered transcript sessions. Selecting one navigates to TranscriptReaderView.
@MainActor
struct TranscriptListView: View {
    @StateObject private var scanner: TranscriptScanner
    @EnvironmentObject private var rootSelection: RootSelectionViewModel

    @State private var selectedMetadata: TranscriptMetadata?

    init(scanner: TranscriptScanner? = nil) {
        _scanner = StateObject(wrappedValue: scanner ?? TranscriptScanner())
    }

    var body: some View {
        Group {
            if let metadata = selectedMetadata {
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            selectedMetadata = nil
                        } label: {
                            Label("All Sessions", systemImage: "chevron.left")
                        }
                        .buttonStyle(.borderless)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(.background)

                    Divider()

                    TranscriptReaderView(metadata: metadata, scanner: scanner)
                }
            } else {
                transcriptListContent
            }
        }
        .navigationTitle("Transcripts")
        .task {
            scanner.updateClaudeRootURL(rootSelection.selectedGlobalRootURL)
            await scanner.scanTranscripts()
        }
        .onChange(of: rootSelection.selectedGlobalRootURL) { _, newValue in
            scanner.updateClaudeRootURL(newValue)
            Task { await scanner.scanTranscripts() }
        }
    }

    @ViewBuilder
    private var transcriptListContent: some View {
        if scanner.recentTranscripts.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No Transcripts Found")
                    .font(.title2)
                Text("Session transcripts will appear here once Claude Code sessions are discovered.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    Text("\(scanner.recentTranscripts.count) session\(scanner.recentTranscripts.count == 1 ? "" : "s") found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)

                    ForEach(scanner.recentTranscripts) { transcript in
                        Button {
                            selectedMetadata = transcript
                        } label: {
                            transcriptRow(transcript)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
            }
        }
    }

    @ViewBuilder
    private func transcriptRow(_ transcript: TranscriptMetadata) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(transcript.sessionId ?? "Unknown")
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if transcript.isRecent {
                    Text("Recent")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.green.opacity(0.16), in: Capsule())
                        .foregroundStyle(.green)
                }
            }

            HStack(spacing: 12) {
                if let model = transcript.model {
                    Text(model)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                Text("\(transcript.lineCount) turns")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(ByteCountFormatter.string(fromByteCount: transcript.fileSize, countStyle: .file))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(transcript.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

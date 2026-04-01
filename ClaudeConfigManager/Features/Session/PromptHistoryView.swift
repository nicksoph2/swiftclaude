import SwiftUI

struct PromptHistoryView: View {
    let entries: [PromptHistoryEntry]

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var roleFilter: RoleFilter = .all
    @State private var expandedEntryId: UUID?

    private enum RoleFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case user = "User"
        case assistant = "Assistant"

        var id: String { rawValue }
    }

    private var filteredEntries: [PromptHistoryEntry] {
        entries.filter { entry in
            let matchesRole: Bool
            switch roleFilter {
            case .all:
                matchesRole = true
            case .user:
                matchesRole = entry.isUserPrompt
            case .assistant:
                matchesRole = entry.isAssistantResponse
            }

            let matchesSearch: Bool
            if searchText.isEmpty {
                matchesSearch = true
            } else {
                matchesSearch = entry.contentPreview.localizedCaseInsensitiveContains(searchText)
                    || entry.contentFull.localizedCaseInsensitiveContains(searchText)
            }

            return matchesRole && matchesSearch
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            filterBar
            Divider()
            entryList
        }
        .frame(minWidth: 520, minHeight: 480)
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack {
            Text("Prompt History")
                .font(.title2.weight(.semibold))

            Spacer()

            Text("\(filteredEntries.count) entries")
                .foregroundStyle(.secondary)

            Button("Done") {
                dismiss()
            }
        }
        .padding(20)
    }

    // MARK: - Filter Bar

    @ViewBuilder
    private var filterBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search prompts...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(6)
            .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            Picker("Role", selection: $roleFilter) {
                ForEach(RoleFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Entry List

    @ViewBuilder
    private var entryList: some View {
        if filteredEntries.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "text.bubble")
                    .font(.largeTitle)
                    .foregroundStyle(.quaternary)
                Text("No prompt history entries found.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(filteredEntries) { entry in
                        entryRow(entry)
                    }
                }
                .padding(20)
            }
        }
    }

    // MARK: - Entry Row

    @ViewBuilder
    private func entryRow(_ entry: PromptHistoryEntry) -> some View {
        let isExpanded = expandedEntryId == entry.id

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                roleBadge(entry.role)

                Text(entry.sessionId)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)

                Spacer()

                if let tokens = entry.tokensUsed {
                    Text("\(tokens) tokens")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if entry.timestamp != .distantPast {
                    Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Text(isExpanded ? entry.contentFull : entry.contentPreview)
                .font(.callout)
                .lineLimit(isExpanded ? nil : 3)
                .textSelection(.enabled)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            entry.isUserPrompt
                ? Color.blue.opacity(0.05)
                : Color.purple.opacity(0.05),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isExpanded {
                    expandedEntryId = nil
                } else {
                    expandedEntryId = entry.id
                }
            }
        }
    }

    // MARK: - Components

    @ViewBuilder
    private func roleBadge(_ role: String) -> some View {
        Text(role.capitalized)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                role == "user" ? Color.blue.opacity(0.15) : Color.purple.opacity(0.15),
                in: Capsule()
            )
            .foregroundStyle(role == "user" ? .blue : .purple)
    }
}

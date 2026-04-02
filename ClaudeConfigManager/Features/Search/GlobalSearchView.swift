import SwiftUI

/// A search overlay that appears when ⌘F is pressed, searching across all
/// resolved settings, discovered files, MCP servers, and hook event types.
struct GlobalSearchView: View {

    @ObservedObject var viewModel: GlobalSearchViewModel
    @FocusState private var isSearchFieldFocused: Bool

    /// Called when the user taps a result and wants to navigate.
    var onNavigate: ((GlobalSearchResult) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.title3)

                TextField("Search settings, files, MCP servers, hooks…", text: $viewModel.query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isSearchFieldFocused)
                    .onSubmit {
                        if let first = viewModel.results.first {
                            navigateToResult(first)
                        }
                    }

                if !viewModel.query.isEmpty {
                    Button {
                        viewModel.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button("Done") {
                    viewModel.dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Results or suggestions
            if viewModel.query.isEmpty {
                suggestedSearchesView
            } else if viewModel.results.isEmpty {
                emptyStateView
            } else {
                resultListView
            }
        }
        .frame(width: 580, height: 400)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
        .onAppear {
            isSearchFieldFocused = true
        }
    }

    // MARK: - Suggested Searches

    private var suggestedSearchesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested searches")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            FlowLayout(spacing: 8) {
                ForEach(GlobalSearchViewModel.suggestedSearches, id: \.self) { suggestion in
                    Button {
                        viewModel.query = suggestion
                    } label: {
                        Text(suggestion)
                            .font(.system(.callout, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No results for '\(viewModel.query)'")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Try searching for \"model\", \"permissions.deny\", or \"bash\".")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Result List

    private var resultListView: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(viewModel.results) { result in
                    searchResultRow(result)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func searchResultRow(_ result: GlobalSearchResult) -> some View {
        Button {
            navigateToResult(result)
        } label: {
            HStack(spacing: 10) {
                // Type badge
                Text(result.kind.badge)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(badgeColor(for: result.kind).opacity(0.12))
                    .foregroundStyle(badgeColor(for: result.kind))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .frame(width: 60)

                // Key/name
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)

                    Text(result.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Stage badge
                Text(result.stage.title)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .foregroundStyle(.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(result.kind.badge): \(result.title), in \(result.stage.title) stage")
    }

    // MARK: - Helpers

    private func navigateToResult(_ result: GlobalSearchResult) {
        viewModel.dismiss()
        onNavigate?(result)
    }

    private func badgeColor(for kind: SearchResultKind) -> Color {
        switch kind {
        case .setting: .blue
        case .file:    .green
        case .mcp:     .purple
        case .hook:    .orange
        }
    }
}

// MARK: - Flow Layout (for suggestion chips)

/// A simple horizontal wrapping layout for suggestion chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct LayoutResult {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }

        return LayoutResult(
            size: CGSize(width: maxX, height: currentY + lineHeight),
            positions: positions
        )
    }
}

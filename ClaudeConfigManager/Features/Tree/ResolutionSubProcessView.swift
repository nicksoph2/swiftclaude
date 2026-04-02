import SwiftUI

// MARK: - Merge Lane

/// One merge-method lane for the sub-process expansion diagram.
private struct MergeLane: Identifiable {
    let id: String
    let title: String
    let description: String
    let color: Color
    let icon: String
    let keys: [String]

    init(
        id: String,
        title: String,
        description: String,
        color: Color,
        icon: String,
        keys: [String]
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.color = color
        self.icon = icon
        self.keys = keys
    }
}

// MARK: - Resolution Sub-Process View

/// Renders the three merge-method lanes inside the Resolution stage detail view.
///
/// Shown when the "Show sub-processes" toggle is active (Z5 in the packet spec).
/// Derives example keys from the real resolved data.
struct ResolutionSubProcessView: View {

    /// All resolved entries, used to pick example keys per lane.
    let entries: [ResolutionEntryDisplay]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Merge sub-processes")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(alignment: .top, spacing: 12) {
                ForEach(lanes) { lane in
                    laneColumn(lane)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
    }

    // MARK: - Lane Column

    @ViewBuilder
    private func laneColumn(_ lane: MergeLane) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Lane header
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: lane.icon)
                        .font(.caption)
                        .foregroundStyle(lane.color)
                    Text(lane.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(lane.color)
                }
                Text(lane.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 4)

            // Key rows
            VStack(alignment: .leading, spacing: 6) {
                if lane.keys.isEmpty {
                    Text("No keys in this lane")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .italic()
                } else {
                    ForEach(lane.keys.prefix(5), id: \.self) { key in
                        keyRow(key, color: lane.color)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(lane.color.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(lane.color.opacity(0.25), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func keyRow(_ key: String, color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(color.opacity(0.5))
                .frame(width: 3, height: 14)
            Text(key)
                .font(.caption2.monospaced())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Image(systemName: "arrow.right")
                .font(.system(size: 8))
                .foregroundStyle(color.opacity(0.7))
        }
    }

    // MARK: - Lane Data

    private var lanes: [MergeLane] {
        [
            MergeLane(
                id: "override",
                title: "Override",
                description: "Highest-scope value wins",
                color: .blue,
                icon: "arrow.up.circle",
                keys: overrideKeys
            ),
            MergeLane(
                id: "appendUnique",
                title: "Append Unique",
                description: "Permission arrays, hook arrays",
                color: .purple,
                icon: "plus.circle",
                keys: appendUniqueKeys
            ),
            MergeLane(
                id: "deepMerge",
                title: "Deep Merge",
                description: "env object, sandbox object",
                color: .teal,
                icon: "arrow.triangle.merge",
                keys: deepMergeKeys
            ),
        ]
    }

    // MARK: - Key Selectors

    /// Keys that use selectHighestPrecedence / replace merge method (first 5).
    private var overrideKeys: [String] {
        entries
            .filter { $0.mergeMethod == .selectHighestPrecedence || $0.mergeMethod == .replace }
            .prefix(5)
            .map(\.keyPath)
    }

    /// Keys that use appendUnique / setUnion (first 5).
    private var appendUniqueKeys: [String] {
        entries
            .filter { $0.mergeMethod == .appendUnique || $0.mergeMethod == .setUnion || $0.mergeMethod == .append }
            .prefix(5)
            .map(\.keyPath)
    }

    /// Keys that use deepMergeObject / keyedByIdentifier (first 5).
    private var deepMergeKeys: [String] {
        entries
            .filter { $0.mergeMethod == .deepMergeObject || $0.mergeMethod == .keyedByIdentifier }
            .prefix(5)
            .map(\.keyPath)
    }
}

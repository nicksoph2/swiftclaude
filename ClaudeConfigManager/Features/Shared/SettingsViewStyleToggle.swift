import SwiftUI

/// Controls whether resolved settings are displayed as cards or compact table rows.
enum SettingsViewStyle: String {
    case card
    case table
}

/// A segmented control toggling between card and table view styles for settings lists.
struct SettingsViewStyleToggle: View {
    @Binding var style: SettingsViewStyle

    var body: some View {
        Picker("View style", selection: $style) {
            Image(systemName: "square.grid.2x2")
                .help("Card view")
                .tag(SettingsViewStyle.card)
            Image(systemName: "list.bullet")
                .help("Table view")
                .tag(SettingsViewStyle.table)
        }
        .pickerStyle(.segmented)
        .frame(width: 80)
    }
}

/// A compact single-line row for a resolved settings entry, used in table view mode.
/// Approximately 28pt height, showing key name, value, scope badge, and conflict indicator.
struct SettingsTableRow: View {
    let keyPath: String
    let value: String
    let scope: ResolutionScope?
    let hasConflict: Bool
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 8) {
                Text(keyPath)
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(1)
                    .frame(maxWidth: 200, alignment: .leading)

                Text(value)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 120, alignment: .leading)

                Spacer()

                if hasConflict {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }

                if let scope {
                    Text(scope.rawValue.localizedCapitalized)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(ScopeColorScheme.color(for: scope).opacity(0.15))
                        .foregroundStyle(ScopeColorScheme.color(for: scope))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .frame(height: 28)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

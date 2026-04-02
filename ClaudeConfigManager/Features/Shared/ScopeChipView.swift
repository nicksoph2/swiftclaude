import SwiftUI

/// Displays a scope-coloured chip with optional win/lose/contributor status.
///
/// Three display modes:
/// - `.winner`  — bold border, scope colour text, checkmark
/// - `.overridden` — faded, strikethrough value, crossed-out
/// - `.contributor` — normal border, scope colour, ⊕ prefix
/// - `.neutral` — plain scope badge, no status indicator
struct ScopeChipView: View {

    let scope: ResolutionScope
    let label: String
    let status: ChipStatus

    enum ChipStatus {
        case winner
        case overridden
        case contributor
        case neutral
    }

    init(scope: ResolutionScope, label: String, status: ChipStatus = .neutral) {
        self.scope = scope
        self.label = label
        self.status = status
    }

    var body: some View {
        HStack(spacing: 3) {
            if status == .contributor {
                Text("⊕")
                    .font(.system(size: 8, weight: .bold))
            }
            Text(chipText)
                .strikethrough(status == .overridden)
            if status == .winner {
                Image(systemName: "checkmark")
                    .font(.system(size: 7, weight: .bold))
            }
        }
        .font(.system(size: 9, weight: status == .winner ? .bold : .medium))
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(borderColor, lineWidth: status == .winner ? 1.2 : 0.8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .opacity(status == .overridden ? 0.45 : 1.0)
    }

    private var chipText: String {
        if label.isEmpty {
            return scope.rawValue.localizedCapitalized
        }
        return "\(scope.rawValue.localizedCapitalized): \(label)"
    }

    private var scopeColor: Color {
        ScopeColorScheme.color(for: scope)
    }

    private var foregroundColor: Color {
        switch status {
        case .winner:
            scopeColor
        case .overridden:
            .secondary
        case .contributor:
            scopeColor
        case .neutral:
            scopeColor
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .winner:
            scopeColor.opacity(0.1)
        case .overridden:
            Color.secondary.opacity(0.04)
        case .contributor:
            scopeColor.opacity(0.06)
        case .neutral:
            scopeColor.opacity(0.06)
        }
    }

    private var borderColor: Color {
        switch status {
        case .winner:
            scopeColor.opacity(0.4)
        case .overridden:
            Color.secondary.opacity(0.15)
        case .contributor:
            scopeColor.opacity(0.25)
        case .neutral:
            scopeColor.opacity(0.2)
        }
    }
}

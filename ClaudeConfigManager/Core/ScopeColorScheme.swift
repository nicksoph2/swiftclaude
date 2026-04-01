import SwiftUI

/// Maps `ResolutionScope` values to consistent SwiftUI colors used across the Tree view.
enum ScopeColorScheme {

    /// Returns the canonical color for a given resolution scope.
    static func color(for scope: ResolutionScope) -> Color {
        switch scope {
        case .managed:      .red
        case .user:         .blue
        case .project:      .green
        case .projectLocal: .teal
        case .session:      .orange
        case .cli:          .purple
        case .imported:     .secondary
        case .autoMemory:   .indigo
        case .synthetic:    .gray
        }
    }

    /// Returns a small badge `Text` view with a scope-colored background chip.
    @ViewBuilder
    static func scopeBadge(for scope: ResolutionScope) -> some View {
        Text(scope.rawValue.localizedCapitalized)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color(for: scope).opacity(0.15))
            .foregroundStyle(color(for: scope))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

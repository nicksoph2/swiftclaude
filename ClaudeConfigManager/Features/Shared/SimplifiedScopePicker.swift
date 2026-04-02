import SwiftUI

/// A scope picker that shows simplified options by default and expands to show all scopes
struct SimplifiedScopePicker: View {
    @Binding var selectedScope: ResolutionScope
    let availableScopes: [ResolutionScope]
    let recommendedScope: ResolutionScope
    let rationale: String

    @AppStorage("useSimplifiedScopePicker") var useSimplifiedUI: Bool = true
    @State private var showAdvanced: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save to:")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if useSimplifiedUI && !showAdvanced {
                simplifiedOptions
            } else {
                advancedOptions
            }

            if useSimplifiedUI {
                DisclosureGroup("Advanced options", isExpanded: $showAdvanced) {
                    advancedOptions
                }
            }

            // Rationale
            VStack(alignment: .leading, spacing: 4) {
                Text("Why recommended?")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(rationale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(8)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(6)
        }
    }

    @ViewBuilder
    private var simplifiedOptions: some View {
        VStack(spacing: 8) {
            Button(action: { selectScope(.project) }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("This project only")
                                .font(.body)
                            if selectedScope == .project {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                        Text("Applies only to this project")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.bordered)

            Button(action: { selectScope(.user) }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("All my projects")
                                .font(.body)
                            if selectedScope == .user {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                        Text("Applies to all your projects")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var advancedOptions: some View {
        VStack(spacing: 8) {
            ForEach(advancedScopeOptions, id: \.self) { scope in
                Button(action: { selectScope(scope) }) {
                    HStack {
                        Text(scopeLabel(scope))
                            .font(.body)
                        Spacer()
                        if selectedScope == scope {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var advancedScopeOptions: [ResolutionScope] {
        return availableScopes.filter { $0 != .managed && $0 != .cli }
    }

    private func scopeLabel(_ scope: ResolutionScope) -> String {
        switch scope {
        case .user:
            return "User scope (~/.claude/)"
        case .project:
            return "Project scope (.claude/)"
        case .projectLocal:
            return "Project local (.claude/settings.local.json)"
        case .session:
            return "Session scope"
        case .managed:
            return "Managed (read-only)"
        case .cli:
            return "CLI"
        case .imported:
            return "Imported"
        case .autoMemory:
            return "Auto memory"
        case .synthetic:
            return "Synthetic"
        }
    }

    private func selectScope(_ scope: ResolutionScope) {
        selectedScope = scope
        // If user selected non-simplified scope, disable simplified UI
        if !isSimplifiedScope(scope) {
            useSimplifiedUI = false
        }
    }

    private func isSimplifiedScope(_ scope: ResolutionScope) -> Bool {
        return scope == .user || scope == .project
    }
}

#Preview {
    @State var selected: ResolutionScope = .user
    return SimplifiedScopePicker(
        selectedScope: $selected,
        availableScopes: [.user, .project, .projectLocal],
        recommendedScope: .user,
        rationale: "This is a personal preference. Saving here applies it to all your projects."
    )
}

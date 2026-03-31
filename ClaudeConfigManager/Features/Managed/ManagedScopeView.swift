import SwiftUI

struct ManagedScopeView: View {
    let status: ManagedScopeStatusModel

    init(status: ManagedScopeStatusModel = ManagedScopeStatusModel(resolution: nil)) {
        self.status = status
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                // Show an explicit access-failure banner before the tier card so the user
                // never sees a silent "no managed config" when the real reason is a sandbox
                // restriction or a filesystem permission problem.
                if status.accessOutcome.requiresExplicitFallbackUI {
                    accessFallbackCard
                }
                activeTierCard
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Managed")
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Managed Configuration", systemImage: "building.2.crop.circle")
                .font(.largeTitle.weight(.semibold))

            Text("Managed Claude settings are inspected read-only. In App Store builds, system-managed files may be unavailable inside the sandbox; the app reports that explicitly rather than reading them through elevated helpers.")
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Access fallback banner (M4)

    /// Shown whenever the managed root path could not be read — either because the macOS App
    /// Sandbox blocked access or because of an unexpected filesystem condition. This card ensures
    /// the limitation is always visible and never a silent omission.
    @ViewBuilder
    private var accessFallbackCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(accessFallbackTitle, systemImage: accessFallbackIcon)
                .font(.headline)
                .foregroundStyle(accessFallbackTint)

            Text(accessFallbackMessage)
                .foregroundStyle(.secondary)

            if case .inaccessible(let diagnostics) = status.accessOutcome,
               let diagnostics {
                Divider()
                Text(diagnostics)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accessFallbackBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(accessFallbackTint.opacity(0.35))
        )
    }

    private var accessFallbackTitle: String {
        switch status.accessOutcome {
        case .sandboxRestricted:
            return "Managed path not accessible in sandbox"
        case .inaccessible:
            return "Managed path inaccessible"
        default:
            return "Managed path unavailable"
        }
    }

    private var accessFallbackIcon: String {
        switch status.accessOutcome {
        case .sandboxRestricted:
            return "lock.shield"
        case .inaccessible:
            return "exclamationmark.triangle"
        default:
            return "exclamationmark.circle"
        }
    }

    private var accessFallbackMessage: String {
        switch status.accessOutcome {
        case .sandboxRestricted:
            return """
            The managed ClaudeCode configuration directory (/Library/Application Support/ClaudeCode/) \
            is not reachable from within the macOS App Sandbox. This is expected for standard App Store builds \
            that have not been granted explicit access to system library paths. \
            If managed policy has been deployed on this machine, it cannot be inspected by this build of the app.
            """
        case .inaccessible:
            return """
            The managed ClaudeCode configuration directory (/Library/Application Support/ClaudeCode/) \
            exists but could not be read. Check that the directory permissions allow read access for \
            the current user, or that no security policy is blocking access.
            """
        default:
            return "The managed configuration path is not accessible."
        }
    }

    private var accessFallbackTint: Color {
        switch status.accessOutcome {
        case .sandboxRestricted:
            return .orange
        case .inaccessible:
            return .red
        default:
            return .yellow
        }
    }

    private var accessFallbackBackground: AnyShapeStyle {
        switch status.accessOutcome {
        case .sandboxRestricted:
            return AnyShapeStyle(.orange.opacity(0.06))
        case .inaccessible:
            return AnyShapeStyle(.red.opacity(0.06))
        default:
            return AnyShapeStyle(.yellow.opacity(0.06))
        }
    }

    // MARK: - Active tier card

    private var activeTierCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(status.title)
                .font(.headline)

            Text(status.detail)
                .foregroundStyle(.secondary)

            if !status.sourceSummaries.isEmpty {
                Divider()

                ForEach(status.sourceSummaries, id: \.self) { summary in
                    Label(summary, systemImage: "doc.text")
                        .font(.subheadline)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.separator.opacity(0.35))
        )
    }
}

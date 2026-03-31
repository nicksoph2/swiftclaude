import SwiftUI

struct UserScopeView: View {
    @EnvironmentObject private var rootSelection: RootSelectionViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard

                if let issue = rootSelection.issue, issue.area == .globalRoot {
                    issueCard(issue)
                }

                globalRootCard
                precedenceReminderCard
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("User")
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Global Claude Root", systemImage: "folder.badge.gearshape")
                .font(.largeTitle.weight(.semibold))

            Text("Select the folder used for global discovery. This is discovery configuration only.")
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var globalRootCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Current root")
                    .font(.headline)
                Spacer()
                sourceBadge
            }

            Text(rootSelection.selectedGlobalRootURL.path)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)

            Text("Default root: \(rootSelection.defaultGlobalRootURL.path)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("Choose Override…") {
                    rootSelection.selectGlobalRootOverride()
                }
                Button("Use Default") {
                    rootSelection.useDefaultGlobalRoot()
                }
                .disabled(rootSelection.globalRootSource == .defaultHomeClaude)
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

    private var precedenceReminderCard: some View {
        Text("Changing this root does not change Claude configuration precedence rules.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var sourceBadge: some View {
        Text(rootSelection.globalRootSourceLabel)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                rootSelection.globalRootSource == .defaultHomeClaude
                    ? Color.gray.opacity(0.18)
                    : Color.green.opacity(0.18),
                in: Capsule()
            )
    }

    private func issueCard(_ issue: RootSelectionIssue) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text("Validation Message")
                    .font(.headline)
                Text(issue.message)
                    .font(.subheadline)
            }
            Spacer()
            Button("Dismiss") {
                rootSelection.clearIssue(for: .globalRoot)
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

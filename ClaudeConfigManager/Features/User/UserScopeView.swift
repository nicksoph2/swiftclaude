import SwiftUI

struct UserScopeView: View {
    @EnvironmentObject private var rootSelection: RootSelectionViewModel
    @State private var showSettingsEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard

                if let issue = rootSelection.issue, issue.area == .globalRoot {
                    issueCard(issue)
                }

                globalRootCard
                precedenceReminderCard

                editSettingsButton

                ScopeContributionSummaryView(targetScope: .user)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("User")
        .sheet(isPresented: $showSettingsEditor) {
            let userSettingsURL = rootSelection.selectedGlobalRootURL
                .appendingPathComponent(".claude")
                .appendingPathComponent("settings.json")
            UserSettingsEditorSheet(fileURL: userSettingsURL)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Global Claude Root", systemImage: "folder.badge.gearshape")
                .font(.largeTitle.weight(.semibold))

            Text("Select the folder used for global discovery. The app uses user-granted, read-only access and does not write into Claude-managed folders.")
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

            Text(rootSelection.hasAuthorizedGlobalRoot ? rootSelection.selectedGlobalRootURL.path : "No authorized global folder")
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)

            Text("Recommended default: \(rootSelection.defaultGlobalRootURL.path)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(rootSelection.recommendedGlobalRootIsAvailable
                ? "The recommended Claude folder is available. Use the button below to grant read-only access."
                : "The recommended Claude folder is not currently available, so choose another folder if you want global discovery.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("Choose Folder…") {
                    rootSelection.chooseGlobalRootFolder()
                }
                Button("Use Recommended Default") {
                    rootSelection.authorizeRecommendedGlobalRoot()
                }
                .disabled(!rootSelection.recommendedGlobalRootIsAvailable)
                Button("Clear Selection") {
                    rootSelection.clearGlobalRootSelection()
                }
                .disabled(!rootSelection.hasAuthorizedGlobalRoot)
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
        Text("Changing this folder changes only where the app reads global Claude files from. It does not change Claude’s own configuration precedence rules.")
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
                rootSelection.hasAuthorizedGlobalRoot
                    ? (rootSelection.globalRootSource == .defaultHomeClaude
                        ? Color.gray.opacity(0.18)
                        : Color.green.opacity(0.18))
                    : Color.orange.opacity(0.18),
                in: Capsule()
            )
    }

    private var editSettingsButton: some View {
        Button(action: { showSettingsEditor = true }) {
            HStack {
                Image(systemName: "pencil.circle.fill")
                Text("Edit settings.json")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.blue)
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

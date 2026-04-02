import SwiftUI

struct ProjectScopeView: View {
    @EnvironmentObject private var rootSelection: RootSelectionViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard

                if let issue = rootSelection.issue, issue.area == .projects {
                    issueCard(issue)
                }

                projectRegistryCard
                precedenceReminderCard
                ScopeContributionSummaryView(targetScope: .project)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Project")
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Project Roots", systemImage: "folder.badge.plus")
                .font(.largeTitle.weight(.semibold))

            Text("Register one or more project folders for discovery.")
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var projectRegistryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Registered projects")
                    .font(.headline)
                Spacer()
                Button("Add Project…") {
                    rootSelection.addProjectRoot()
                }
            }

            if rootSelection.projectRegistrations.isEmpty {
                Text("No projects selected yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rootSelection.projectRegistrations) { project in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button {
                                rootSelection.selectProject(id: project.id)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: isSelected(project) ? "checkmark.circle.fill" : "circle")
                                    Text(project.displayName)
                                }
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button("Remove") {
                                rootSelection.removeProject(id: project.id)
                            }
                            .buttonStyle(.borderless)
                        }

                        Text(project.preferredPath)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    private var precedenceReminderCard: some View {
        Text("Project registration controls discovery only. It does not alter Claude precedence.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func isSelected(_ project: ProjectRegistration) -> Bool {
        rootSelection.selectedProjectRegistrationID == project.id
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
                rootSelection.clearIssue(for: .projects)
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

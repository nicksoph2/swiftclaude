import SwiftUI

// MARK: - Profile Manager View

@MainActor
struct ProfileManagerView: View {
    @EnvironmentObject private var pipeline: ConfigurationPipeline
    @ObservedObject var profileStore: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var showingCreateSheet = false
    @State private var renamingProfile: ConfigurationProfile?
    @State private var renameText = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            if profileStore.profiles.isEmpty {
                emptyState
            } else {
                profileList
            }
        }
        .frame(minWidth: 500, minHeight: 350)
        .sheet(isPresented: $showingCreateSheet) {
            ProfileCreateSheet(profileStore: profileStore)
                .environmentObject(pipeline)
        }
        .alert("Rename Profile", isPresented: .init(
            get: { renamingProfile != nil },
            set: { if !$0 { renamingProfile = nil } }
        )) {
            TextField("Profile Name", text: $renameText)
            Button("Rename") {
                if let profile = renamingProfile {
                    do {
                        try profileStore.rename(profile, to: renameText)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                renamingProfile = nil
            }
            Button("Cancel", role: .cancel) {
                renamingProfile = nil
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Text("Configuration Profiles")
                .font(.headline)
            Spacer()
            Button {
                showingCreateSheet = true
            } label: {
                Label("Create Profile", systemImage: "plus")
            }
            .disabled(pipeline.projection == nil)

            Button("Done") {
                dismiss()
            }
        }
        .padding(16)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "square.stack.3d.up.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No Profiles")
                .font(.title3.weight(.medium))
            Text("Create a profile to capture the current settings for a scope.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(24)
    }

    private var profileList: some View {
        List {
            ForEach(profileStore.profiles) { profile in
                profileRow(profile)
            }
        }
        .listStyle(.inset)
    }

    private func profileRow(_ profile: ConfigurationProfile) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.body.weight(.medium))

                HStack(spacing: 8) {
                    if let scope = profile.resolutionScope {
                        ScopeColorScheme.scopeBadge(for: scope)
                    } else {
                        Text(profile.scope)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("\(profile.keyCount) settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(profile.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if let desc = profile.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Button("Rename") {
                    renameText = profile.name
                    renamingProfile = profile
                }
                .buttonStyle(.borderless)

                Button("Duplicate") {
                    try? profileStore.duplicate(profile)
                }
                .buttonStyle(.borderless)

                Button(role: .destructive) {
                    profileStore.delete(profile)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Profile Create Sheet

@MainActor
struct ProfileCreateSheet: View {
    @EnvironmentObject private var pipeline: ConfigurationPipeline
    @ObservedObject var profileStore: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var profileName = ""
    @State private var selectedScope: ResolutionScope = .user
    @State private var profileDescription = ""
    @State private var errorMessage: String?

    private let availableScopes: [ResolutionScope] = [
        .managed, .user, .project, .projectLocal
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text("Create Profile from Current Settings")
                .font(.headline)

            Form {
                TextField("Profile Name", text: $profileName)

                Picker("Scope", selection: $selectedScope) {
                    ForEach(availableScopes, id: \.rawValue) { scope in
                        Text(scope.rawValue.capitalized).tag(scope)
                    }
                }

                TextField("Description (optional)", text: $profileDescription)
            }
            .formStyle(.grouped)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    createProfile()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(profileName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 400)
    }

    private func createProfile() {
        guard let projection = pipeline.projection else {
            errorMessage = "No pipeline data available."
            return
        }

        do {
            _ = try profileStore.createFromProjection(
                name: profileName.trimmingCharacters(in: .whitespaces),
                scope: selectedScope,
                projection: projection,
                description: profileDescription.isEmpty ? nil : profileDescription
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

import SwiftUI

/// Stage 7 — MCP Servers detail view.
///
/// Displays a tool landscape tree with two sections:
/// 1. **Built-in Tools** — all 18 tools from `BuiltInToolCatalog`
/// 2. **MCP Servers** — resolved servers from the pipeline with transport type,
///    scope badges, blocked/active status, and override relationships.
///
/// Includes a deferred loading note explaining that MCP tool lists are
/// discovered lazily at runtime.
struct TreeMCPView: View {

    @EnvironmentObject private var pipeline: ConfigurationPipeline
    @StateObject private var viewModel = TreeMCPViewModel()

    /// Optional callback for cross-stage navigation.
    var onNavigate: ((TreeNavigationTarget) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StageExplanationView(stage: .mcpServers)

            if viewModel.landscapeNodes.isEmpty {
                noDataPlaceholder
            } else {
                teachingCallout
                healthIssuesBanner
                toolCatalogSection
                mcpServersSection
                deferredLoadingNote
            }
        }
        .onAppear {
            viewModel.bind(to: pipeline)
        }
    }

    // MARK: - No Data

    private var noDataPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "server.rack")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No MCP server data available")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Run the pipeline to see built-in tools and configured MCP servers.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    // MARK: - Teaching Callout

    private var teachingCallout: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
                .font(.callout)

            Text("Claude Code has 18 built-in tools available in every session. MCP (Model Context Protocol) servers extend this with additional tools. Servers can be configured at user or project scope, and policies control which servers are allowed.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.yellow.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.yellow.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Health Issues Banner

    @ViewBuilder
    private var healthIssuesBanner: some View {
        if !viewModel.healthIssues.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("Server Health Issues")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }

                ForEach(Array(viewModel.healthIssues.enumerated()), id: \.offset) { _, issue in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: issue.severity == .error ? "xmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(issue.severity == .error ? .red : .orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(issue.serverId)
                                .font(.system(.caption2, design: .monospaced).weight(.medium))
                            Text(issue.message)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.orange.opacity(0.2), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Tool Catalog Section

    private var toolCatalogSection: some View {
        MCPToolCatalogView(
            builtInTools: BuiltInToolCatalog.tools,
            mcpServers: viewModel.activeServers + viewModel.blockedServers
        )
    }

    // MARK: - Built-in Tools Section (Legacy)

    private var builtInToolsSection: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(BuiltInToolCatalog.tools) { tool in
                    builtInToolRow(tool)
                }
            }
            .padding(.top, 4)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)

                Text("Built-in Tools")
                    .font(.subheadline.weight(.medium))

                Spacer()

                Text("\(BuiltInToolCatalog.tools.count) tools")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
        )
    }

    private func builtInToolRow(_ tool: BuiltInToolCatalog.Tool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(width: 12)

            Text(tool.name)
                .font(.system(.caption, design: .monospaced).weight(.medium))

            Text("—")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text(tool.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
    }

    // MARK: - MCP Servers Section

    private var mcpServersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "server.rack")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)

                Text("MCP Servers")
                    .font(.subheadline.weight(.medium))

                Spacer()

                serverCountBadge
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            if !viewModel.globalPolicyEffects.isEmpty {
                globalPolicyBanner
            }

            if viewModel.activeServers.isEmpty && viewModel.blockedServers.isEmpty {
                noServersPlaceholder
            } else {
                if !viewModel.activeServers.isEmpty {
                    ForEach(viewModel.activeServers) { server in
                        serverCard(server)
                            .id(TreeNavigationTarget.mcpServerPolicy(server.serverID).anchorID)
                    }
                }

                if !viewModel.blockedServers.isEmpty {
                    blockedServersHeader
                    ForEach(viewModel.blockedServers) { server in
                        serverCard(server)
                            .id(TreeNavigationTarget.mcpServerPolicy(server.serverID).anchorID)
                    }
                }
            }
        }
        .padding(.bottom, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
        )
    }

    private var serverCountBadge: some View {
        HStack(spacing: 6) {
            if !viewModel.activeServers.isEmpty {
                Text("\(viewModel.activeServers.count) active")
                    .font(.caption2)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            if !viewModel.blockedServers.isEmpty {
                Text("\(viewModel.blockedServers.count) blocked")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            if viewModel.activeServers.isEmpty && viewModel.blockedServers.isEmpty {
                Text("None")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var globalPolicyBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(viewModel.globalPolicyEffects.enumerated()), id: \.offset) { _, effect in
                HStack(spacing: 6) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(effect.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.orange.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.orange.opacity(0.2), lineWidth: 0.5)
        )
        .padding(.horizontal, 12)
    }

    private var noServersPlaceholder: some View {
        Text("No MCP servers configured. Add servers to your settings.json or .mcp.json to extend Claude's capabilities.")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
    }

    private var blockedServersHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "xmark.shield.fill")
                .font(.caption)
                .foregroundStyle(.red)
            Text("Blocked Servers")
                .font(.caption.weight(.medium))
                .foregroundStyle(.red)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    // MARK: - Server Card

    private func serverCard(_ server: MCPServerDisplayModel) -> some View {
        DisclosureGroup {
            serverCardExpandedContent(server)
                .padding(.top, 4)
        } label: {
            serverCardHeader(server)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func serverCardHeader(_ server: MCPServerDisplayModel) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(serverStatusColor(server))
                .frame(width: 8, height: 8)

            Text(server.serverID)
                .font(.system(.subheadline, design: .monospaced).weight(.medium))
                .strikethrough(server.isBlocked)
                .foregroundStyle(server.isBlocked ? .secondary : .primary)

            Spacer()

            transportBadge(server.transportType)

            if let scope = server.sourceScope {
                ScopeColorScheme.scopeBadge(for: scope)
            }

            serverStatusBadge(server)
        }
    }

    @ViewBuilder
    private func serverCardExpandedContent(_ server: MCPServerDisplayModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let detail = server.transportDetail {
                detailRow(icon: "terminal", label: "Transport", value: detail, isMonospaced: true)
            }

            if let path = server.sourcePath {
                detailRow(icon: "doc", label: "Source", value: path, isMonospaced: true)
            }

            if let explanation = server.policyExplanation, !explanation.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: server.isBlocked ? "exclamationmark.triangle.fill" : "info.circle")
                        .font(.caption)
                        .foregroundStyle(server.isBlocked ? .red : .secondary)
                        .frame(width: 14)

                    Text(explanation)
                        .font(.caption)
                        .foregroundStyle(server.isBlocked ? .red.opacity(0.8) : .secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(server.isBlocked
                              ? Color.red.opacity(0.05)
                              : Color(nsColor: .textBackgroundColor).opacity(0.5))
                )
            }

            if !server.overrides.isEmpty {
                overrideRelationships(server.overrides, serverID: server.serverID)
            }

            if !server.environmentNotes.isEmpty {
                environmentNotesSection(server.environmentNotes)
            }

            // Stage 7 → Stage 3: Cross-nav to Resolution for blocked-server policy settings
            if server.isBlocked {
                Button {
                    onNavigate?(.resolutionKey("mcpServers"))
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle")
                            .font(.caption)
                        Text("View in Resolution")
                            .font(.caption)
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                .help("Jump to the mcpServers entry in Stage 3 — Resolution")
            }
        }
    }

    private func detailRow(icon: String, label: String, value: String, isMonospaced: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14)

            Text(label + ":")
                .font(.caption)
                .foregroundStyle(.secondary)

            if isMonospaced {
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(3)
            } else {
                Text(value)
                    .font(.caption)
                    .lineLimit(3)
            }
        }
    }

    private func overrideRelationships(_ overrides: [MCPOverrideRelationship], serverID: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(overrides.enumerated()), id: \.offset) { _, override_ in
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.caption2)
                        .foregroundStyle(.orange)

                    Text("Overrides:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("\(serverID)")
                        .font(.system(.caption2, design: .monospaced))

                    Text("from")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    ScopeColorScheme.scopeBadge(for: override_.overriddenScope)
                }
            }
        }
    }

    private func environmentNotesSection(_ notes: [McpEnvironmentNote]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Environment")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)

            ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                HStack(spacing: 6) {
                    Image(systemName: environmentNoteIcon(for: note.classification))
                        .font(.caption2)
                        .foregroundStyle(environmentNoteColor(for: note.classification))

                    Text(note.fieldPath)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Text("— \(note.message)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.5))
        )
    }

    // MARK: - Deferred Loading Note

    private var deferredLoadingNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("MCP tools are loaded lazily — each server's full tool list is only discovered when Claude first connects to it during a session. The tools shown here reflect the server configuration, not the runtime tool inventory.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.04))
        )
    }

    // MARK: - Styling Helpers

    private func serverStatusColor(_ server: MCPServerDisplayModel) -> Color {
        switch server.effectiveState {
        case .active: .green
        case .managed: ScopeColorScheme.color(for: .managed)
        case .blocked, .disabled: .red
        case .unresolved: .gray
        }
    }

    private func transportBadge(_ type: MCPTransportType) -> some View {
        Text(type.rawValue.uppercased())
            .font(.system(.caption2, design: .monospaced).weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(transportBadgeColor(type).opacity(0.1))
            .foregroundStyle(transportBadgeColor(type))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func transportBadgeColor(_ type: MCPTransportType) -> Color {
        switch type {
        case .stdio: .purple
        case .http: .cyan
        case .unknown: .secondary
        }
    }

    private func serverStatusBadge(_ server: MCPServerDisplayModel) -> some View {
        Group {
            switch server.effectiveState {
            case .active:
                Label("Active", systemImage: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            case .managed:
                Label("Managed", systemImage: "building.2.fill")
                    .font(.caption2)
                    .foregroundStyle(ScopeColorScheme.color(for: .managed))
            case .blocked:
                Label("Blocked", systemImage: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
            case .disabled:
                Label("Disabled", systemImage: "slash.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
            case .unresolved:
                Label("Unresolved", systemImage: "questionmark.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func environmentNoteIcon(for classification: McpEnvironmentClassification) -> String {
        switch classification {
        case .staticLiteral: "checkmark.circle"
        case .containsReference: "dollarsign.circle"
        case .unresolvedReference: "exclamationmark.triangle"
        }
    }

    private func environmentNoteColor(for classification: McpEnvironmentClassification) -> Color {
        switch classification {
        case .staticLiteral: .green
        case .containsReference: .orange
        case .unresolvedReference: .red
        }
    }
}

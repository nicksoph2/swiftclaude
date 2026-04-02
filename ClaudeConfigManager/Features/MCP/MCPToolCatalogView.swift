import SwiftUI

/// Searchable, grouped list of all tools available in the current configuration.
///
/// Two sections:
/// 1. **Built-in tools** — from `BuiltInToolCatalog`, grouped by category.
/// 2. **MCP server tools** — one sub-group per active server from the pipeline.
///
/// Includes a total capability summary and tap-to-inspect popovers.
struct MCPToolCatalogView: View {

    let builtInTools: [BuiltInToolCatalog.Tool]
    let mcpServers: [MCPServerDisplayModel]

    @State private var searchText: String = ""
    @State private var selectedBuiltInTool: BuiltInToolCatalog.Tool?
    @State private var selectedMCPServer: MCPServerDisplayModel?

    // MARK: - Computed

    private var filteredBuiltInTools: [BuiltInToolCatalog.Tool] {
        guard !searchText.isEmpty else { return builtInTools }
        let query = searchText.lowercased()
        return builtInTools.filter {
            $0.name.lowercased().contains(query) || $0.description.lowercased().contains(query)
        }
    }

    private var filteredServers: [MCPServerDisplayModel] {
        guard !searchText.isEmpty else { return mcpServers.filter { !$0.isBlocked } }
        let query = searchText.lowercased()
        return mcpServers.filter { server in
            guard !server.isBlocked else { return false }
            return server.serverID.lowercased().contains(query)
                || (server.transportDetail?.lowercased().contains(query) ?? false)
        }
    }

    private var activeServerCount: Int {
        mcpServers.filter { !$0.isBlocked }.count
    }

    private var totalToolCount: Int {
        builtInTools.count + activeServerCount
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            capabilitySummary
            searchBar
            builtInSection
            mcpServersSection
        }
    }

    // MARK: - Capability Summary

    private var capabilitySummary: some View {
        HStack(spacing: 6) {
            Image(systemName: "hammer.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            (Text("Claude has access to ") + Text("\(totalToolCount) tools").bold() + Text(" in this configuration (\(builtInTools.count) built-in + \(activeServerCount) from \(activeServerCount) server\(activeServerCount == 1 ? "" : "s"))."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.accentColor.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Filter tools by name or description…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.caption)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }

    // MARK: - Built-in Tools

    private var builtInSection: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(filteredBuiltInTools) { tool in
                    builtInToolRow(tool)
                }

                if filteredBuiltInTools.isEmpty {
                    Text("No built-in tools match \"\(searchText)\"")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
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

                Text("\(filteredBuiltInTools.count) tools")
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
        Button {
            selectedBuiltInTool = (selectedBuiltInTool?.id == tool.id) ? nil : tool
        } label: {
            HStack(spacing: 8) {
                Text(tool.name)
                    .font(.system(.caption, design: .monospaced).weight(.medium))
                    .foregroundStyle(.primary)

                categoryBadge(tool.category)

                Text(tool.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: Binding(
            get: { selectedBuiltInTool?.id == tool.id },
            set: { if !$0 { selectedBuiltInTool = nil } }
        )) {
            builtInToolPopover(tool)
        }
    }

    private func categoryBadge(_ category: ToolCategory) -> some View {
        Text(category.rawValue)
            .font(.system(.caption2, design: .rounded).weight(.medium))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .foregroundStyle(categoryColor(category))
            .background(categoryColor(category).opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private func categoryColor(_ category: ToolCategory) -> Color {
        switch category {
        case .fileSystem: return .blue
        case .shell: return .purple
        case .search: return .green
        case .memory: return .orange
        case .mcp: return .cyan
        case .agent: return .indigo
        case .other: return .secondary
        }
    }

    private func builtInToolPopover(_ tool: BuiltInToolCatalog.Tool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(tool.name)
                    .font(.system(.body, design: .monospaced).weight(.bold))
                categoryBadge(tool.category)
            }

            Text(tool.description)
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()

            Text("Parameters")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(tool.inputSummary)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
        }
        .padding(12)
        .frame(minWidth: 280, maxWidth: 360)
    }

    // MARK: - MCP Servers

    private var mcpServersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if filteredServers.isEmpty && searchText.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 20)

                    Text("MCP Server Tools")
                        .font(.subheadline.weight(.medium))

                    Spacer()

                    Text("None")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            } else {
                ForEach(filteredServers) { server in
                    mcpServerGroup(server)
                }

                if filteredServers.isEmpty && !searchText.isEmpty {
                    Text("No MCP servers match \"\(searchText)\"")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                }
            }
        }
    }

    private func mcpServerGroup(_ server: MCPServerDisplayModel) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 4) {
                if let detail = server.transportDetail {
                    HStack(spacing: 6) {
                        Text("Transport:")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(detail)
                            .font(.system(.caption2, design: .monospaced))
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                }

                Text("Tools are discovered at runtime when Claude connects to this server.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
            }
            .padding(.top, 4)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "server.rack")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)

                Text(server.serverID)
                    .font(.system(.subheadline, design: .monospaced).weight(.medium))

                Spacer()

                if let scope = server.sourceScope {
                    ScopeColorScheme.scopeBadge(for: scope)
                }

                transportBadge(server.transportType)
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

    private func transportBadge(_ type: MCPTransportType) -> some View {
        Text(type.rawValue.uppercased())
            .font(.system(.caption2, design: .monospaced).weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(transportColor(type).opacity(0.1))
            .foregroundStyle(transportColor(type))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func transportColor(_ type: MCPTransportType) -> Color {
        switch type {
        case .stdio: return .purple
        case .http: return .cyan
        case .unknown: return .secondary
        }
    }
}

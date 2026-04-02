import SwiftUI

/// Card-style display for a single resolved MCP server entry.
/// Shows server name, scope badge, transport icon, validation status, and config detail.
struct MCPServerCardView: View {
    let server: ResolvedMcpServerEntry
    let onEdit: (() -> Void)?

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 10) {
                // Transport icon
                Image(systemName: transportIcon)
                    .font(.title3)
                    .foregroundStyle(transportColor)
                    .frame(width: 28, height: 28)

                // Server name
                VStack(alignment: .leading, spacing: 2) {
                    Text(server.serverID)
                        .font(.body.weight(.bold))
                        .lineLimit(1)

                    if !server.stateExplanation.isEmpty {
                        Text(server.stateExplanation)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Scope badge
                if let source = server.resolvedConfig.winningSource {
                    ScopeColorScheme.scopeBadge(for: source.scope)
                }

                // Validation status
                validationStatusIcon

                // Overridden callout
                if !server.resolvedConfig.trace.overridden.isEmpty {
                    overriddenCallout
                }

                // Edit button
                if let onEdit {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Edit server configuration")
                }

                // Disclosure chevron
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .buttonStyle(.plain)
            }
            .padding(12)

            // Expanded detail
            if isExpanded {
                Divider()
                    .padding(.horizontal, 12)

                configDetailSection
                    .padding(12)
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(cardBorderColor, lineWidth: 0.5)
        )
        .opacity(isSuppressed ? 0.5 : 1.0)
    }

    // MARK: - Transport

    private var transportIcon: String {
        guard let config = server.resolvedConfig.effectiveValue,
              case .object(let obj) = config else {
            return "questionmark.circle"
        }

        let transport = obj["type"]?.stringValue ?? obj["transport"]?.stringValue
        if transport == "http" {
            return "globe"
        } else {
            return "terminal"
        }
    }

    private var transportColor: Color {
        guard let config = server.resolvedConfig.effectiveValue,
              case .object(let obj) = config else {
            return .secondary
        }

        let transport = obj["type"]?.stringValue ?? obj["transport"]?.stringValue
        if transport == "http" {
            return .blue
        } else {
            return .purple
        }
    }

    // MARK: - Validation Status

    private var validationStatusIcon: some View {
        Group {
            switch server.effectiveState {
            case .active:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .help("Server is active and complete")
            case .disabled:
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.gray)
                    .help("Server is disabled")
            case .blocked:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                    .help("Server is blocked by policy")
            case .managed:
                Image(systemName: "lock.circle.fill")
                    .foregroundStyle(.orange)
                    .help("Managed server — cannot be overridden")
            case .unresolved:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                    .help("Missing required fields")
            }
        }
        .font(.body)
    }

    // MARK: - Overridden Callout

    private var overriddenCallout: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.triangle.branch")
                .font(.caption2)
            if let overrider = server.resolvedConfig.trace.overridden.first {
                Text("Overridden by \(overrider.scope.rawValue)")
                    .font(.caption2)
            }
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    /// Whether this card represents a server that has been overridden by a higher-precedence scope.
    private var isSuppressed: Bool {
        !server.resolvedConfig.trace.overridden.isEmpty
    }

    // MARK: - Config Detail

    private var configDetailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let config = server.resolvedConfig.effectiveValue,
               case .object(let obj) = config {
                ForEach(obj.keys.sorted(), id: \.self) { key in
                    configRow(key: key, value: obj[key]!)
                }
            } else {
                Text("No configuration data available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Environment notes
            if !server.environmentNotes.isEmpty {
                Divider()
                Text("Environment Notes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(server.environmentNotes, id: \.fieldPath) { note in
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                        Text(note.message)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Policy effects
            if !server.policyEffects.isEmpty {
                Divider()
                Text("Policy Effects")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(Array(server.policyEffects.enumerated()), id: \.offset) { _, effect in
                    HStack(spacing: 6) {
                        Image(systemName: "shield")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text(effect.message)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Override "what differs" expansion
            if isSuppressed {
                Divider()
                overrideDiffSection
            }
        }
    }

    /// Shows which fields differ between the winning definition and each overridden source.
    private var overrideDiffSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.swap")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("What Differs")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            ForEach(server.resolvedConfig.trace.overridden, id: \.id) { overrider in
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Overridden by \(overrider.scope.rawValue) scope")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let path = overrider.sourcePath {
                        Text("(\(path))")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }

            Text("The overriding scope's definition takes precedence. Fields such as command, environment variables, or URL may differ.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func configRow(key: String, value: JSONValue) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(key)
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)

            Text(valueDisplayString(value))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(3)

            Spacer()
        }
    }

    private func valueDisplayString(_ value: JSONValue) -> String {
        switch value {
        case .string(let s):
            return s
        case .number(let n):
            return String(n)
        case .bool(let b):
            return b ? "true" : "false"
        case .array(let arr):
            let items = arr.prefix(3).map { itemString($0) }.joined(separator: ", ")
            return arr.count > 3 ? "[\(items), ...]" : "[\(items)]"
        case .object(let obj):
            return "{\(obj.count) keys}"
        case .null:
            return "null"
        }
    }

    private func itemString(_ value: JSONValue) -> String {
        if case .string(let s) = value { return s }
        return valueDisplayString(value)
    }

    // MARK: - Card Styling

    private var cardBackground: Color {
        switch server.effectiveState {
        case .active:
            return Color(nsColor: .controlBackgroundColor)
        case .disabled:
            return Color(nsColor: .controlBackgroundColor).opacity(0.6)
        case .blocked:
            return Color.red.opacity(0.03)
        case .managed:
            return Color.orange.opacity(0.03)
        case .unresolved:
            return Color.red.opacity(0.05)
        }
    }

    private var cardBorderColor: Color {
        switch server.effectiveState {
        case .active:
            return .gray.opacity(0.3)
        case .blocked:
            return .red.opacity(0.3)
        case .managed:
            return .orange.opacity(0.3)
        default:
            return .gray.opacity(0.2)
        }
    }
}

// MARK: - McpEnvironmentNote Identifiable conformance

extension McpEnvironmentNote: Identifiable {
    var id: String { "\(fieldPath):\(message)" }
}

#Preview {
    let mockSource = ResolutionSource(
        scope: .user,
        kind: .file,
        identifier: "user-mcp",
        displayName: "User MCP Config",
        sourcePath: "~/.claude.json"
    )

    let server = ResolvedMcpServerEntry(
        serverID: "filesystem",
        resolvedConfig: ResolvedValue(
            effectiveValue: .object([
                "command": .string("npx"),
                "args": .array([.string("-y"), .string("@modelcontextprotocol/server-filesystem"), .string("/Users/test")]),
            ]),
            winningSource: mockSource,
            trace: ResolutionTrace(participants: [mockSource]),
            mergeMethod: .selectHighestPrecedence
        ),
        effectiveState: .active,
        stateExplanation: "Active — all fields present"
    )

    return MCPServerCardView(
        server: server,
        onEdit: { }
    )
    .frame(width: 500)
    .padding()
}

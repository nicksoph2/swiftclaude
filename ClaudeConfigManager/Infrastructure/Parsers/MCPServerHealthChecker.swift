import Foundation

/// Severity-qualified health issue for an MCP server configuration.
struct MCPHealthIssue: Equatable, Sendable {
    let serverId: String
    let severity: IssueSeverity
    let code: MCPHealthCode
    let message: String
}

/// Categorized health-check codes for MCP server validation.
enum MCPHealthCode: Equatable, Sendable {
    case commandNotFound(path: String)
    case commandNotExecutable(path: String)
    case invalidUrl(url: String)
    case missingRequiredField(field: String)
}

/// Validates MCP server configurations for runtime viability.
///
/// Checks include:
/// - **stdio**: command exists on disk (absolute) or on PATH (bare name), and is executable.
/// - **http**: URL parses successfully with http/https scheme and non-empty host.
/// - **Required fields**: `command` for stdio, `url` for http.
struct MCPServerHealthChecker {

    // MARK: - Public API

    /// Run health checks against a list of resolved MCP server entries.
    /// Returns issues found; an empty array means all servers pass.
    func check(_ servers: [ResolvedMcpServerEntry]) -> [MCPHealthIssue] {
        servers.flatMap { checkSingle($0) }
    }

    /// Convert health issues into `SyntaxIssue` entries suitable for inclusion in parse results.
    static func asSyntaxIssues(_ healthIssues: [MCPHealthIssue], sourcePath: String) -> [SyntaxIssue] {
        healthIssues.map { issue in
            let code: SyntaxIssueCode
            switch issue.code {
            case .commandNotFound: code = .mcpCommandNotFound
            case .commandNotExecutable: code = .mcpCommandNotExecutable
            case .invalidUrl: code = .mcpInvalidUrl
            case .missingRequiredField: code = .mcpMissingRequiredField
            }

            return SyntaxIssue(
                code: code,
                severity: issue.severity,
                message: "[\(issue.serverId)] \(issue.message)",
                sourcePath: sourcePath,
                keyPath: "mcpServers.\(issue.serverId)"
            )
        }
    }

    // MARK: - Single-Server Checks

    private func checkSingle(_ entry: ResolvedMcpServerEntry) -> [MCPHealthIssue] {
        guard let config = entry.resolvedConfig.effectiveValue,
              case .object(let obj) = config else {
            return []
        }

        let transport = detectTransport(obj)

        switch transport {
        case .stdio:
            return checkStdio(serverId: entry.serverID, obj: obj)
        case .http:
            return checkHttp(serverId: entry.serverID, obj: obj)
        case .unknown:
            return []
        }
    }

    // MARK: - Transport Detection

    private enum Transport {
        case stdio, http, unknown
    }

    private func detectTransport(_ obj: [String: JSONValue]) -> Transport {
        if obj["command"] != nil { return .stdio }
        if obj["url"] != nil { return .http }
        if case .string(let t) = obj["type"] {
            if t == "stdio" { return .stdio }
            if t == "http" || t == "sse" || t == "streamable-http" { return .http }
        }
        return .unknown
    }

    // MARK: - stdio Checks

    private func checkStdio(serverId: String, obj: [String: JSONValue]) -> [MCPHealthIssue] {
        var issues: [MCPHealthIssue] = []

        guard case .string(let command) = obj["command"] else {
            issues.append(MCPHealthIssue(
                serverId: serverId,
                severity: .error,
                code: .missingRequiredField(field: "command"),
                message: "stdio server is missing required 'command' field"
            ))
            return issues
        }

        // Resolve the command path
        let resolvedPath: String?
        if command.hasPrefix("/") {
            // Absolute path — check directly
            resolvedPath = command
        } else {
            // Bare command name — attempt to resolve via known PATH directories
            resolvedPath = resolveCommandOnPath(command)
        }

        guard let path = resolvedPath else {
            issues.append(MCPHealthIssue(
                serverId: serverId,
                severity: .warning,
                code: .commandNotFound(path: command),
                message: "Command '\(command)' not found on disk or PATH"
            ))
            return issues
        }

        if !FileManager.default.fileExists(atPath: path) {
            issues.append(MCPHealthIssue(
                serverId: serverId,
                severity: .warning,
                code: .commandNotFound(path: path),
                message: "Command path '\(path)' does not exist"
            ))
        } else if !FileManager.default.isExecutableFile(atPath: path) {
            issues.append(MCPHealthIssue(
                serverId: serverId,
                severity: .warning,
                code: .commandNotExecutable(path: path),
                message: "Command '\(path)' exists but is not executable"
            ))
        }

        return issues
    }

    /// Resolve a bare command name by checking common PATH directories.
    /// Uses `which` via Process for accuracy.
    private func resolveCommandOnPath(_ command: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return output?.isEmpty == false ? output : nil
    }

    // MARK: - http Checks

    private func checkHttp(serverId: String, obj: [String: JSONValue]) -> [MCPHealthIssue] {
        var issues: [MCPHealthIssue] = []

        guard case .string(let urlString) = obj["url"] else {
            issues.append(MCPHealthIssue(
                serverId: serverId,
                severity: .error,
                code: .missingRequiredField(field: "url"),
                message: "HTTP server is missing required 'url' field"
            ))
            return issues
        }

        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              let host = url.host, !host.isEmpty else {
            issues.append(MCPHealthIssue(
                serverId: serverId,
                severity: .error,
                code: .invalidUrl(url: urlString),
                message: "URL '\(urlString)' is invalid — must be http(s) with a non-empty host"
            ))
            return issues
        }

        return issues
    }
}

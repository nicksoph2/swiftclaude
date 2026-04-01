import Foundation

struct StatusLinePayload: Codable, Equatable, Sendable {
    let cwd: String
    let sessionId: String
    let transcriptPath: String
    let version: String?
    let model: StatusLineModel
    let workspace: StatusLineWorkspace
    let outputStyle: StatusLineOutputStyle?
    let cost: StatusLineCost
    let contextWindow: StatusLineContextWindow
    let exceeds200kTokens: Bool?
    let rateLimits: StatusLineRateLimits?
    let vim: StatusLineVim?
    let agent: StatusLineAgent?
    let worktree: StatusLineWorktree?

    enum CodingKeys: String, CodingKey {
        case cwd
        case sessionId = "session_id"
        case transcriptPath = "transcript_path"
        case version
        case model
        case workspace
        case outputStyle = "output_style"
        case cost
        case contextWindow = "context_window"
        case exceeds200kTokens = "exceeds_200k_tokens"
        case rateLimits = "rate_limits"
        case vim
        case agent
        case worktree
    }
}

struct StatusLineModel: Codable, Equatable, Sendable {
    let id: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

struct StatusLineWorkspace: Codable, Equatable, Sendable {
    let currentDir: String
    let projectDir: String?

    enum CodingKeys: String, CodingKey {
        case currentDir = "current_dir"
        case projectDir = "project_dir"
    }
}

struct StatusLineOutputStyle: Codable, Equatable, Sendable {
    let name: String?
}

struct StatusLineCost: Codable, Equatable, Sendable {
    let totalCostUsd: Double?
    let totalDurationMs: Int?
    let totalApiDurationMs: Int?
    let totalLinesAdded: Int?
    let totalLinesRemoved: Int?

    enum CodingKeys: String, CodingKey {
        case totalCostUsd = "total_cost_usd"
        case totalDurationMs = "total_duration_ms"
        case totalApiDurationMs = "total_api_duration_ms"
        case totalLinesAdded = "total_lines_added"
        case totalLinesRemoved = "total_lines_removed"
    }
}

struct StatusLineContextWindow: Codable, Equatable, Sendable {
    let totalInputTokens: Int?
    let totalOutputTokens: Int?
    let contextWindowSize: Int?
    let usedPercentage: Double?
    let remainingPercentage: Double?
    let currentUsage: StatusLineCurrentUsage?

    enum CodingKeys: String, CodingKey {
        case totalInputTokens = "total_input_tokens"
        case totalOutputTokens = "total_output_tokens"
        case contextWindowSize = "context_window_size"
        case usedPercentage = "used_percentage"
        case remainingPercentage = "remaining_percentage"
        case currentUsage = "current_usage"
    }
}

struct StatusLineCurrentUsage: Codable, Equatable, Sendable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}

struct StatusLineRateLimits: Codable, Equatable, Sendable {
    let fiveHour: StatusLineRateWindow?
    let sevenDay: StatusLineRateWindow?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }
}

struct StatusLineRateWindow: Codable, Equatable, Sendable {
    let usedPercentage: Double?
    let resetsAt: Int?

    enum CodingKeys: String, CodingKey {
        case usedPercentage = "used_percentage"
        case resetsAt = "resets_at"
    }
}

struct StatusLineVim: Codable, Equatable, Sendable {
    let mode: String?
}

struct StatusLineAgent: Codable, Equatable, Sendable {
    let name: String?
}

struct StatusLineWorktree: Codable, Equatable, Sendable {
    let name: String?
    let path: String?
    let branch: String?
    let originalCwd: String?
    let originalBranch: String?

    enum CodingKeys: String, CodingKey {
        case name
        case path
        case branch
        case originalCwd = "original_cwd"
        case originalBranch = "original_branch"
    }
}

struct RuntimeSessionSnapshot: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let transcriptPath: String
    let modelId: String
    let modelDisplayName: String
    let cwd: String
    let projectDir: String?
    let version: String?
    let totalCostUsd: Double?
    let totalDurationMs: Int?
    let totalLinesAdded: Int?
    let totalLinesRemoved: Int?
    let totalInputTokens: Int?
    let totalOutputTokens: Int?
    let contextWindowSize: Int?
    let usedPercentage: Double?
    let fiveHourUsedPercentage: Double?
    let fiveHourResetsAt: Int?
    let sevenDayUsedPercentage: Double?
    let sevenDayResetsAt: Int?
    let capturedAt: Date

    init(
        id: String,
        transcriptPath: String,
        modelId: String,
        modelDisplayName: String,
        cwd: String,
        projectDir: String?,
        version: String?,
        totalCostUsd: Double?,
        totalDurationMs: Int?,
        totalLinesAdded: Int?,
        totalLinesRemoved: Int?,
        totalInputTokens: Int?,
        totalOutputTokens: Int?,
        contextWindowSize: Int?,
        usedPercentage: Double?,
        fiveHourUsedPercentage: Double?,
        fiveHourResetsAt: Int?,
        sevenDayUsedPercentage: Double?,
        sevenDayResetsAt: Int?,
        capturedAt: Date
    ) {
        self.id = id
        self.transcriptPath = transcriptPath
        self.modelId = modelId
        self.modelDisplayName = modelDisplayName
        self.cwd = cwd
        self.projectDir = projectDir
        self.version = version
        self.totalCostUsd = totalCostUsd
        self.totalDurationMs = totalDurationMs
        self.totalLinesAdded = totalLinesAdded
        self.totalLinesRemoved = totalLinesRemoved
        self.totalInputTokens = totalInputTokens
        self.totalOutputTokens = totalOutputTokens
        self.contextWindowSize = contextWindowSize
        self.usedPercentage = usedPercentage
        self.fiveHourUsedPercentage = fiveHourUsedPercentage
        self.fiveHourResetsAt = fiveHourResetsAt
        self.sevenDayUsedPercentage = sevenDayUsedPercentage
        self.sevenDayResetsAt = sevenDayResetsAt
        self.capturedAt = capturedAt
    }

    init(from payload: StatusLinePayload, capturedAt: Date = .now) {
        self.init(
            id: payload.sessionId,
            transcriptPath: payload.transcriptPath,
            modelId: payload.model.id,
            modelDisplayName: payload.model.displayName,
            cwd: payload.cwd,
            projectDir: payload.workspace.projectDir,
            version: payload.version,
            totalCostUsd: payload.cost.totalCostUsd,
            totalDurationMs: payload.cost.totalDurationMs,
            totalLinesAdded: payload.cost.totalLinesAdded,
            totalLinesRemoved: payload.cost.totalLinesRemoved,
            totalInputTokens: payload.contextWindow.totalInputTokens,
            totalOutputTokens: payload.contextWindow.totalOutputTokens,
            contextWindowSize: payload.contextWindow.contextWindowSize,
            usedPercentage: payload.contextWindow.usedPercentage,
            fiveHourUsedPercentage: payload.rateLimits?.fiveHour?.usedPercentage,
            fiveHourResetsAt: payload.rateLimits?.fiveHour?.resetsAt,
            sevenDayUsedPercentage: payload.rateLimits?.sevenDay?.usedPercentage,
            sevenDayResetsAt: payload.rateLimits?.sevenDay?.resetsAt,
            capturedAt: capturedAt
        )
    }

    var isStale: Bool {
        Date.now.timeIntervalSince(capturedAt) > 30 * 60
    }

    var totalTokens: Int {
        (totalInputTokens ?? 0) + (totalOutputTokens ?? 0)
    }
}

enum TranscriptKind: String, Codable, Equatable, Sendable {
    case primarySession
    case subagent
}

struct TranscriptUsage: Codable, Equatable, Sendable {
    let inputTokens: Int?
    let outputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

struct TranscriptEntry: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let lineNumber: Int
    let rawJson: [String: JSONValue]
    let rawLine: String
    let type: String?
    let role: String?
    let contentPreview: String?
    let model: String?
    let timestamp: Date?
    let usage: TranscriptUsage?

    init(
        id: UUID = UUID(),
        lineNumber: Int,
        rawJson: [String: JSONValue],
        rawLine: String,
        type: String?,
        role: String?,
        contentPreview: String?,
        model: String?,
        timestamp: Date?,
        usage: TranscriptUsage?
    ) {
        self.id = id
        self.lineNumber = lineNumber
        self.rawJson = rawJson
        self.rawLine = rawLine
        self.type = type
        self.role = role
        self.contentPreview = contentPreview
        self.model = model
        self.timestamp = timestamp
        self.usage = usage
    }

    var displayText: String {
        if let contentPreview, !contentPreview.isEmpty {
            return contentPreview
        }

        if let rawJSON = rawJson.prettyPrintedJSONString, !rawJSON.isEmpty {
            return TranscriptEntry.truncated(rawJSON)
        }

        let trimmedLine = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedLine.isEmpty {
            return TranscriptEntry.truncated(trimmedLine)
        }

        return "Empty line"
    }

    var prettyRawJSON: String {
        rawJson.prettyPrintedJSONString ?? rawLine
    }

    private static func truncated(_ value: String, limit: Int = 240) -> String {
        guard value.count > limit else {
            return value
        }

        return String(value.prefix(limit)) + "..."
    }
}

struct TranscriptMetadata: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let sessionId: String?
    let transcriptKind: TranscriptKind
    let agentId: String?
    let projectKey: String?
    let transcriptPath: String
    let fileSize: Int64
    let createdAt: Date?
    let modifiedAt: Date
    let lineCount: Int
    let model: String?
    let totalTokensIn: Int?
    let totalTokensOut: Int?

    var isRecent: Bool {
        Date.now.timeIntervalSince(modifiedAt) < 7 * 24 * 60 * 60
    }
}

enum TranscriptDiscoveryError: LocalizedError, Equatable, Sendable {
    case transcriptFileNotFound(path: String)
    case invalidJsonLine(path: String, lineNumber: Int, details: String)
    case fileAccessDenied(path: String)
    case unexpectedDirectoryStructure(path: String, details: String)

    var errorDescription: String? {
        switch self {
        case .transcriptFileNotFound(let path):
            return "Transcript file not found: \(path)"
        case .invalidJsonLine(let path, let lineNumber, let details):
            return "Invalid JSON on line \(lineNumber) of \(path): \(details)"
        case .fileAccessDenied(let path):
            return "Access denied reading transcript: \(path)"
        case .unexpectedDirectoryStructure(let path, let details):
            return "Unexpected transcript directory structure at \(path): \(details)"
        }
    }
}

enum RuntimeSessionSnapshotError: LocalizedError, Equatable, Sendable {
    case invalidJsonFormat(details: String)
    case missingRequiredField(fieldName: String)
    case transcriptNotFound(path: String)
    case fileAccessDenied(path: String)

    var errorDescription: String? {
        switch self {
        case .invalidJsonFormat(let details):
            return "Invalid status-line JSON: \(details)"
        case .missingRequiredField(let fieldName):
            return "Missing required field in status-line payload: \(fieldName)"
        case .transcriptNotFound(let path):
            return "Transcript file not found: \(path)"
        case .fileAccessDenied(let path):
            return "Access denied reading: \(path)"
        }
    }
}

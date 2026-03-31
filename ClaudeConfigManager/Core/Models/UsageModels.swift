import Foundation

// MARK: - Usage Aggregate

struct UsageAggregate: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let sessionId: String?
    let startTime: Date?
    let endTime: Date?
    let totalTokensIn: Int
    let totalTokensOut: Int
    let totalCostUsd: Double
    let modelUsage: [ModelUsageBreakdown]
    let messageCount: Int
    let toolUseCount: Int
    let duration: TimeInterval?

    var totalTokens: Int {
        totalTokensIn + totalTokensOut
    }

    var tokensPerMinute: Double? {
        guard let dur = duration, dur > 0 else { return nil }
        return Double(totalTokens) / (dur / 60)
    }

    var costPerKTokens: Double {
        guard totalTokens > 0 else { return 0 }
        return (totalCostUsd * 1000) / Double(totalTokens)
    }
}

// MARK: - Model Usage Breakdown

struct ModelUsageBreakdown: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let model: String
    let tokensIn: Int
    let tokensOut: Int
    let costUsd: Double
    let messageCount: Int?

    var totalTokens: Int {
        tokensIn + tokensOut
    }
}

// MARK: - Prompt History Entry

struct PromptHistoryEntry: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let sessionId: String
    let timestamp: Date
    let role: String
    let contentPreview: String
    let contentFull: String
    let tokensUsed: Int?

    var isUserPrompt: Bool {
        role == "user"
    }

    var isAssistantResponse: Bool {
        role == "assistant"
    }

    static func from(
        entry: TranscriptEntry,
        sessionId: String
    ) -> PromptHistoryEntry? {
        guard let role = entry.role ?? entry.type else { return nil }
        let knownRoles: Set<String> = ["user", "assistant", "human"]
        let effectiveRole: String
        if role == "human" {
            effectiveRole = "user"
        } else if knownRoles.contains(role) {
            effectiveRole = role
        } else {
            return nil
        }

        let fullContent = entry.contentPreview ?? entry.displayText
        let preview: String
        if fullContent.count > 200 {
            preview = String(fullContent.prefix(200))
        } else {
            preview = fullContent
        }

        let tokensUsed: Int?
        if let usage = entry.usage {
            let total = (usage.inputTokens ?? 0) + (usage.outputTokens ?? 0)
            tokensUsed = total > 0 ? total : nil
        } else {
            tokensUsed = nil
        }

        return PromptHistoryEntry(
            id: UUID(),
            sessionId: sessionId,
            timestamp: entry.timestamp ?? .distantPast,
            role: effectiveRole,
            contentPreview: preview,
            contentFull: fullContent,
            tokensUsed: tokensUsed
        )
    }
}

// MARK: - Usage Computation Error

enum UsageComputationError: LocalizedError, Equatable, Sendable {
    case noSessionsFound
    case invalidTokenCounts(sessionId: String, details: String)
    case failedToLoadTranscript(path: String)
    case internalError(details: String)

    var errorDescription: String? {
        switch self {
        case .noSessionsFound:
            return "No sessions or transcripts found to aggregate"
        case .invalidTokenCounts(let sessionId, let details):
            return "Invalid token counts for session \(sessionId): \(details)"
        case .failedToLoadTranscript(let path):
            return "Failed to load transcript for usage computation: \(path)"
        case .internalError(let details):
            return "Internal error computing usage: \(details)"
        }
    }
}

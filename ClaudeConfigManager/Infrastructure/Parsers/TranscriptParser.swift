import Foundation

// MARK: - Transcript Summary

/// Aggregated summary of a transcript file without loading all content into memory.
struct TranscriptSummary: Equatable, Sendable {
    let sessionId: String
    let projectId: String
    let turnCount: Int
    let inputTokens: Int
    let outputTokens: Int
    let estimatedCostUSD: Double
    let startedAt: Date?
    let lastActivityAt: Date?
    let modelsUsed: [String: Int]
    let toolInvocations: [String: Int]

    var totalTokens: Int {
        inputTokens + outputTokens
    }
}

// MARK: - Cost Estimation

/// Hardcoded API pricing constants.
/// These rates reflect published Anthropic API pricing as of April 2025.
/// Update these when Anthropic changes pricing.
enum TranscriptCostEstimation {
    // Claude Opus 4: $15 / 1M input, $75 / 1M output
    // Claude Sonnet 4: $3 / 1M input, $15 / 1M output
    // Claude Haiku 3.5: $0.80 / 1M input, $4 / 1M output
    // Default fallback uses Sonnet pricing as most common

    struct ModelRate: Sendable {
        let inputPerMillionTokens: Double
        let outputPerMillionTokens: Double
    }

    static let rates: [String: ModelRate] = [
        "claude-opus-4-6": ModelRate(inputPerMillionTokens: 15.0, outputPerMillionTokens: 75.0),
        "claude-opus-4-5-20250620": ModelRate(inputPerMillionTokens: 15.0, outputPerMillionTokens: 75.0),
        "claude-sonnet-4-6": ModelRate(inputPerMillionTokens: 3.0, outputPerMillionTokens: 15.0),
        "claude-sonnet-4-5-20250514": ModelRate(inputPerMillionTokens: 3.0, outputPerMillionTokens: 15.0),
        "claude-haiku-4-5-20251001": ModelRate(inputPerMillionTokens: 0.80, outputPerMillionTokens: 4.0),
    ]

    static let defaultRate = ModelRate(inputPerMillionTokens: 3.0, outputPerMillionTokens: 15.0)

    static func estimateCost(inputTokens: Int, outputTokens: Int, model: String?) -> Double {
        let rate = rateForModel(model)
        let inputCost = Double(inputTokens) * rate.inputPerMillionTokens / 1_000_000
        let outputCost = Double(outputTokens) * rate.outputPerMillionTokens / 1_000_000
        return inputCost + outputCost
    }

    static func rateForModel(_ model: String?) -> ModelRate {
        guard let model else { return defaultRate }

        // Try exact match first
        if let rate = rates[model] { return rate }

        // Try prefix matching for model families
        if model.contains("opus") {
            return rates["claude-opus-4-6"] ?? defaultRate
        }
        if model.contains("haiku") {
            return rates["claude-haiku-4-5-20251001"] ?? defaultRate
        }
        if model.contains("sonnet") {
            return rates["claude-sonnet-4-6"] ?? defaultRate
        }

        return defaultRate
    }
}

// MARK: - Transcript Parser

/// Parses `.jsonl` transcript files using streaming line-by-line reading.
///
/// This parser works directly with `FileHandle` to avoid loading entire files into memory.
/// It reuses the same JSON decoding approach as the internal `TranscriptRecordParser`.
struct TranscriptParser {

    // MARK: - Streaming Parse

    /// Parse a `.jsonl` file, streaming entries one at a time.
    func parse(fileURL: URL) -> AsyncThrowingStream<TranscriptEntry, Error> {
        AsyncThrowingStream { continuation in
            do {
                let handle = try FileHandle(forReadingFrom: fileURL)
                defer {
                    try? handle.close()
                }

                var buffer = Data()
                var lineNumber = 0

                while let chunk = try handle.read(upToCount: 4096), !chunk.isEmpty {
                    buffer.append(chunk)

                    while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                        let lineData = Data(buffer[..<newlineIndex])
                        buffer.removeSubrange(...newlineIndex)
                        lineNumber += 1

                        let trimmed = TranscriptParser.trimCarriageReturn(in: lineData)
                        let rawLine = String(decoding: trimmed, as: UTF8.self)

                        guard !rawLine.trimmingCharacters(in: .whitespaces).isEmpty else {
                            continue
                        }

                        let entry = TranscriptParser.parseEntry(
                            lineNumber: lineNumber,
                            rawLine: rawLine,
                            lineData: trimmed,
                            path: fileURL.path
                        )
                        continuation.yield(entry)
                    }
                }

                // Handle remaining buffer without trailing newline
                if !buffer.isEmpty {
                    lineNumber += 1
                    let trimmed = TranscriptParser.trimCarriageReturn(in: buffer)
                    let rawLine = String(decoding: trimmed, as: UTF8.self)
                    if !rawLine.trimmingCharacters(in: .whitespaces).isEmpty {
                        let entry = TranscriptParser.parseEntry(
                            lineNumber: lineNumber,
                            rawLine: rawLine,
                            lineData: trimmed,
                            path: fileURL.path
                        )
                        continuation.yield(entry)
                    }
                }

                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    // MARK: - Summary Parse

    /// Parse a summary without loading all content. Streams through the file once,
    /// collecting only aggregate statistics.
    func parseSummary(fileURL: URL) -> TranscriptSummary {
        let pathComponents = fileURL.deletingPathExtension().pathComponents
        let sessionId = fileURL.deletingPathExtension().lastPathComponent

        // Derive project ID from path: .../projects/<projectKey>/<sessionId>.jsonl
        let projectId: String
        if let projectsIndex = pathComponents.lastIndex(of: "projects"),
           projectsIndex + 1 < pathComponents.count {
            projectId = pathComponents[projectsIndex + 1]
        } else {
            projectId = "unknown"
        }

        var turnCount = 0
        var totalInputTokens = 0
        var totalOutputTokens = 0
        var modelsUsed: [String: Int] = [:]
        var toolInvocations: [String: Int] = [:]
        var startedAt: Date?
        var lastActivityAt: Date?
        var dominantModel: String?

        guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
            return TranscriptSummary(
                sessionId: sessionId,
                projectId: projectId,
                turnCount: 0,
                inputTokens: 0,
                outputTokens: 0,
                estimatedCostUSD: 0,
                startedAt: nil,
                lastActivityAt: nil,
                modelsUsed: [:],
                toolInvocations: [:]
            )
        }
        defer { try? handle.close() }

        var buffer = Data()
        var lineNumber = 0

        func processLine(_ lineData: Data) {
            let trimmed = TranscriptParser.trimCarriageReturn(in: lineData)
            let rawLine = String(decoding: trimmed, as: UTF8.self)
            guard !rawLine.trimmingCharacters(in: .whitespaces).isEmpty else { return }

            lineNumber += 1
            turnCount += 1

            guard let jsonObject = try? JSONSerialization.jsonObject(with: trimmed) as? [String: Any] else {
                return
            }

            // Extract type
            let entryType = jsonObject["type"] as? String

            // Extract usage from message.usage or top-level usage
            if let message = jsonObject["message"] as? [String: Any],
               let usage = message["usage"] as? [String: Any] {
                if let input = usage["input_tokens"] as? Int {
                    totalInputTokens += input
                }
                if let output = usage["output_tokens"] as? Int {
                    totalOutputTokens += output
                }
            }

            // Extract model
            if let message = jsonObject["message"] as? [String: Any],
               let model = message["model"] as? String {
                modelsUsed[model, default: 0] += 1
                if dominantModel == nil { dominantModel = model }
            }

            // Extract tool name for tool_use entries
            if entryType == "tool_use", let name = jsonObject["name"] as? String {
                toolInvocations[name, default: 0] += 1
            }

            // Also check for tool_use blocks inside assistant message content
            if entryType == "assistant",
               let message = jsonObject["message"] as? [String: Any],
               let content = message["content"] as? [[String: Any]] {
                for block in content {
                    if block["type"] as? String == "tool_use",
                       let name = block["name"] as? String {
                        toolInvocations[name, default: 0] += 1
                    }
                }
            }

            // Extract timestamp
            if let timestampStr = jsonObject["timestamp"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let date = formatter.date(from: timestampStr)
                    ?? { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f.date(from: timestampStr) }()

                if let date {
                    if startedAt == nil || date < startedAt! { startedAt = date }
                    if lastActivityAt == nil || date > lastActivityAt! { lastActivityAt = date }
                }
            }
        }

        // Stream through file in chunks
        while let chunk = try? handle.read(upToCount: 8192), !chunk.isEmpty {
            buffer.append(chunk)
            while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                let lineData = Data(buffer[..<newlineIndex])
                buffer.removeSubrange(...newlineIndex)
                processLine(lineData)
            }
        }
        if !buffer.isEmpty {
            processLine(buffer)
        }

        let estimatedCost = TranscriptCostEstimation.estimateCost(
            inputTokens: totalInputTokens,
            outputTokens: totalOutputTokens,
            model: dominantModel
        )

        return TranscriptSummary(
            sessionId: sessionId,
            projectId: projectId,
            turnCount: turnCount,
            inputTokens: totalInputTokens,
            outputTokens: totalOutputTokens,
            estimatedCostUSD: estimatedCost,
            startedAt: startedAt,
            lastActivityAt: lastActivityAt,
            modelsUsed: modelsUsed,
            toolInvocations: toolInvocations
        )
    }

    // MARK: - Export

    /// Generate a human-readable Markdown summary for a transcript.
    static func markdownSummary(
        metadata: TranscriptMetadata,
        entries: [TranscriptEntry],
        summary: TranscriptSummary
    ) -> String {
        var lines: [String] = []
        lines.append("# Transcript Summary")
        lines.append("")
        lines.append("- **Session ID:** \(summary.sessionId)")
        lines.append("- **Project:** \(summary.projectId)")
        lines.append("- **Turns:** \(summary.turnCount)")
        lines.append("- **Input tokens:** \(summary.inputTokens)")
        lines.append("- **Output tokens:** \(summary.outputTokens)")
        lines.append("- **Estimated cost:** $\(String(format: "%.4f", summary.estimatedCostUSD))")

        if let started = summary.startedAt {
            lines.append("- **Started:** \(started.formatted(date: .abbreviated, time: .standard))")
        }
        if let last = summary.lastActivityAt {
            lines.append("- **Last activity:** \(last.formatted(date: .abbreviated, time: .standard))")
        }

        if !summary.modelsUsed.isEmpty {
            lines.append("")
            lines.append("## Models Used")
            lines.append("")
            for (model, count) in summary.modelsUsed.sorted(by: { $0.value > $1.value }) {
                lines.append("- \(model): \(count) turns")
            }
        }

        if !summary.toolInvocations.isEmpty {
            lines.append("")
            lines.append("## Top Tools")
            lines.append("")
            for (tool, count) in summary.toolInvocations.sorted(by: { $0.value > $1.value }).prefix(10) {
                lines.append("- `\(tool)`: \(count) invocations")
            }
        }

        lines.append("")
        lines.append("## Conversation")
        lines.append("")

        for entry in entries {
            let role: String
            switch entry.type {
            case "human", "user":
                role = "**You**"
            case "assistant":
                role = "**Claude**"
            case "tool_use":
                role = "**Tool Use**"
            case "tool_result":
                role = "**Tool Result**"
            default:
                role = "**\(entry.type ?? "Unknown")**"
            }

            let timestamp = entry.timestamp.map { " (\($0.formatted(date: .omitted, time: .standard)))" } ?? ""
            lines.append("\(role)\(timestamp)")
            lines.append("")

            let content = entry.contentPreview ?? entry.displayText
            if content.count > 500 {
                lines.append(String(content.prefix(500)) + "...")
            } else {
                lines.append(content)
            }
            lines.append("")

            if let usage = entry.usage {
                let input = usage.inputTokens ?? 0
                let output = usage.outputTokens ?? 0
                if input > 0 || output > 0 {
                    lines.append("_Tokens: \(input) in / \(output) out_")
                    lines.append("")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Private Helpers

    private static func trimCarriageReturn(in data: Data) -> Data {
        guard data.last == 0x0D else { return data }
        return Data(data.dropLast())
    }

    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601WithoutFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func parseEntry(
        lineNumber: Int,
        rawLine: String,
        lineData: Data,
        path: String
    ) -> TranscriptEntry {
        do {
            let object = try JSONSerialization.jsonObject(with: lineData) as? [String: Any] ?? [:]
            let jsonValueObject = object.mapValues(JSONValue.from(any:))

            return TranscriptEntry(
                lineNumber: lineNumber,
                rawJson: jsonValueObject,
                rawLine: rawLine,
                type: extractString(from: object, key: "type"),
                role: extractRole(from: object),
                contentPreview: extractContentPreview(from: object),
                model: extractModel(from: object),
                timestamp: extractTimestamp(from: object),
                usage: extractUsage(from: object)
            )
        } catch {
            return TranscriptEntry(
                lineNumber: lineNumber,
                rawJson: [:],
                rawLine: rawLine,
                type: nil,
                role: nil,
                contentPreview: nil,
                model: nil,
                timestamp: nil,
                usage: nil
            )
        }
    }

    private static func extractString(from object: [String: Any], key: String) -> String? {
        object[key] as? String
    }

    private static func extractRole(from object: [String: Any]) -> String? {
        if let message = object["message"] as? [String: Any],
           let role = message["role"] as? String {
            return role
        }
        return object["role"] as? String
    }

    private static func extractContentPreview(from object: [String: Any]) -> String? {
        let messageObject = object["message"] as? [String: Any]
        let contentSource = messageObject ?? object

        if let content = contentSource["content"] {
            if let text = content as? String { return text }
            if let blocks = content as? [[String: Any]] {
                let texts = blocks.compactMap { block -> String? in
                    if block["type"] as? String == "text" {
                        return block["text"] as? String
                    }
                    if let name = block["name"] as? String {
                        return "[Tool: \(name)]"
                    }
                    return block["text"] as? String
                }
                return texts.isEmpty ? nil : texts.joined(separator: "\n")
            }
        }

        return messageObject.flatMap { $0["message"] as? String }
    }

    private static func extractModel(from object: [String: Any]) -> String? {
        if let message = object["message"] as? [String: Any],
           let model = message["model"] as? String {
            return model
        }
        return object["model"] as? String
    }

    private static func extractTimestamp(from object: [String: Any]) -> Date? {
        if let str = object["timestamp"] as? String {
            return iso8601WithFractional.date(from: str) ?? iso8601WithoutFractional.date(from: str)
        }
        if let num = object["timestamp"] as? Double {
            return num > 9_999_999_999 ? Date(timeIntervalSince1970: num / 1000) : Date(timeIntervalSince1970: num)
        }
        return nil
    }

    private static func extractUsage(from object: [String: Any]) -> TranscriptUsage? {
        let usage: [String: Any]?
        if let message = object["message"] as? [String: Any] {
            usage = message["usage"] as? [String: Any]
        } else {
            usage = object["usage"] as? [String: Any]
        }

        guard let usage else { return nil }

        let input = (usage["input_tokens"] as? Int) ?? (usage["inputTokens"] as? Int)
        let output = (usage["output_tokens"] as? Int) ?? (usage["outputTokens"] as? Int)

        guard input != nil || output != nil else { return nil }

        return TranscriptUsage(inputTokens: input, outputTokens: output)
    }
}

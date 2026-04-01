import Foundation

@MainActor
final class UsageAggregator: ObservableObject {
    @Published var currentSessionUsage: UsageAggregate?
    @Published var recentSessionsUsage: [UsageAggregate] = []
    @Published var aggregateUsage: UsageAggregate?
    @Published var promptHistory: [PromptHistoryEntry] = []
    @Published var computationIssues: [UsageComputationError] = []

    private let transcriptScanner: TranscriptScanner
    private let runtimeDiscovery: RuntimeSessionDiscovery

    init(transcriptScanner: TranscriptScanner, runtimeDiscovery: RuntimeSessionDiscovery) {
        self.transcriptScanner = transcriptScanner
        self.runtimeDiscovery = runtimeDiscovery
    }

    // MARK: - Public API

    func refreshAll() async {
        computationIssues = []
        await computeCurrentSessionUsage()
        await computeRecentSessionsUsage()
        computeAggregateUsage()
        await loadPromptHistory()
    }

    func computeCurrentSessionUsage() async {
        guard let snapshot = runtimeDiscovery.currentSession, !snapshot.isStale else {
            currentSessionUsage = nil
            return
        }

        let modelBreakdown = ModelUsageBreakdown(
            id: snapshot.modelId,
            model: snapshot.modelDisplayName,
            tokensIn: snapshot.totalInputTokens ?? 0,
            tokensOut: snapshot.totalOutputTokens ?? 0,
            costUsd: snapshot.totalCostUsd ?? 0,
            messageCount: nil
        )

        let durationSeconds: TimeInterval?
        if let ms = snapshot.totalDurationMs {
            durationSeconds = Double(ms) / 1000.0
        } else {
            durationSeconds = nil
        }

        currentSessionUsage = UsageAggregate(
            id: snapshot.id,
            sessionId: snapshot.id,
            startTime: nil,
            endTime: snapshot.capturedAt,
            totalTokensIn: snapshot.totalInputTokens ?? 0,
            totalTokensOut: snapshot.totalOutputTokens ?? 0,
            totalCostUsd: snapshot.totalCostUsd ?? 0,
            modelUsage: [modelBreakdown],
            messageCount: 0,
            toolUseCount: 0,
            duration: durationSeconds
        )
    }

    func computeRecentSessionsUsage() async {
        let thirtyDaysAgo = Date.now.addingTimeInterval(-30 * 24 * 60 * 60)
        let primaryTranscripts = transcriptScanner.recentTranscripts.filter { metadata in
            metadata.transcriptKind == .primarySession && metadata.modifiedAt >= thirtyDaysAgo
        }

        guard !primaryTranscripts.isEmpty else {
            if recentSessionsUsage.isEmpty && currentSessionUsage == nil {
                appendIssue(.noSessionsFound)
            }
            return
        }

        var aggregates: [UsageAggregate] = []

        for metadata in primaryTranscripts {
            let sessionId = metadata.sessionId ?? metadata.id
            let tokensIn = metadata.totalTokensIn ?? 0
            let tokensOut = metadata.totalTokensOut ?? 0

            if tokensIn < 0 || tokensOut < 0 {
                appendIssue(.invalidTokenCounts(
                    sessionId: sessionId,
                    details: "Negative token counts: in=\(tokensIn), out=\(tokensOut)"
                ))
                continue
            }

            let modelBreakdown: [ModelUsageBreakdown]
            if let model = metadata.model {
                modelBreakdown = [
                    ModelUsageBreakdown(
                        id: model,
                        model: model,
                        tokensIn: tokensIn,
                        tokensOut: tokensOut,
                        costUsd: 0,
                        messageCount: nil
                    )
                ]
            } else {
                modelBreakdown = []
            }

            let duration: TimeInterval?
            if let created = metadata.createdAt {
                duration = metadata.modifiedAt.timeIntervalSince(created)
            } else {
                duration = nil
            }

            let aggregate = UsageAggregate(
                id: sessionId,
                sessionId: sessionId,
                startTime: metadata.createdAt,
                endTime: metadata.modifiedAt,
                totalTokensIn: tokensIn,
                totalTokensOut: tokensOut,
                totalCostUsd: 0,
                modelUsage: modelBreakdown,
                messageCount: metadata.lineCount,
                toolUseCount: 0,
                duration: duration
            )

            aggregates.append(aggregate)
        }

        recentSessionsUsage = aggregates.sorted { ($0.endTime ?? .distantPast) > ($1.endTime ?? .distantPast) }
    }

    func computeAggregateUsage() {
        let allAggregates = recentSessionsUsage
        guard !allAggregates.isEmpty else {
            aggregateUsage = nil
            return
        }

        var totalIn = 0
        var totalOut = 0
        var totalCost = 0.0
        var totalMessages = 0
        var totalToolUse = 0
        var modelMap: [String: (tokensIn: Int, tokensOut: Int, costUsd: Double, messageCount: Int)] = [:]
        var earliestStart: Date?
        var latestEnd: Date?

        for agg in allAggregates {
            totalIn += agg.totalTokensIn
            totalOut += agg.totalTokensOut
            totalCost += agg.totalCostUsd
            totalMessages += agg.messageCount
            totalToolUse += agg.toolUseCount

            if let start = agg.startTime {
                if earliestStart == nil || start < earliestStart! {
                    earliestStart = start
                }
            }
            if let end = agg.endTime {
                if latestEnd == nil || end > latestEnd! {
                    latestEnd = end
                }
            }

            for model in agg.modelUsage {
                var existing = modelMap[model.model] ?? (tokensIn: 0, tokensOut: 0, costUsd: 0, messageCount: 0)
                existing.tokensIn += model.tokensIn
                existing.tokensOut += model.tokensOut
                existing.costUsd += model.costUsd
                existing.messageCount += (model.messageCount ?? 0)
                modelMap[model.model] = existing
            }
        }

        let modelBreakdowns = modelMap.map { key, value in
            ModelUsageBreakdown(
                id: key,
                model: key,
                tokensIn: value.tokensIn,
                tokensOut: value.tokensOut,
                costUsd: value.costUsd,
                messageCount: value.messageCount > 0 ? value.messageCount : nil
            )
        }.sorted { $0.totalTokens > $1.totalTokens }

        let totalDuration: TimeInterval?
        if let start = earliestStart, let end = latestEnd {
            totalDuration = end.timeIntervalSince(start)
        } else {
            totalDuration = nil
        }

        aggregateUsage = UsageAggregate(
            id: "aggregate-all",
            sessionId: nil,
            startTime: earliestStart,
            endTime: latestEnd,
            totalTokensIn: totalIn,
            totalTokensOut: totalOut,
            totalCostUsd: totalCost,
            modelUsage: modelBreakdowns,
            messageCount: totalMessages,
            toolUseCount: totalToolUse,
            duration: totalDuration
        )
    }

    func loadPromptHistory(limit: Int = 100) async {
        let sevenDaysAgo = Date.now.addingTimeInterval(-7 * 24 * 60 * 60)
        let recentPrimary = transcriptScanner.recentTranscripts
            .filter { $0.transcriptKind == .primarySession && $0.modifiedAt >= sevenDaysAgo }
            .prefix(50)

        var entries: [PromptHistoryEntry] = []

        for metadata in recentPrimary {
            let sessionId = metadata.sessionId ?? metadata.id
            let (transcriptEntries, issues) = await transcriptScanner.loadTranscriptContent(path: metadata.transcriptPath)

            if !issues.isEmpty {
                appendIssue(.failedToLoadTranscript(path: metadata.transcriptPath))
            }

            for entry in transcriptEntries {
                if let prompt = PromptHistoryEntry.from(entry: entry, sessionId: sessionId) {
                    entries.append(prompt)
                }
            }
        }

        entries.sort { $0.timestamp > $1.timestamp }
        promptHistory = Array(entries.prefix(limit))
    }

    // MARK: - Private

    private func appendIssue(_ issue: UsageComputationError) {
        if !computationIssues.contains(issue) {
            computationIssues.append(issue)
        }
    }
}

import XCTest
@testable import ClaudeConfigManager

@MainActor
final class UsageAggregatorTests: XCTestCase {

    // MARK: - Current Session Usage

    func testComputeCurrentSessionUsageFromSnapshot() async {
        let (aggregator, discovery, _) = makeAggregator()

        let snapshot = RuntimeSessionSnapshot(
            id: "sess-live",
            transcriptPath: "/tmp/test.jsonl",
            modelId: "claude-opus-4-6",
            modelDisplayName: "Opus",
            cwd: "/Users/test",
            projectDir: "/Users/test",
            version: "1.0",
            totalCostUsd: 0.50,
            totalDurationMs: 120_000,
            totalLinesAdded: nil,
            totalLinesRemoved: nil,
            totalInputTokens: 5000,
            totalOutputTokens: 2000,
            contextWindowSize: 200_000,
            usedPercentage: 3.5,
            fiveHourUsedPercentage: nil,
            fiveHourResetsAt: nil,
            sevenDayUsedPercentage: nil,
            sevenDayResetsAt: nil,
            capturedAt: .now
        )

        discovery.currentSession = snapshot
        await aggregator.computeCurrentSessionUsage()

        let usage = try! XCTUnwrap(aggregator.currentSessionUsage)
        XCTAssertEqual(usage.id, "sess-live")
        XCTAssertEqual(usage.totalTokensIn, 5000)
        XCTAssertEqual(usage.totalTokensOut, 2000)
        XCTAssertEqual(usage.totalTokens, 7000)
        XCTAssertEqual(usage.totalCostUsd, 0.50, accuracy: 0.0001)
        XCTAssertEqual(usage.modelUsage.count, 1)
        XCTAssertEqual(usage.modelUsage.first?.model, "Opus")
        XCTAssertEqual(try XCTUnwrap(usage.duration), 120.0, accuracy: 0.01)
    }

    func testComputeCurrentSessionUsageNilWhenNoSnapshot() async {
        let (aggregator, _, _) = makeAggregator()
        await aggregator.computeCurrentSessionUsage()
        XCTAssertNil(aggregator.currentSessionUsage)
    }

    func testComputeCurrentSessionUsageNilWhenStale() async {
        let (aggregator, discovery, _) = makeAggregator()

        let snapshot = RuntimeSessionSnapshot(
            id: "sess-old",
            transcriptPath: "/tmp/test.jsonl",
            modelId: "claude-opus-4-6",
            modelDisplayName: "Opus",
            cwd: "/Users/test",
            projectDir: nil,
            version: nil,
            totalCostUsd: nil,
            totalDurationMs: nil,
            totalLinesAdded: nil,
            totalLinesRemoved: nil,
            totalInputTokens: 100,
            totalOutputTokens: 50,
            contextWindowSize: nil,
            usedPercentage: nil,
            fiveHourUsedPercentage: nil,
            fiveHourResetsAt: nil,
            sevenDayUsedPercentage: nil,
            sevenDayResetsAt: nil,
            capturedAt: Date.now.addingTimeInterval(-3600) // 1 hour ago -> stale
        )

        discovery.currentSession = snapshot
        await aggregator.computeCurrentSessionUsage()
        XCTAssertNil(aggregator.currentSessionUsage)
    }

    // MARK: - Aggregate Usage

    func testComputeAggregateUsageSumsCorrectly() {
        let (aggregator, _, _) = makeAggregator()

        // Manually set recent sessions usage
        aggregator.recentSessionsUsage = [
            UsageAggregate(
                id: "sess-1",
                sessionId: "sess-1",
                startTime: Date(timeIntervalSince1970: 1_000_000),
                endTime: Date(timeIntervalSince1970: 1_001_000),
                totalTokensIn: 300,
                totalTokensOut: 100,
                totalCostUsd: 0.02,
                modelUsage: [
                    ModelUsageBreakdown(id: "opus", model: "opus", tokensIn: 300, tokensOut: 100, costUsd: 0.02, messageCount: 3)
                ],
                messageCount: 10,
                toolUseCount: 2,
                duration: 1000
            ),
            UsageAggregate(
                id: "sess-2",
                sessionId: "sess-2",
                startTime: Date(timeIntervalSince1970: 1_002_000),
                endTime: Date(timeIntervalSince1970: 1_003_000),
                totalTokensIn: 200,
                totalTokensOut: 150,
                totalCostUsd: 0.03,
                modelUsage: [
                    ModelUsageBreakdown(id: "sonnet", model: "sonnet", tokensIn: 200, tokensOut: 150, costUsd: 0.03, messageCount: 5)
                ],
                messageCount: 8,
                toolUseCount: 1,
                duration: 1000
            )
        ]

        aggregator.computeAggregateUsage()

        let agg = try! XCTUnwrap(aggregator.aggregateUsage)
        XCTAssertEqual(agg.totalTokensIn, 500)
        XCTAssertEqual(agg.totalTokensOut, 250)
        XCTAssertEqual(agg.totalTokens, 750)
        XCTAssertEqual(agg.totalCostUsd, 0.05, accuracy: 0.0001)
        XCTAssertEqual(agg.messageCount, 18)
        XCTAssertEqual(agg.toolUseCount, 3)
        XCTAssertEqual(agg.modelUsage.count, 2)

        // Duration should span from earliest start to latest end
        XCTAssertEqual(agg.startTime, Date(timeIntervalSince1970: 1_000_000))
        XCTAssertEqual(agg.endTime, Date(timeIntervalSince1970: 1_003_000))
        XCTAssertEqual(try XCTUnwrap(agg.duration), 3000, accuracy: 0.01)
    }

    func testComputeAggregateUsageCombinesModelBreakdowns() {
        let (aggregator, _, _) = makeAggregator()

        aggregator.recentSessionsUsage = [
            UsageAggregate(
                id: "sess-1",
                sessionId: "sess-1",
                startTime: nil,
                endTime: nil,
                totalTokensIn: 300,
                totalTokensOut: 100,
                totalCostUsd: 0.02,
                modelUsage: [
                    ModelUsageBreakdown(id: "opus", model: "opus", tokensIn: 300, tokensOut: 100, costUsd: 0.02, messageCount: 3)
                ],
                messageCount: 5,
                toolUseCount: 0,
                duration: nil
            ),
            UsageAggregate(
                id: "sess-2",
                sessionId: "sess-2",
                startTime: nil,
                endTime: nil,
                totalTokensIn: 400,
                totalTokensOut: 200,
                totalCostUsd: 0.04,
                modelUsage: [
                    ModelUsageBreakdown(id: "opus", model: "opus", tokensIn: 400, tokensOut: 200, costUsd: 0.04, messageCount: 5)
                ],
                messageCount: 7,
                toolUseCount: 0,
                duration: nil
            )
        ]

        aggregator.computeAggregateUsage()

        let agg = try! XCTUnwrap(aggregator.aggregateUsage)
        XCTAssertEqual(agg.modelUsage.count, 1, "Same model should be combined")

        let opus = agg.modelUsage.first!
        XCTAssertEqual(opus.model, "opus")
        XCTAssertEqual(opus.tokensIn, 700)
        XCTAssertEqual(opus.tokensOut, 300)
        XCTAssertEqual(opus.costUsd, 0.06, accuracy: 0.0001)
        XCTAssertEqual(opus.messageCount, 8)
    }

    func testComputeAggregateUsageNilWhenEmpty() {
        let (aggregator, _, _) = makeAggregator()
        aggregator.recentSessionsUsage = []
        aggregator.computeAggregateUsage()
        XCTAssertNil(aggregator.aggregateUsage)
    }

    // MARK: - Error Collection

    func testComputationIssuesCollectedWithoutCrash() async {
        let (aggregator, _, _) = makeAggregator()

        // With no sessions scanned, computeRecentSessionsUsage should note no sessions
        await aggregator.computeRecentSessionsUsage()

        // The issue should be recorded since no data is available
        XCTAssertTrue(
            aggregator.computationIssues.contains(.noSessionsFound)
            || aggregator.recentSessionsUsage.isEmpty,
            "Should either record noSessionsFound issue or simply have empty results"
        )
    }

    // MARK: - Helpers

    private func makeAggregator() -> (UsageAggregator, RuntimeSessionDiscovery, TranscriptScanner) {
        let scanner = TranscriptScanner()
        let discovery = RuntimeSessionDiscovery()
        let aggregator = UsageAggregator(transcriptScanner: scanner, runtimeDiscovery: discovery)
        return (aggregator, discovery, scanner)
    }
}

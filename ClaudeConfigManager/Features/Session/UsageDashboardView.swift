import SwiftUI

struct UsageDashboardView: View {
    @ObservedObject var aggregator: UsageAggregator

    @State private var selectedSession: UsageAggregate?
    @State private var showingPromptHistory = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                currentSessionSection

                aggregateSummarySection

                recentSessionsSection

                promptHistoryLink

                issuesSection
            }
            .padding(24)
        }
        .sheet(item: $selectedSession) { session in
            UsageDetailView(aggregate: session)
        }
        .sheet(isPresented: $showingPromptHistory) {
            PromptHistoryView(entries: aggregator.promptHistory)
        }
    }

    // MARK: - Current Session

    @ViewBuilder
    private var currentSessionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Current Session", systemImage: "bolt.circle")
                .font(.headline)

            if let usage = aggregator.currentSessionUsage {
                usageCard(usage, showSessionId: true)
            } else {
                Text("No active session usage available.")
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    // MARK: - Aggregate Summary

    @ViewBuilder
    private var aggregateSummarySection: some View {
        if let agg = aggregator.aggregateUsage {
            VStack(alignment: .leading, spacing: 10) {
                Label("Aggregate Usage (Last 30 Days)", systemImage: "chart.bar")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    metricsRow("Total Tokens", value: formatTokenCount(agg.totalTokens))
                    metricsRow("Input Tokens", value: formatTokenCount(agg.totalTokensIn))
                    metricsRow("Output Tokens", value: formatTokenCount(agg.totalTokensOut))

                    if agg.totalCostUsd > 0 {
                        metricsRow("Total Cost", value: formatCost(agg.totalCostUsd))
                    }

                    if let tpm = agg.tokensPerMinute {
                        metricsRow("Tokens/min", value: String(format: "%.0f", tpm))
                    }

                    if agg.costPerKTokens > 0 {
                        metricsRow("Cost/1K tokens", value: formatCost(agg.costPerKTokens))
                    }

                    metricsRow("Sessions", value: "\(aggregator.recentSessionsUsage.count)")
                    metricsRow("Total Lines", value: "\(agg.messageCount)")

                    if let start = agg.startTime, let end = agg.endTime {
                        metricsRow("Time Range", value: "\(start.formatted(date: .abbreviated, time: .omitted)) – \(end.formatted(date: .abbreviated, time: .omitted))")
                    }
                }
                .padding(14)
                .background(.quaternary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                if !agg.modelUsage.isEmpty {
                    modelBreakdownSection(agg.modelUsage)
                }
            }
        }
    }

    // MARK: - Model Breakdown

    @ViewBuilder
    private func modelBreakdownSection(_ models: [ModelUsageBreakdown]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model Distribution")
                .font(.subheadline.weight(.semibold))

            let totalTokens = models.reduce(0) { $0 + $1.totalTokens }

            ForEach(models) { model in
                HStack(spacing: 10) {
                    Text(model.model)
                        .font(.caption.monospaced())
                        .lineLimit(1)

                    GeometryReader { geometry in
                        let fraction = totalTokens > 0 ? Double(model.totalTokens) / Double(totalTokens) : 0
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(.blue.opacity(0.6))
                            .frame(width: geometry.size.width * fraction)
                    }
                    .frame(height: 12)

                    Text(formatTokenCount(model.totalTokens))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 60, alignment: .trailing)
                }
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Recent Sessions

    @ViewBuilder
    private var recentSessionsSection: some View {
        if !aggregator.recentSessionsUsage.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("Recent Sessions", systemImage: "clock")
                    .font(.headline)

                ForEach(aggregator.recentSessionsUsage) { session in
                    Button {
                        selectedSession = session
                    } label: {
                        usageCard(session, showSessionId: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Prompt History Link

    @ViewBuilder
    private var promptHistoryLink: some View {
        if !aggregator.promptHistory.isEmpty {
            Button {
                showingPromptHistory = true
            } label: {
                HStack {
                    Label("Prompt History (\(aggregator.promptHistory.count) entries)", systemImage: "text.bubble")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(.quaternary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Issues

    @ViewBuilder
    private var issuesSection: some View {
        if !aggregator.computationIssues.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Computation Issues", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                    .foregroundStyle(.orange)

                ForEach(Array(aggregator.computationIssues.enumerated()), id: \.offset) { _, issue in
                    Text(issue.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Shared Components

    @ViewBuilder
    private func usageCard(_ usage: UsageAggregate, showSessionId: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if showSessionId, let sessionId = usage.sessionId {
                Text(sessionId)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 16) {
                if let model = usage.modelUsage.first {
                    metricPill("Model", value: model.model)
                }

                metricPill("Tokens", value: formatTokenCount(usage.totalTokens))

                if usage.totalCostUsd > 0 {
                    metricPill("Cost", value: formatCost(usage.totalCostUsd))
                }

                if let dur = usage.duration, dur > 0 {
                    metricPill("Duration", value: formatDuration(dur))
                }
            }

            if let endTime = usage.endTime {
                Text(endTime.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func metricPill(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func metricsRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body.monospacedDigit())
        }
    }

    // MARK: - Formatting

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    private func formatCost(_ cost: Double) -> String {
        String(format: "$%.4f", cost)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds >= 3600 {
            return String(format: "%.1fh", seconds / 3600)
        } else if seconds >= 60 {
            return String(format: "%.0fm", seconds / 60)
        }
        return String(format: "%.0fs", seconds)
    }
}

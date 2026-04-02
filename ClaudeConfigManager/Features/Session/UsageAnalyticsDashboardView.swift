import SwiftUI
import Charts

// MARK: - Usage Analytics Dashboard View

/// A comprehensive analytics dashboard with Swift Charts showing usage across sessions.
/// All data is computed from local `.jsonl` files — no network access.
@MainActor
struct UsageAnalyticsDashboardView: View {
    @ObservedObject var aggregator: UsageAggregator
    @ObservedObject var scanner: TranscriptScanner

    @State private var selectedTimeWindow: TimeWindow = .thirtyDays
    @State private var filteredAggregates: [UsageAggregate] = []
    @State private var tokensPerDay: [DailyTokenData] = []
    @State private var projectUsage: [ProjectTokenData] = []
    @State private var modelDistribution: [ModelTokenData] = []
    @State private var topTools: [ToolInvocationData] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                timeWindowPicker

                metricsCards

                if !tokensPerDay.isEmpty {
                    tokensPerDayChart
                }

                HStack(alignment: .top, spacing: 20) {
                    if !projectUsage.isEmpty {
                        topProjectsChart
                    }
                    if !modelDistribution.isEmpty {
                        modelDistributionChart
                    }
                }

                if !topTools.isEmpty {
                    topToolsTable
                }
            }
            .padding(24)
        }
        .navigationTitle("Usage Analytics")
        .onChange(of: selectedTimeWindow) { _, _ in recomputeAnalytics() }
        .onAppear { recomputeAnalytics() }
    }

    // MARK: - Time Window Picker

    private var timeWindowPicker: some View {
        Picker("Time Window", selection: $selectedTimeWindow) {
            ForEach(TimeWindow.allCases) { window in
                Text(window.label).tag(window)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 400)
    }

    // MARK: - Metrics Cards

    private var metricsTotalIn: Int { filteredAggregates.reduce(0) { $0 + $1.totalTokensIn } }
    private var metricsTotalOut: Int { filteredAggregates.reduce(0) { $0 + $1.totalTokensOut } }
    private var metricsSessionCount: Int { filteredAggregates.count }
    private var metricsProjectCount: Int {
        Set(scanner.allTranscripts.filter { isWithinWindow($0.modifiedAt) }.compactMap(\.projectKey)).count
    }
    private var metricsDisplayCost: Double {
        let totalCost = filteredAggregates.reduce(0.0) { $0 + $1.totalCostUsd }
        if totalCost > 0 { return totalCost }
        return TranscriptCostEstimation.estimateCost(inputTokens: metricsTotalIn, outputTokens: metricsTotalOut, model: nil)
    }

    @ViewBuilder
    private var metricsCards: some View {
        HStack(spacing: 16) {
            metricCard("Input Tokens", value: formatTokenCount(metricsTotalIn), icon: "arrow.down.circle", color: .blue)
            metricCard("Output Tokens", value: formatTokenCount(metricsTotalOut), icon: "arrow.up.circle", color: .purple)
            metricCard("Est. Cost", value: String(format: "$%.2f", metricsDisplayCost), icon: "dollarsign.circle", color: .green)
            metricCard("Sessions", value: "\(metricsSessionCount)", icon: "bubble.left.and.bubble.right", color: .orange)
            metricCard("Projects", value: "\(metricsProjectCount)", icon: "folder", color: .teal)
        }
    }

    @ViewBuilder
    private func metricCard(_ label: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Tokens Per Day Chart

    @ViewBuilder
    private var tokensPerDayChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Tokens Per Day", systemImage: "chart.xyaxis.line")
                .font(.headline)

            Chart(tokensPerDay) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Tokens", item.inputTokens)
                )
                .foregroundStyle(by: .value("Type", "Input"))

                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Tokens", item.outputTokens)
                )
                .foregroundStyle(by: .value("Type", "Output"))
            }
            .chartForegroundStyleScale([
                "Input": .blue,
                "Output": .purple
            ])
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text(formatTokenCount(intValue))
                        }
                    }
                }
            }
            .frame(height: 220)
        }
        .padding(16)
        .background(.quaternary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Top Projects Chart

    @ViewBuilder
    private var topProjectsChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Top Projects", systemImage: "chart.bar")
                .font(.headline)

            Chart(projectUsage) { item in
                BarMark(
                    x: .value("Tokens", item.totalTokens),
                    y: .value("Project", item.projectName)
                )
                .foregroundStyle(.blue.gradient)
                .annotation(position: .trailing, alignment: .leading) {
                    Text(formatTokenCount(item.totalTokens))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let name = value.as(String.self) {
                            Text(truncateProjectName(name))
                                .font(.caption.monospaced())
                        }
                    }
                }
            }
            .frame(height: CGFloat(max(projectUsage.count, 1)) * 44)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Model Distribution Chart

    @ViewBuilder
    private var modelDistributionChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Model Distribution", systemImage: "chart.pie")
                .font(.headline)

            Chart(modelDistribution) { item in
                SectorMark(
                    angle: .value("Tokens", item.totalTokens),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(by: .value("Model", item.modelName))
                .cornerRadius(4)
            }
            .frame(height: 200)

            // Legend
            VStack(alignment: .leading, spacing: 4) {
                ForEach(modelDistribution) { item in
                    HStack(spacing: 6) {
                        Text(item.modelName)
                            .font(.caption.monospaced())
                            .lineLimit(1)
                        Spacer()
                        Text(formatTokenCount(item.totalTokens))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Top Tools Table

    @ViewBuilder
    private var topToolsTable: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Most Used Tools", systemImage: "hammer")
                .font(.headline)

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Tool")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text("Invocations")
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.quaternary.opacity(0.2))

                ForEach(Array(topTools.prefix(5).enumerated()), id: \.element.id) { index, tool in
                    HStack {
                        HStack(spacing: 8) {
                            Text("\(index + 1)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text(tool.toolName)
                                .font(.body.monospaced())
                        }
                        Spacer()
                        Text("\(tool.count)")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)

                    if index < min(topTools.count, 5) - 1 {
                        Divider().padding(.horizontal, 14)
                    }
                }
            }
            .background(.quaternary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(16)
        .background(.quaternary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Data Computation

    private func recomputeAnalytics() {
        let cutoff = selectedTimeWindow.cutoffDate
        filteredAggregates = aggregator.recentSessionsUsage.filter { agg in
            guard let endTime = agg.endTime else { return cutoff == nil }
            return cutoff == nil || endTime >= cutoff!
        }

        computeTokensPerDay()
        computeProjectUsage()
        computeModelDistribution()
        computeTopTools()
    }

    private func computeTokensPerDay() {
        let calendar = Calendar.current
        var dailyMap: [Date: (input: Int, output: Int)] = [:]

        for agg in filteredAggregates {
            guard let date = agg.endTime else { continue }
            let day = calendar.startOfDay(for: date)
            var existing = dailyMap[day] ?? (input: 0, output: 0)
            existing.input += agg.totalTokensIn
            existing.output += agg.totalTokensOut
            dailyMap[day] = existing
        }

        tokensPerDay = dailyMap.map { day, tokens in
            DailyTokenData(date: day, inputTokens: tokens.input, outputTokens: tokens.output)
        }.sorted { $0.date < $1.date }
    }

    private func computeProjectUsage() {
        let transcripts = scanner.allTranscripts.filter { isWithinWindow($0.modifiedAt) }
        var projectMap: [String: Int] = [:]

        for transcript in transcripts {
            let project = transcript.projectKey ?? "unknown"
            let tokens = (transcript.totalTokensIn ?? 0) + (transcript.totalTokensOut ?? 0)
            projectMap[project, default: 0] += tokens
        }

        projectUsage = projectMap
            .map { ProjectTokenData(projectName: $0.key, totalTokens: $0.value) }
            .sorted { $0.totalTokens > $1.totalTokens }
            .prefix(5)
            .map { $0 }
    }

    private func computeModelDistribution() {
        var modelMap: [String: Int] = [:]

        for agg in filteredAggregates {
            for model in agg.modelUsage {
                modelMap[model.model, default: 0] += model.totalTokens
            }
        }

        // Also pull from transcripts if aggregates don't have model data
        if modelMap.isEmpty {
            let transcripts = scanner.allTranscripts.filter { isWithinWindow($0.modifiedAt) }
            for transcript in transcripts {
                guard let model = transcript.model else { continue }
                let tokens = (transcript.totalTokensIn ?? 0) + (transcript.totalTokensOut ?? 0)
                modelMap[model, default: 0] += tokens
            }
        }

        modelDistribution = modelMap
            .map { ModelTokenData(modelName: $0.key, totalTokens: $0.value) }
            .sorted { $0.totalTokens > $1.totalTokens }
    }

    private func computeTopTools() {
        let parser = TranscriptParser()
        let transcripts = scanner.allTranscripts
            .filter { $0.transcriptKind == .primarySession && isWithinWindow($0.modifiedAt) }
            .prefix(50)

        var toolMap: [String: Int] = [:]

        for transcript in transcripts {
            let summary = parser.parseSummary(fileURL: URL(fileURLWithPath: transcript.transcriptPath))
            for (tool, count) in summary.toolInvocations {
                toolMap[tool, default: 0] += count
            }
        }

        topTools = toolMap
            .map { ToolInvocationData(toolName: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Helpers

    private func isWithinWindow(_ date: Date) -> Bool {
        guard let cutoff = selectedTimeWindow.cutoffDate else { return true }
        return date >= cutoff
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    private func truncateProjectName(_ name: String) -> String {
        if name.count > 25 {
            return String(name.prefix(12)) + "..." + String(name.suffix(10))
        }
        return name
    }
}

// MARK: - Supporting Types

enum TimeWindow: String, CaseIterable, Identifiable {
    case sevenDays = "7d"
    case thirtyDays = "30d"
    case ninetyDays = "90d"
    case allTime = "all"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sevenDays: "Last 7 Days"
        case .thirtyDays: "Last 30 Days"
        case .ninetyDays: "Last 90 Days"
        case .allTime: "All Time"
        }
    }

    var cutoffDate: Date? {
        switch self {
        case .sevenDays: Date.now.addingTimeInterval(-7 * 24 * 60 * 60)
        case .thirtyDays: Date.now.addingTimeInterval(-30 * 24 * 60 * 60)
        case .ninetyDays: Date.now.addingTimeInterval(-90 * 24 * 60 * 60)
        case .allTime: nil
        }
    }
}

struct DailyTokenData: Identifiable {
    let id = UUID()
    let date: Date
    let inputTokens: Int
    let outputTokens: Int
}

struct ProjectTokenData: Identifiable {
    let id = UUID()
    let projectName: String
    let totalTokens: Int
}

struct ModelTokenData: Identifiable {
    let id = UUID()
    let modelName: String
    let totalTokens: Int
}

struct ToolInvocationData: Identifiable {
    let id = UUID()
    let toolName: String
    let count: Int
}

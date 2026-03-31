import SwiftUI

struct UsageDetailView: View {
    let aggregate: UsageAggregate

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    overviewSection
                    modelBreakdownSection
                    efficiencySection
                }
                .padding(24)
            }
        }
        .frame(minWidth: 480, minHeight: 400)
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Session Usage Detail")
                    .font(.title2.weight(.semibold))

                if let sessionId = aggregate.sessionId {
                    Text(sessionId)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
        }
        .padding(20)
    }

    // MARK: - Overview

    @ViewBuilder
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Overview")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                metricCard("Input Tokens", value: formatTokenCount(aggregate.totalTokensIn))
                metricCard("Output Tokens", value: formatTokenCount(aggregate.totalTokensOut))
                metricCard("Total Tokens", value: formatTokenCount(aggregate.totalTokens))

                if aggregate.totalCostUsd > 0 {
                    metricCard("Cost", value: formatCost(aggregate.totalCostUsd))
                }

                if aggregate.messageCount > 0 {
                    metricCard("Lines", value: "\(aggregate.messageCount)")
                }

                if aggregate.toolUseCount > 0 {
                    metricCard("Tool Uses", value: "\(aggregate.toolUseCount)")
                }

                if let dur = aggregate.duration, dur > 0 {
                    metricCard("Duration", value: formatDuration(dur))
                }
            }

            if let start = aggregate.startTime {
                HStack {
                    Text("Started:")
                        .foregroundStyle(.secondary)
                    Text(start.formatted(date: .abbreviated, time: .standard))
                }
                .font(.caption)
            }
            if let end = aggregate.endTime {
                HStack {
                    Text("Ended:")
                        .foregroundStyle(.secondary)
                    Text(end.formatted(date: .abbreviated, time: .standard))
                }
                .font(.caption)
            }
        }
    }

    // MARK: - Model Breakdown

    @ViewBuilder
    private var modelBreakdownSection: some View {
        if !aggregate.modelUsage.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Model Breakdown")
                    .font(.headline)

                ForEach(aggregate.modelUsage) { model in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.model)
                            .font(.subheadline.weight(.medium).monospaced())

                        HStack(spacing: 16) {
                            VStack(alignment: .leading) {
                                Text("In")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text(formatTokenCount(model.tokensIn))
                                    .font(.caption.monospacedDigit())
                            }
                            VStack(alignment: .leading) {
                                Text("Out")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text(formatTokenCount(model.tokensOut))
                                    .font(.caption.monospacedDigit())
                            }
                            if model.costUsd > 0 {
                                VStack(alignment: .leading) {
                                    Text("Cost")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    Text(formatCost(model.costUsd))
                                        .font(.caption.monospacedDigit())
                                }
                            }
                            if let mc = model.messageCount, mc > 0 {
                                VStack(alignment: .leading) {
                                    Text("Messages")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    Text("\(mc)")
                                        .font(.caption.monospacedDigit())
                                }
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    // MARK: - Efficiency

    @ViewBuilder
    private var efficiencySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Efficiency Metrics")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                if let tpm = aggregate.tokensPerMinute {
                    row("Tokens / minute", value: String(format: "%.0f", tpm))
                }

                if aggregate.costPerKTokens > 0 {
                    row("Cost / 1K tokens", value: formatCost(aggregate.costPerKTokens))
                }

                if aggregate.totalTokens > 0 {
                    let inRatio = Double(aggregate.totalTokensIn) / Double(aggregate.totalTokens) * 100
                    row("Input ratio", value: String(format: "%.1f%%", inRatio))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    // MARK: - Components

    @ViewBuilder
    private func metricCard(_ label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(.quaternary.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func row(_ label: String, value: String) -> some View {
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

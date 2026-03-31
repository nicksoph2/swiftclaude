import SwiftUI

struct RuntimeSessionCardView: View {
    @ObservedObject var discovery: RuntimeSessionDiscovery

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Runtime Session", systemImage: "bolt.horizontal.circle")
                        .font(.title2.weight(.semibold))

                    Text(subtitle)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    badge(discovery.dataSource.displayName, color: dataSourceColor)

                    if let snapshot = discovery.currentSession {
                        badge(snapshot.isStale ? "Stale" : "Fresh", color: snapshot.isStale ? .orange : .green)
                    }
                }
            }

            if let snapshot = discovery.currentSession {
                metricsGrid(snapshot: snapshot)

                if discovery.dataSource == .transcriptDerived {
                    Text("Transcript-derived snapshot inferred from the latest primary transcript. Cost, context, and rate-limit fields may be unavailable until a live status-line feed exists.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No active session")
                        .font(.headline)
                    Text("No primary session transcript was discovered under the selected Claude root.")
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if let lastUpdateTime = discovery.lastUpdateTime {
                Text("Last update: \(lastUpdateTime.formatted(date: .abbreviated, time: .standard))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !discovery.discoveryIssues.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Discovery issues")
                        .font(.headline)

                    ForEach(discovery.discoveryIssues.map(\.localizedDescription), id: \.self) { issue in
                        Text(issue)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.separator.opacity(0.35))
        )
    }

    private var subtitle: String {
        switch discovery.dataSource {
        case .none:
            return "Live-session observability is ready, but no current session snapshot is available."
        case .transcriptDerived:
            return "Best-effort snapshot inferred from on-disk primary transcripts."
        case .statusLineSnapshot:
            return "Live snapshot decoded from Claude Code status-line JSON."
        }
    }

    private var dataSourceColor: Color {
        switch discovery.dataSource {
        case .none:
            return .gray
        case .transcriptDerived:
            return .blue
        case .statusLineSnapshot:
            return .green
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.18), in: Capsule())
    }

    private func metricsGrid(snapshot: RuntimeSessionSnapshot) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(minimum: 220), alignment: .leading),
                GridItem(.flexible(minimum: 220), alignment: .leading)
            ],
            alignment: .leading,
            spacing: 12
        ) {
            metricRow(title: "Session ID", value: snapshot.id)
            metricRow(title: "Model", value: "\(snapshot.modelDisplayName) (\(snapshot.modelId))")
            metricRow(title: "Current directory", value: snapshot.cwd)
            metricRow(title: "Project directory", value: snapshot.projectDir ?? "Unavailable")
            metricRow(title: "Transcript", value: snapshot.transcriptPath)
            metricRow(title: "Version", value: snapshot.version ?? "Unavailable")
            metricRow(title: "Context usage", value: contextSummary(snapshot))
            metricRow(title: "Cost", value: costSummary(snapshot))
            metricRow(title: "Rate limits", value: rateLimitSummary(snapshot))
        }
    }

    private func metricRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func contextSummary(_ snapshot: RuntimeSessionSnapshot) -> String {
        var parts: [String] = []

        if let usedPercentage = snapshot.usedPercentage {
            parts.append(String(format: "%.1f%% used", usedPercentage))
        }
        if let contextWindowSize = snapshot.contextWindowSize {
            parts.append("window \(contextWindowSize)")
        }
        if snapshot.totalTokens > 0 {
            parts.append("tokens \(snapshot.totalTokens)")
        }

        return parts.isEmpty ? "Unavailable" : parts.joined(separator: " | ")
    }

    private func costSummary(_ snapshot: RuntimeSessionSnapshot) -> String {
        var parts: [String] = []

        if let totalCostUsd = snapshot.totalCostUsd {
            parts.append(String(format: "$%.4f", totalCostUsd))
        }
        if let totalDurationMs = snapshot.totalDurationMs {
            parts.append("\(totalDurationMs) ms")
        }
        if let added = snapshot.totalLinesAdded, let removed = snapshot.totalLinesRemoved {
            parts.append("+\(added)/-\(removed)")
        }

        return parts.isEmpty ? "Unavailable" : parts.joined(separator: " | ")
    }

    private func rateLimitSummary(_ snapshot: RuntimeSessionSnapshot) -> String {
        var parts: [String] = []

        if let fiveHour = snapshot.fiveHourUsedPercentage {
            parts.append(String(format: "5h %.1f%%", fiveHour))
        }
        if let sevenDay = snapshot.sevenDayUsedPercentage {
            parts.append(String(format: "7d %.1f%%", sevenDay))
        }

        return parts.isEmpty ? "Unavailable" : parts.joined(separator: " | ")
    }
}

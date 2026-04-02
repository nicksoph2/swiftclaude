import SwiftUI

/// Chronological timeline of a Claude exchange — from environment setup
/// through prompt, exchange, and agentic loop.
///
/// Unlike the Flow Strip (which groups by pipeline phase), this view
/// reads top-to-bottom as a story: the least sticky config at the top,
/// each layer overriding what came before, building to the merged state,
/// then the prompt, the exchange, and the loop.
struct SessionTimelineView: View {

    @EnvironmentObject private var pipeline: ConfigurationPipeline
    @StateObject private var viewModel = SessionTimelineViewModel()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            scrollContent
        }
        .onAppear {
            Task { @MainActor in
                viewModel.bind(to: pipeline)
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.2.circlepath")
                .foregroundStyle(.secondary)
            Text("Session Timeline")
                .font(.headline)

            Text("The story of a Claude exchange, told in order")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Scroll content

    private var scrollContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if viewModel.moments.isEmpty {
                    emptyState
                } else {
                    timelineContent
                }
            }
            .padding(.bottom, 40)
        }
    }

    private var timelineContent: some View {
        ForEach(TimelineAct.allCases, id: \.self) { act in
            let actMoments = viewModel.moments.filter { $0.act == act }
            if !actMoments.isEmpty {
                actSection(act, moments: actMoments)
            }
        }
    }

    // MARK: - Act section

    private func actSection(_ act: TimelineAct, moments: [TimelineMoment]) -> some View {
        VStack(spacing: 0) {
            // Act header
            actHeader(act)

            // Moments within the act
            ForEach(moments) { moment in
                momentRow(moment)
            }
        }
    }

    private func actHeader(_ act: TimelineAct) -> some View {
        HStack(spacing: 10) {
            Image(systemName: act.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(act.tint)
                .frame(width: 28, height: 28)
                .background(act.tint.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(act.rawValue)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(act.tint)
                Text(act.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(act.tint.opacity(0.04))
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Moment row

    private func momentRow(_ moment: TimelineMoment) -> some View {
        VStack(spacing: 0) {
            // Main row — tappable to expand
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.toggleMoment(moment.id)
                }
            } label: {
                momentHeader(moment)
            }
            .buttonStyle(.plain)

            // Expanded narrative + details
            if viewModel.isExpanded(moment.id) {
                momentExpanded(moment)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .overlay(alignment: .bottom) {
            Divider().opacity(0.4).padding(.leading, 56)
        }
    }

    private func momentHeader(_ moment: TimelineMoment) -> some View {
        HStack(spacing: 12) {
            // Timeline spine
            timelineSpine(moment: moment)

            // Content
            VStack(alignment: .leading, spacing: 3) {
                Text(moment.headline)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)

                if !viewModel.isExpanded(moment.id) {
                    Text(moment.narrative)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Detail count badge
            if !moment.details.isEmpty {
                HStack(spacing: 3) {
                    Text("\(moment.details.count)")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    Image(systemName: viewModel.isExpanded(moment.id)
                          ? "chevron.up" : "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.quaternary.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func timelineSpine(moment: TimelineMoment) -> some View {
        VStack(spacing: 0) {
            Image(systemName: moment.icon)
                .font(.system(size: 11))
                .foregroundStyle(moment.tint)
                .frame(width: 28, height: 28)
                .background(moment.tint.opacity(0.1))
                .clipShape(Circle())
        }
    }

    // MARK: - Expanded content

    private func momentExpanded(_ moment: TimelineMoment) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Full narrative
            Text(moment.narrative)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 56)
                .padding(.bottom, 8)

            // Detail rows
            if !moment.details.isEmpty {
                VStack(spacing: 0) {
                    ForEach(moment.details) { detail in
                        detailRow(detail, tint: moment.tint)
                    }
                }
                .padding(.leading, 56)
                .padding(.trailing, 16)
                .padding(.bottom, 8)
            }
        }
    }

    private func detailRow(_ detail: TimelineDetail, tint: Color) -> some View {
        HStack(spacing: 8) {
            // Status indicator
            detailStatusDot(detail.status)

            VStack(alignment: .leading, spacing: 1) {
                Text(detail.text)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(detailTextColor(detail.status))

                if !detail.note.isEmpty {
                    Text(detail.note)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(detailBackground(detail.status))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .padding(.vertical, 1)
    }

    @ViewBuilder
    private func detailStatusDot(_ status: TimelineDetail.DetailStatus) -> some View {
        switch status {
        case .active:
            Circle().fill(.green).frame(width: 5, height: 5)
        case .overridden:
            Image(systemName: "xmark")
                .font(.system(size: 6, weight: .bold))
                .foregroundStyle(.red.opacity(0.6))
                .frame(width: 5, height: 5)
        case .inactive:
            Circle().fill(.secondary.opacity(0.3)).frame(width: 5, height: 5)
        case .enforced:
            Image(systemName: "lock.fill")
                .font(.system(size: 6))
                .foregroundStyle(.orange)
                .frame(width: 5, height: 5)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 6))
                .foregroundStyle(.yellow)
                .frame(width: 5, height: 5)
        }
    }

    private func detailTextColor(_ status: TimelineDetail.DetailStatus) -> Color {
        switch status {
        case .active: .primary
        case .overridden: .secondary
        case .inactive: .secondary.opacity(0.6)
        case .enforced: .orange
        case .warning: .yellow
        }
    }

    private func detailBackground(_ status: TimelineDetail.DetailStatus) -> Color {
        switch status {
        case .active: .clear
        case .overridden: .red.opacity(0.03)
        case .inactive: .clear
        case .enforced: .orange.opacity(0.04)
        case .warning: .yellow.opacity(0.04)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.2.circlepath")
                .font(.system(size: 28))
                .foregroundStyle(.secondary.opacity(0.4))
            Text("No configuration loaded")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("Select a Claude root directory to see the session timeline")
                .font(.system(size: 11))
                .foregroundStyle(.secondary.opacity(0.6))
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}

import SwiftUI

/// Stage 5 — Tool Execution Flow detail view.
///
/// Displays a vertical flowchart of the 4 gates a tool request passes through:
/// 1. PreToolUse Hooks — inspection/rejection before execution
/// 2. Permission Rules — deny/ask/allow evaluation
/// 3. Execution — the tool runs
/// 4. PostToolUse Hooks — post-execution processing
///
/// Each gate is a styled card with connecting arrows. Gate border colors indicate
/// status: green (active with items), gray (empty), red with strikethrough (suppressed).
struct TreeToolExecutionView: View {

    @EnvironmentObject private var pipeline: ConfigurationPipeline
    @StateObject private var viewModel = TreeToolExecutionViewModel()
    @State private var showWhatIfInspector: Bool = false

    /// Optional callback for cross-stage navigation.
    var onNavigate: ((TreeNavigationTarget) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StageExplanationView(stage: .toolExecution)
                Spacer()
                Button {
                    showWhatIfInspector = true
                } label: {
                    Label("What If", systemImage: "questionmark.diamond")
                        .font(.caption)
                }
                .help("Test a tool invocation")
            }

            if viewModel.isLiveSession, let toolName = viewModel.liveActiveToolName {
                activeToolBanner(toolName: toolName)
            }

            if viewModel.gates.isEmpty {
                noDataPlaceholder
            } else {
                teachingCallout
                gateFlowchart
                permissionWalkthrough
            }
        }
        .onAppear {
            Task { @MainActor in viewModel.bind(to: pipeline) }
        }
        .sheet(isPresented: $showWhatIfInspector) {
            WhatIfInspectorView()
        }
    }

    // MARK: - Active Tool Banner

    private func activeToolBanner(toolName: String) -> some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)

            Image(systemName: "hammer.fill")
                .font(.caption)
                .foregroundStyle(.green)

            Text("Running: ")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            + Text(toolName)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(.green)

            Spacer()

            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
                .modifier(PulsingDotModifier())
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.easeInOut(duration: 0.3), value: toolName)
    }

    // MARK: - No Data

    private var noDataPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No tool execution data available")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Run the pipeline to see how tool requests are evaluated through hooks and permission rules.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    // MARK: - Teaching Callout

    private var teachingCallout: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
                .font(.callout)

            Text("Every tool invocation passes through this pipeline. Pre-hooks can inspect or reject the request, permission rules determine if the tool is allowed, and post-hooks process the result. If any gate blocks, the tool does not execute.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.yellow.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.yellow.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Gate Flowchart

    private var gateFlowchart: some View {
        VStack(alignment: .center, spacing: 0) {
            ForEach(Array(viewModel.gates.enumerated()), id: \.element.id) { index, gate in
                gateCard(gate, number: index + 1)
                    .id(TreeNavigationTarget.toolExecutionGate(gate.gateType).anchorID)

                if index < viewModel.gates.count - 1 {
                    flowArrow
                }
            }
        }
    }

    // MARK: - Permission Evaluation Walkthrough

    private var permissionWalkthrough: some View {
        PermissionEvaluationWalkthroughView(
            actualDenyRules: viewModel.denyRules.map(\.pattern),
            actualAskRules: viewModel.askRules.map(\.pattern),
            actualAllowRules: viewModel.allowRules.map(\.pattern)
        )
    }

    // MARK: - Gate Card

    private func gateCard(_ gate: ExecutionGate, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            gateHeader(gate, number: number)

            switch gate.status {
            case .suppressed(let reason):
                suppressedContent(reason: reason)
            case .empty:
                emptyContent(for: gate.gateType)
            case .active:
                activeContent(for: gate)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(gateBorderColor(for: gate.status), lineWidth: 1.5)
        )
        .opacity(gateOpacity(for: gate.status))
    }

    private func gateHeader(_ gate: ExecutionGate, number: Int) -> some View {
        HStack(spacing: 8) {
            Text("\(number)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(gateHeaderColor(for: gate.status)))

            Image(systemName: gateIcon(for: gate.gateType))
                .font(.subheadline)
                .foregroundStyle(gateHeaderColor(for: gate.status))

            Text(gateTitle(for: gate.gateType))
                .font(.subheadline.weight(.medium))
                .strikethrough(isSuppressed(gate.status))

            Spacer()

            gateStatusBadge(gate.status)
        }
    }

    // MARK: - Gate Content Variants

    private func suppressedContent(reason: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "nosign")
                .font(.caption)
                .foregroundStyle(.red)
            Text(reason)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.red.opacity(0.05))
        )
    }

    private func emptyContent(for gateType: ExecutionGateType) -> some View {
        Text(emptyMessage(for: gateType))
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.vertical, 2)
    }

    @ViewBuilder
    private func activeContent(for gate: ExecutionGate) -> some View {
        switch gate.gateType {
        case .preHook, .postHook:
            hookGateContent(gate)
        case .permissions:
            permissionsGateContent(gate)
        case .execution:
            executionGateContent(gate)
        }
    }

    // MARK: - Hook Gate Content

    private func hookGateContent(_ gate: ExecutionGate) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(gate.items) { item in
                hookItemRow(item, gateType: gate.gateType)
            }
        }
    }

    private func hookItemRow(_ item: ExecutionGateItem, gateType: ExecutionGateType) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: hookItemIcon(for: item))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(item.label)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(2)

                Spacer()

                if let scope = item.sourceScope {
                    ScopeColorScheme.scopeBadge(for: scope)
                }
            }

            if let detail = item.detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 22)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.5))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // Stage 5 → Stage 6: Cross-nav to hooks lifecycle event
            let eventKey = gateType == .preHook ? "PreToolUse" : "PostToolUse"
            onNavigate?(.hooksEvent(eventKey))
        }
        .help("Tap to view this hook in Stage 6 — Hooks Lifecycle")
    }

    private func hookItemIcon(for item: ExecutionGateItem) -> String {
        if item.label.hasPrefix("http") || item.label.contains("://") {
            return "network"
        } else if item.label.contains("agent") {
            return "person.2"
        } else if item.label.contains("prompt") {
            return "text.bubble"
        }
        return "terminal"
    }

    // MARK: - Permissions Gate Content

    private func permissionsGateContent(_ gate: ExecutionGate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !viewModel.denyRules.isEmpty {
                permissionSection(title: "DENY", rules: viewModel.denyRules, color: .red)
            }

            if !viewModel.askRules.isEmpty {
                permissionSection(title: "ASK", rules: viewModel.askRules, color: .orange)
            }

            if !viewModel.allowRules.isEmpty {
                permissionSection(title: "ALLOW", rules: viewModel.allowRules, color: .green)
            }

            if viewModel.denyRules.isEmpty && viewModel.askRules.isEmpty && viewModel.allowRules.isEmpty {
                // Only default mode item
                if let item = gate.items.first {
                    Text(item.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let detail = item.detail {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // Default mode footer
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Default mode: \(viewModel.defaultPermissionMode)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 2)
        }
    }

    private func permissionSection(
        title: String,
        rules: [PermissionRuleDisplay],
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 3))

            ForEach(rules) { rule in
                HStack(spacing: 6) {
                    Image(systemName: permissionIcon(for: rule.ruleType))
                        .font(.caption2)
                        .foregroundStyle(color)

                    Text(rule.pattern)
                        .font(.system(.caption, design: .monospaced))

                    Spacer()

                    ScopeColorScheme.scopeBadge(for: rule.sourceScope)
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 4)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.5))
        )
    }

    // MARK: - Execution Gate Content

    private func executionGateContent(_ gate: ExecutionGate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let item = gate.items.first {
                HStack(spacing: 6) {
                    Image(systemName: "play.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text(item.label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                }
                if let detail = item.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Flow Arrow

    private var flowArrow: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 2, height: 12)
            Image(systemName: "chevron.down")
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.5))
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 2, height: 12)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Styling Helpers

    private func gateBorderColor(for status: GateStatus) -> Color {
        switch status {
        case .active: .green.opacity(0.5)
        case .empty: .secondary.opacity(0.3)
        case .suppressed: .red.opacity(0.4)
        }
    }

    private func gateHeaderColor(for status: GateStatus) -> Color {
        switch status {
        case .active: .accentColor
        case .empty: .secondary
        case .suppressed: .red
        }
    }

    private func gateOpacity(for status: GateStatus) -> Double {
        switch status {
        case .suppressed: 0.7
        default: 1.0
        }
    }

    private func isSuppressed(_ status: GateStatus) -> Bool {
        if case .suppressed = status { return true }
        return false
    }

    private func gateIcon(for gateType: ExecutionGateType) -> String {
        switch gateType {
        case .preHook: "arrow.right.to.line"
        case .permissions: "lock.shield"
        case .execution: "play.circle"
        case .postHook: "arrow.left.to.line"
        }
    }

    private func gateTitle(for gateType: ExecutionGateType) -> String {
        switch gateType {
        case .preHook: "PreToolUse Hooks"
        case .permissions: "Permission Rules"
        case .execution: "Execution"
        case .postHook: "PostToolUse Hooks"
        }
    }

    private func gateStatusBadge(_ status: GateStatus) -> some View {
        Group {
            switch status {
            case .active:
                Label("Active", systemImage: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            case .empty:
                Label("None", systemImage: "circle.dashed")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            case .suppressed:
                Label("Skipped", systemImage: "slash.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }

    private func emptyMessage(for gateType: ExecutionGateType) -> String {
        switch gateType {
        case .preHook:
            "No PreToolUse hooks configured — tool requests pass through."
        case .permissions:
            "No explicit permission rules configured."
        case .execution:
            "Tool runs with approved inputs."
        case .postHook:
            "No PostToolUse hooks configured — results pass through."
        }
    }

    private func permissionIcon(for ruleType: PermissionRuleType) -> String {
        switch ruleType {
        case .deny: "xmark.circle.fill"
        case .ask: "questionmark.circle.fill"
        case .allow: "checkmark.circle.fill"
        }
    }
}

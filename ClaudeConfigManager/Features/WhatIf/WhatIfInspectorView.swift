import SwiftUI

struct WhatIfInspectorView: View {
    @EnvironmentObject private var router: AppRouter
    @State private var toolInvocation: String = ""
    @State private var simulationResult: SimulationResult?
    @State private var debounceTask: Task<Void, Never>?
    @State private var placeholderIndex: Int = 0
    @State private var placeholderTimer: Timer?

    private let simulator = PermissionRuleSimulator()

    private let placeholderExamples = [
        "bash: git push --force",
        "mcp__github__create_issue",
        "read: /etc/hosts",
        "bash: rm -rf /tmp",
        "write: ~/.bashrc",
        "bash: git status"
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    inputSection
                    if simulationResult != nil {
                        resultSection
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 480, minHeight: 400)
        .onAppear { startPlaceholderCycling() }
        .onDisappear { placeholderTimer?.invalidate() }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test a tool invocation")
                .font(.headline.weight(.semibold))

            Text("Enter a tool invocation to see how Claude's permission rules would handle it.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField(
                    placeholderExamples[placeholderIndex],
                    text: $toolInvocation
                )
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .onChange(of: toolInvocation) { _, newValue in
                    scheduleEvaluation(for: newValue)
                }

                Button("Evaluate") {
                    evaluateNow()
                }
                .disabled(toolInvocation.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: - Result Section

    @ViewBuilder
    private var resultSection: some View {
        if let result = simulationResult {
            VStack(alignment: .leading, spacing: 20) {
                outcomeBanner(for: result.outcome)

                if let matchedRule = result.matchedRule {
                    matchedRuleCallout(
                        rule: matchedRule,
                        scope: result.matchedRuleScope,
                        gate: result.matchedAt
                    )
                }

                evaluationTraceSection(trace: result.evaluationTrace)

                hooksSection(hooks: result.hooksTriggered)
            }
        }
    }

    // MARK: - Outcome Banner

    private func outcomeBanner(for outcome: PermissionOutcome) -> some View {
        let (text, color, icon) = outcomeBannerContent(for: outcome)

        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(color)

                Text(outcomeDescription(for: outcome))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
        )
    }

    private func outcomeBannerContent(for outcome: PermissionOutcome) -> (String, Color, String) {
        switch outcome {
        case .blocked:
            return ("BLOCKED", .red, "xmark.shield.fill")
        case .askUser:
            return ("ASK USER", .orange, "questionmark.circle.fill")
        case .allowed:
            return ("ALLOWED", .green, "checkmark.shield.fill")
        case .allowedByDefault:
            return ("ALLOWED BY DEFAULT", Color.green.opacity(0.7), "checkmark.circle")
        case .askedByDefault:
            return ("ASK BY DEFAULT", Color.orange.opacity(0.7), "questionmark.circle")
        }
    }

    private func outcomeDescription(for outcome: PermissionOutcome) -> String {
        switch outcome {
        case .blocked:
            return "This invocation would be blocked"
        case .askUser:
            return "Claude would ask your permission before running this"
        case .allowed:
            return "This invocation would be allowed"
        case .allowedByDefault:
            return "No rule matches — Claude's default is to allow this"
        case .askedByDefault:
            return "No rule matches — Claude's default is to ask"
        }
    }

    // MARK: - Matched Rule Callout

    private func matchedRuleCallout(
        rule: String,
        scope: ResolutionScope?,
        gate: PermissionOutcome.Gate
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Matched rule")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                Text(rule)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)

                Spacer()

                if let scope {
                    ScopeColorScheme.scopeBadge(for: scope)
                }

                Text(gate.rawValue.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(gateColor(for: gate))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(gateColor(for: gate).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Evaluation Trace

    private func evaluationTraceSection(trace: [EvaluationStep]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Evaluation trace")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if trace.isEmpty {
                Text("No rules to evaluate.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                let matchIndex = trace.firstIndex(where: { $0.matched })

                VStack(spacing: 4) {
                    ForEach(Array(trace.enumerated()), id: \.offset) { index, step in
                        let isPastMatch = matchIndex.map { index > $0 } ?? false
                        traceStepRow(step: step, isHighlighted: step.matched, isDimmed: isPastMatch)
                    }
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private func traceStepRow(step: EvaluationStep, isHighlighted: Bool, isDimmed: Bool) -> some View {
        HStack(spacing: 8) {
            // Gate badge
            Text(step.gate.rawValue.uppercased())
                .font(.system(.caption2, design: .monospaced).weight(.medium))
                .foregroundStyle(gateColor(for: step.gate))
                .frame(width: 40, alignment: .leading)

            // Rule pattern
            Text(step.rule)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)

            Spacer()

            // Match indicator
            if step.matched {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.caption)
                    .foregroundStyle(gateColor(for: step.gate))
            }

            // Outcome text
            Text(step.outcome)
                .font(.caption2)
                .foregroundStyle(step.matched ? gateColor(for: step.gate) : .secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isHighlighted ? gateColor(for: step.gate).opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .opacity(isDimmed ? 0.4 : 1.0)
    }

    // MARK: - Hooks Section

    private func hooksSection(hooks: [HookSimulationEntry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hooks that would fire")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if hooks.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.slash")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text("No hooks would fire for this invocation")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(hooks.enumerated()), id: \.offset) { _, hook in
                        hookRow(hook)
                    }
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private func hookRow(_ hook: HookSimulationEntry) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.caption2)
                .foregroundStyle(.blue)

            Text(hook.event)
                .font(.caption.weight(.medium))

            Text("·")
                .foregroundStyle(.secondary)

            Text(hook.handlerType)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer()

            Text(hook.handlerSummary)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }

    // MARK: - Helpers

    private func gateColor(for gate: PermissionOutcome.Gate) -> Color {
        switch gate {
        case .deny: .red
        case .ask: .orange
        case .allow: .green
        }
    }

    private func scheduleEvaluation(for text: String) {
        debounceTask?.cancel()
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            simulationResult = nil
            return
        }
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms debounce
            guard !Task.isCancelled else { return }
            evaluateNow()
        }
    }

    private func evaluateNow() {
        let trimmed = toolInvocation.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard let projection = router.pipeline.projection else { return }
        simulationResult = simulator.evaluate(toolInvocation: trimmed, against: projection)
    }

    private func startPlaceholderCycling() {
        placeholderTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task { @MainActor in
                placeholderIndex = (placeholderIndex + 1) % placeholderExamples.count
            }
        }
    }
}

#Preview {
    WhatIfInspectorView()
        .environmentObject(AppRouter())
}

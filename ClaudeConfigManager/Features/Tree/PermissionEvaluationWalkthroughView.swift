import SwiftUI

/// Displays a static step-by-step walkthrough of how permission evaluation works.
/// Shows a realistic example with deny/ask/allow rule evaluation.
struct PermissionEvaluationWalkthroughView: View {
    /// Optional: pass the user's actual deny rules to highlight the matched rule if present.
    var actualDenyRules: [String]?
    var actualAskRules: [String]?
    var actualAllowRules: [String]?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How does this work?")
                .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 10) {
                Text("Example: Claude wants to run \"bash: git status\"")
                    .font(.caption.weight(.medium))
                    .padding(.bottom, 4)

                walkthrough
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.separator.opacity(0.2), lineWidth: 0.5)
            )
        }
    }

    @ViewBuilder
    private var walkthrough: some View {
        // Step 1: Check deny rules
        stepView(
            number: 1,
            title: "Check deny rules...",
            result: "✗ No deny rule matches \"bash: git status\"",
            resultColor: .orange,
            content: {
                if let denyRules = actualDenyRules, !denyRules.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(denyRules, id: \.self) { rule in
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle")
                                    .foregroundStyle(.orange)
                                    .font(.caption2)
                                Text(rule)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Text("(No deny rules configured)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }
        )

        // Step 2: Check ask rules
        stepView(
            number: 2,
            title: "Check ask rules...",
            result: "✗ No ask rule matches \"bash: git status\"",
            resultColor: .orange,
            content: {
                if let askRules = actualAskRules, !askRules.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(askRules, id: \.self) { rule in
                            HStack(spacing: 4) {
                                Image(systemName: "questionmark.circle")
                                    .foregroundStyle(.orange)
                                    .font(.caption2)
                                Text(rule)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Text("(No ask rules configured)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }
        )

        // Step 3: Check allow rules
        stepView(
            number: 3,
            title: "Check allow rules...",
            result: "✓ Rule \"bash:*\" matches — allowed",
            resultColor: .green,
            isFinal: true,
            content: {
                if let allowRules = actualAllowRules, !allowRules.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(allowRules, id: \.self) { rule in
                            HStack(spacing: 4) {
                                if rule == "bash:*" {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.caption2)
                                    Text(rule)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.green)
                                } else {
                                    Image(systemName: "checkmark.circle")
                                        .foregroundStyle(.green)
                                        .font(.caption2)
                                    Text(rule)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } else {
                    // Show default allow example
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption2)
                        Text("bash:*")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                }
            }
        )

        // Final result
        HStack(spacing: 8) {
            Image(systemName: "arrow.right.circle.fill")
                .foregroundStyle(.green)
            Text("Result: Claude runs the command without asking.")
                .font(.caption.weight(.medium))
                .foregroundStyle(.green)
        }
        .padding(8)
        .background(Color.green.opacity(0.08))
        .cornerRadius(4)
    }

    @ViewBuilder
    private func stepView<Content: View>(
        number: Int,
        title: String,
        result: String,
        resultColor: Color,
        isFinal: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Step number and title
            HStack(spacing: 6) {
                Text("Step \(number):")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption.weight(.medium))
            }

            // Content
            content()

            // Result
            HStack(spacing: 4) {
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(resultColor)
                Text(result)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(resultColor)
            }

            if !isFinal {
                Divider()
                    .padding(.vertical, 2)
            }
        }
    }
}

#if DEBUG
#Preview {
    VStack {
        PermissionEvaluationWalkthroughView(
            actualAllowRules: ["bash:*", "read: ~/.claude/**"]
        )
        Spacer()
    }
    .padding()
}
#endif

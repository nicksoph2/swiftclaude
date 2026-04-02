import SwiftUI

/// Displays illustrative examples of how different merge methods work.
/// Static diagrams showing Override, Merge, and Deep Merge scenarios.
struct MergeMethodExampleView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Override example
            exampleSection(
                title: "Override",
                description: "Higher scope completely replaces lower scope.",
                content: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("User scope:")
                                .font(.caption.weight(.semibold))
                            Text("model = \"claude-sonnet-4-6\"")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "xmark.circle")
                                .foregroundStyle(.red)
                                .font(.caption2)
                            Text("overridden")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.05))
                        .cornerRadius(4)

                        HStack {
                            Text("Project scope:")
                                .font(.caption.weight(.semibold))
                            Text("model = \"claude-opus-4-6\"")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption2)
                            Text("wins")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.05))
                        .cornerRadius(4)

                        Divider()
                            .padding(.vertical, 4)

                        HStack {
                            Text("Effective:")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.blue)
                            Text("model = \"claude-opus-4-6\"")
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                }
            )

            // Merge example
            exampleSection(
                title: "Merge",
                description: "Values from all scopes are combined into arrays.",
                content: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("User scope:")
                                .font(.caption.weight(.semibold))
                            Text("permissions.deny = [\"bash: rm -rf *\"]")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                                .font(.caption2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(4)

                        HStack {
                            Text("Project scope:")
                                .font(.caption.weight(.semibold))
                            Text("permissions.deny = [\"git: push --force\"]")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                                .font(.caption2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(4)

                        Divider()
                            .padding(.vertical, 4)

                        HStack(alignment: .top) {
                            Text("Effective:")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("permissions.deny = [")
                                    .font(.system(.caption, design: .monospaced))
                                Text("  \"bash: rm -rf *\",")
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(.leading, 8)
                                Text("  \"git: push --force\"")
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(.leading, 8)
                                Text("]")
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                    }
                }
            )

            // Deep Merge example
            exampleSection(
                title: "Deep Merge",
                description: "Objects are recursively merged; arrays within objects are also merged.",
                content: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("User scope:")
                                .font(.caption.weight(.semibold))
                            Text("env = { \"API_KEY\": \"abc\" }")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.purple)
                                .font(.caption2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.05))
                        .cornerRadius(4)

                        HStack {
                            Text("Project scope:")
                                .font(.caption.weight(.semibold))
                            Text("env = { \"DEBUG\": \"true\" }")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.purple)
                                .font(.caption2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.05))
                        .cornerRadius(4)

                        Divider()
                            .padding(.vertical, 4)

                        HStack(alignment: .top) {
                            Text("Effective:")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("env = {")
                                    .font(.system(.caption, design: .monospaced))
                                Text("  \"API_KEY\": \"abc\",")
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(.leading, 8)
                                Text("  \"DEBUG\": \"true\"")
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(.leading, 8)
                                Text("}")
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                    }
                }
            )
        }
    }

    @ViewBuilder
    private func exampleSection<Content: View>(
        title: String,
        description: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            Text(description)
                .font(.caption2)
                .foregroundStyle(.secondary)
            content()
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

#if DEBUG
#Preview {
    ScrollView {
        MergeMethodExampleView()
            .padding()
    }
}
#endif

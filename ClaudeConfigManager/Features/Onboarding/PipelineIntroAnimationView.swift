import SwiftUI

/// Animated pipeline introduction shown on first launch.
///
/// Tells the story "Files on disk → Claude agent" through a five-phase animation
/// sequence (~8 seconds total). Each phase uses standard SwiftUI transitions.
///
/// **Trigger**: Shown as a sheet on the dashboard when `AppStorage("hasSeenIntro")` is false.
/// Also accessible via Help menu → "How Claude Code works".
struct PipelineIntroAnimationView: View {

    @AppStorage("hasSeenIntro") private var hasSeenIntro: Bool = false

    /// The current animation phase (0-based).
    @State private var currentPhase: Int = 0

    /// Whether auto-advance is active.
    @State private var autoAdvancing: Bool = true

    /// Timer for auto-advance.
    @State private var advanceTimer: Timer?

    /// Dismiss action from parent sheet.
    var onDismiss: (() -> Void)?

    private let totalPhases = 5
    private let phaseDuration: TimeInterval = 1.6

    private let phaseNarrations: [String] = [
        "Claude Code reads your configuration files…",
        "…parses them into structured settings and instructions…",
        "…resolves conflicts when multiple files disagree…",
        "…assembles a complete context for Claude to work with…",
        "…and your configured Claude agent begins."
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button("Skip") {
                    finish()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.callout)
                .padding(16)
            }

            Spacer()

            // Animation canvas
            animationArea
                .frame(height: 220)

            Spacer()
                .frame(height: 24)

            // Narration label
            Text(phaseNarrations[currentPhase])
                .font(.title3)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)
                .padding(.horizontal, 24)
                .animation(.easeInOut(duration: 0.3), value: currentPhase)
                .id("narration-\(currentPhase)")
                .transition(.opacity)

            Spacer()
                .frame(height: 32)

            // Progress dots and navigation
            HStack(spacing: 16) {
                Button {
                    navigateBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .foregroundStyle(currentPhase > 0 ? .primary : .quaternary)
                .disabled(currentPhase == 0)

                HStack(spacing: 8) {
                    ForEach(0..<totalPhases, id: \.self) { index in
                        Circle()
                            .fill(index == currentPhase ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentPhase ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: currentPhase)
                    }
                }

                Button {
                    navigateForward()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .foregroundStyle(currentPhase < totalPhases - 1 ? .primary : .quaternary)
                .disabled(currentPhase >= totalPhases - 1)
            }

            Spacer()
                .frame(height: 20)

            // Get started button (shown on last phase)
            if currentPhase == totalPhases - 1 {
                Button("Get started →") {
                    finish()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer()
                .frame(height: 32)
        }
        .frame(width: 640, height: 520)
        .onAppear {
            startAutoAdvance()
        }
        .onDisappear {
            advanceTimer?.invalidate()
        }
    }

    // MARK: - Animation Area

    @ViewBuilder
    private var animationArea: some View {
        ZStack {
            // Phase 0: File icons appear from left
            fileIcons
            // Phase 1: Parser box
            parserBox
            // Phase 2: Resolver box
            resolverBox
            // Phase 3: Prompt stack
            promptStack
            // Phase 4: Claude agent icon
            agentIcon
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var fileIcons: some View {
        let visible = currentPhase >= 0
        let flowedIntoParser = currentPhase >= 1

        HStack(spacing: 12) {
            fileIcon(name: "settings.json", systemImage: "gearshape.fill", color: .blue)
            fileIcon(name: "CLAUDE.md", systemImage: "doc.text.fill", color: .green)
            fileIcon(name: ".mcp.json", systemImage: "server.rack", color: .purple)
        }
        .offset(x: flowedIntoParser ? 60 : -40)
        .opacity(visible && !flowedIntoParser ? 1 : (flowedIntoParser ? 0 : 0))
        .scaleEffect(visible && !flowedIntoParser ? 1 : 0.8)
        .animation(.easeInOut(duration: 0.6), value: currentPhase)
    }

    @ViewBuilder
    private func fileIcon(name: String, systemImage: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
                .foregroundStyle(color)
            Text(name)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
        }
        .frame(width: 90, height: 70)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(color.opacity(0.2), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var parserBox: some View {
        let active = currentPhase == 1
        let past = currentPhase > 1

        VStack(spacing: 6) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 24))
                .foregroundStyle(.orange)
            Text("Parser")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

            // Token stream output
            if active {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Text("key=val")
                            .font(.system(size: 9, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .opacity(active ? 1 : 0)
                            .offset(x: active ? CGFloat(i * 8) : 0)
                            .animation(
                                .easeOut(duration: 0.5).delay(Double(i) * 0.2),
                                value: currentPhase
                            )
                    }
                }
            }
        }
        .frame(width: 160, height: 90)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(active ? Color.orange.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(active ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1.5)
                )
        )
        .scaleEffect(active ? 1.05 : (past ? 0.9 : 0.8))
        .opacity(active ? 1 : 0)
        .animation(.easeInOut(duration: 0.5), value: currentPhase)
    }

    @ViewBuilder
    private var resolverBox: some View {
        let active = currentPhase == 2

        VStack(spacing: 6) {
            Image(systemName: "arrow.triangle.merge")
                .font(.system(size: 24))
                .foregroundStyle(.teal)
            Text("Resolver")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

            if active {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("1 winner per key")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            }
        }
        .frame(width: 160, height: 90)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(active ? Color.teal.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(active ? Color.teal.opacity(0.4) : Color.clear, lineWidth: 1.5)
                )
        )
        .scaleEffect(active ? 1.05 : 0.8)
        .opacity(active ? 1 : 0)
        .animation(.easeInOut(duration: 0.5), value: currentPhase)
    }

    @ViewBuilder
    private var promptStack: some View {
        let active = currentPhase == 3

        VStack(spacing: 4) {
            // Stacked layers
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.indigo.opacity(0.08))
                    .frame(width: 120, height: 20)
                    .offset(y: -12)
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.indigo.opacity(0.15))
                    .frame(width: 130, height: 20)
                    .offset(y: 0)
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.indigo.opacity(0.25))
                    .frame(width: 140, height: 20)
                    .offset(y: 12)
            }
            .frame(height: 50)

            Text("Prompt Stack")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

            if active {
                Text("~4,200 tokens")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.indigo)
                    .transition(.opacity)
            }
        }
        .frame(width: 160, height: 100)
        .scaleEffect(active ? 1.05 : 0.8)
        .opacity(active ? 1 : 0)
        .animation(.easeInOut(duration: 0.5), value: currentPhase)
    }

    @ViewBuilder
    private var agentIcon: some View {
        let active = currentPhase == 4

        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }
            .shadow(color: .orange.opacity(0.3), radius: active ? 12 : 0, x: 0, y: 4)

            Text("Claude Agent")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)

            Text("Ready to assist")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .scaleEffect(active ? 1.0 : 0.5)
        .opacity(active ? 1 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: currentPhase)
    }

    // MARK: - Navigation

    private func navigateBack() {
        guard currentPhase > 0 else { return }
        stopAutoAdvance()
        withAnimation {
            currentPhase -= 1
        }
    }

    private func navigateForward() {
        guard currentPhase < totalPhases - 1 else { return }
        stopAutoAdvance()
        withAnimation {
            currentPhase += 1
        }
    }

    private func startAutoAdvance() {
        guard autoAdvancing else { return }
        advanceTimer = Timer.scheduledTimer(withTimeInterval: phaseDuration, repeats: true) { _ in
            DispatchQueue.main.async {
                if currentPhase < totalPhases - 1 {
                    withAnimation {
                        currentPhase += 1
                    }
                } else {
                    stopAutoAdvance()
                }
            }
        }
    }

    private func stopAutoAdvance() {
        autoAdvancing = false
        advanceTimer?.invalidate()
        advanceTimer = nil
    }

    private func finish() {
        stopAutoAdvance()
        hasSeenIntro = true
        onDismiss?()
    }
}

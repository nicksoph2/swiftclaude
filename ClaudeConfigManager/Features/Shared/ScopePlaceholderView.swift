import SwiftUI

struct ScopePlaceholderView: View {
    let destination: SidebarDestination
    @EnvironmentObject private var debugMonitor: AppDebugMonitor

    private var debugNotes: [String] {
        [
            "Destination raw value: \(destination.rawValue)",
            "Sidebar title: \(destination.title)",
            "This packet intentionally stops before discovery, parsing, resolution, or saving."
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                statusCard

                #if DEBUG
                debugCard
                #endif
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(destination.title)
        .onAppear(perform: pushDebugState)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(destination.title, systemImage: destination.systemImage)
                .font(.largeTitle.weight(.semibold))

            Text(destination.subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Packet A1 status")
                .font(.headline)

            Text("The shell is active and this scope is a stub screen by design.")
                .foregroundStyle(.primary)

            Text("Future packets will replace this content with scoped file discovery and read-only inspection flows.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.separator.opacity(0.35))
        )
    }

    @ViewBuilder
    private var debugCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Debug monitor")
                .font(.headline)

            ForEach(debugNotes, id: \.self) { note in
                Text(note)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func pushDebugState() {
        debugMonitor.recordDetail(
            title: destination.title,
            subtitle: destination.subtitle,
            debugNotes: debugNotes
        )
    }
}

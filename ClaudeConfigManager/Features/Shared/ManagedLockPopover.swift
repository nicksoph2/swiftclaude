import SwiftUI

/// Popover shown when a managed-locked setting is tapped
struct ManagedLockPopover: View {
    let keyPath: String
    let lockInfo: ManagedLockInfo

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            // Lock icon
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            // Title
            Text("Set by managed policy")
                .font(.headline)

            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("This setting is controlled by \(lockInfo.controllingTier.displayName) from \(lockInfo.sourcePath). You cannot override it at this level.")
                    .font(.body)
                    .lineLimit(3)

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Enforced value:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text(valueDisplayString(lockInfo.enforcedValue))
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(2)
                        Spacer()
                    }
                    .padding(8)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(4)
                }
            }

            HStack {
                Text("To change this setting, contact your administrator.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: 320)
    }

    private func valueDisplayString(_ value: JSONValue) -> String {
        switch value {
        case let .string(s):
            return "\"\(s)\""
        case let .number(n):
            return String(n)
        case let .bool(b):
            return String(b)
        case .array:
            return "[Array]"
        case .object:
            return "{Object}"
        case .null:
            return "null"
        }
    }
}

#Preview {
    ManagedLockPopover(
        keyPath: "model",
        lockInfo: ManagedLockInfo(
            controllingTier: .fileBased,
            sourcePath: "/etc/claude/managed.json",
            enforcedValue: .string("claude-opus")
        )
    )
}

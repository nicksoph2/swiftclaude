import SwiftUI

/// Displays a resolved config value in a monospace cell with status colouring.
///
/// - `.winner` — green tint, normal text
/// - `.overridden` — red tint, strikethrough
/// - `.contributor` — amber tint, normal text (for merged arrays)
/// - `.same` — blue tint (value identical across scopes)
/// - `.absent` — dimmed dash
struct ValueCellView: View {

    let displayValue: String
    let status: CellStatus

    enum CellStatus {
        case winner
        case overridden
        case contributor
        case same
        case absent
    }

    init(_ displayValue: String, status: CellStatus) {
        self.displayValue = displayValue
        self.status = status
    }

    var body: some View {
        if status == .absent {
            Text("—")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary.opacity(0.35))
                .italic()
        } else {
            Text(displayValue)
                .font(.system(size: 10, design: .monospaced))
                .strikethrough(status == .overridden)
                .foregroundStyle(textColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(bgColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(borderColor, lineWidth: 0.8)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .opacity(status == .overridden ? 0.55 : 1.0)
        }
    }

    private var textColor: Color {
        switch status {
        case .winner:      Color.green
        case .overridden:  .secondary
        case .contributor: Color.orange
        case .same:        Color.blue
        case .absent:      .secondary
        }
    }

    private var bgColor: Color {
        switch status {
        case .winner:      Color.green.opacity(0.08)
        case .overridden:  Color.red.opacity(0.04)
        case .contributor: Color.orange.opacity(0.06)
        case .same:        Color.blue.opacity(0.05)
        case .absent:      .clear
        }
    }

    private var borderColor: Color {
        switch status {
        case .winner:      Color.green.opacity(0.2)
        case .overridden:  Color.red.opacity(0.12)
        case .contributor: Color.orange.opacity(0.18)
        case .same:        Color.blue.opacity(0.15)
        case .absent:      .clear
        }
    }
}

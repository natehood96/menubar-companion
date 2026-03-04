import SwiftUI

struct ToastView: View {
    let title: String
    let message: String
    let onDismiss: () -> Void

    private let arrowWidth: CGFloat = 14
    private let arrowHeight: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            // Arrow pointing up toward the blob icon
            BubbleArrow(width: arrowWidth, height: arrowHeight)
                .fill(.ultraThinMaterial)
                .frame(width: arrowWidth, height: arrowHeight)

            // Bubble body
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            .padding(12)
            .frame(width: 280, alignment: .leading)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
        }
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .onTapGesture {
            onDismiss()
        }
    }
}

/// A small upward-pointing triangle used as the speech-bubble arrow.
private struct BubbleArrow: Shape {
    let width: CGFloat
    let height: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        path.move(to: CGPoint(x: midX, y: rect.minY))
        path.addLine(to: CGPoint(x: midX - width / 2, y: rect.minY + height))
        path.addLine(to: CGPoint(x: midX + width / 2, y: rect.minY + height))
        path.closeSubpath()
        return path
    }
}

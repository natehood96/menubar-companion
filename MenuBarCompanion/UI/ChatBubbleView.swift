import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
                Text(message.content)
                    .font(message.role == .assistant ? .system(.body, design: .monospaced) : .body)
                    .textSelection(.enabled)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(bubbleBackground)
                    .foregroundColor(bubbleForeground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if message.isStreaming {
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.mini)
                        Text("Thinking...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private var bubbleBackground: Color {
        switch message.role {
        case .user:
            return Color.accentColor
        case .assistant:
            return Color(nsColor: .controlBackgroundColor)
        case .system:
            return Color(nsColor: .controlBackgroundColor).opacity(0.5)
        }
    }

    private var bubbleForeground: Color {
        switch message.role {
        case .user:
            return .white
        case .assistant, .system:
            return .primary
        }
    }
}

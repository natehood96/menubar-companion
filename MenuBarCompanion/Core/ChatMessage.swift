import Foundation

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

struct ChatMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    var isStreaming: Bool

    init(role: MessageRole, content: String, isStreaming: Bool = false) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.isStreaming = isStreaming
    }
}

// MARK: - Persistence

struct ChatStore {
    private static let historyURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MenuBot", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("chat_history.json")
    }()

    private static let maxMessages = 200

    static func load() -> [ChatMessage] {
        guard let data = try? Data(contentsOf: historyURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([ChatMessage].self, from: data)) ?? []
    }

    static func save(_ messages: [ChatMessage]) {
        // Don't persist messages that are mid-stream
        let persistable = messages.map { msg -> ChatMessage in
            var m = msg
            m.isStreaming = false
            return m
        }
        let trimmed = persistable.count > maxMessages
            ? Array(persistable.suffix(maxMessages))
            : persistable

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(trimmed) else { return }

        // Atomic write
        let tempURL = historyURL.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".tmp")
        do {
            try data.write(to: tempURL, options: .atomic)
            try FileManager.default.moveItem(at: tempURL, to: historyURL)
        } catch {
            // moveItem fails if destination exists — overwrite instead
            try? data.write(to: historyURL, options: .atomic)
            try? FileManager.default.removeItem(at: tempURL)
        }
    }
}

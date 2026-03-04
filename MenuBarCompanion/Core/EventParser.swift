import Foundation

/// Parses [MENUBOT_EVENT] JSON payloads from command output into typed MenuBotEvent values.
///
/// Expected format:
///   [MENUBOT_EVENT] {"type":"toast","title":"Hello","message":"It worked!"}
struct EventParser {
    private static let prefix = "[MENUBOT_EVENT] "
    private static let decoder = JSONDecoder()

    /// Check if a line is an event line and extract the JSON portion.
    /// Returns nil for non-event lines or empty payloads.
    static func extractPayload(from line: String) -> String? {
        guard line.hasPrefix(prefix) else { return nil }
        let json = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        guard !json.isEmpty else { return nil }
        return json
    }

    /// Parse a JSON string into a typed MenuBotEvent.
    /// Returns nil for malformed JSON or unknown event types (does not crash).
    static func parseEvent(from json: String) -> MenuBotEvent? {
        guard let data = json.data(using: .utf8) else { return nil }
        do {
            return try decoder.decode(MenuBotEvent.self, from: data)
        } catch {
            print("[EventParser] Failed to decode event: \(error)")
            return nil
        }
    }
}

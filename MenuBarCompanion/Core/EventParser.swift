import Foundation

/// Parses [MENUBOT_EVENT] JSON payloads from command output.
///
/// Expected format:
///   [MENUBOT_EVENT] {"type":"toast","title":"Hello","message":"It worked!"}
///
/// This is a skeleton — expand as event types are added.
enum EventParser {
    struct MenuBotEvent {
        let type: String
        let payload: [String: Any]
    }

    /// Parse a JSON string into a MenuBotEvent description.
    /// Returns a human-readable summary for display.
    static func parse(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return "unknown (invalid JSON)"
        }

        let type = obj["type"] as? String ?? "unknown"

        switch type {
        case "toast":
            let title = obj["title"] as? String ?? ""
            let message = obj["message"] as? String ?? ""
            return "toast — \(title): \(message)"
        default:
            return "\(type) — \(json)"
        }
    }

    /// Strongly-typed parse (for future use when handling events programmatically).
    static func parseEvent(_ json: String) -> MenuBotEvent? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["type"] as? String
        else {
            return nil
        }
        return MenuBotEvent(type: type, payload: obj)
    }
}

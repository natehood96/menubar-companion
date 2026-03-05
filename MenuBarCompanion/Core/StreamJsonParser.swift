import Foundation

/// Parses Claude Code `--output-format stream-json` NDJSON lines
/// and extracts displayable text content.
///
/// Stream-json emits one JSON object per line. Key event types:
///   - `init`        → session started
///   - `message`     → assistant turn with content array
///   - `tool_use`    → Claude invoking a tool
///   - `tool_result` → output from a tool
///   - `result`      → final completion status
enum StreamJsonParser {

    enum ParsedEvent {
        /// Displayable text from an assistant message
        case assistantText(String)
        /// Incremental text delta (for streaming display, append without newline)
        case assistantDelta(String)
        /// Claude is using a tool (name + optional input summary)
        case toolUse(name: String)
        /// Result from a tool invocation
        case toolResult(output: String)
        /// A MenuBot event line embedded in tool output
        case menubotEvent(String)
        /// Session completed
        case done(exitStatus: String?)
        /// Unrecognized or ignorable event
        case ignored
    }

    /// Parse a single NDJSON line from stream-json output.
    static func parse(line: String) -> ParsedEvent {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .ignored }

        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return .ignored
        }

        switch type {
        case "assistant":
            return parseAssistantMessage(json)
        case "message":
            // Some versions use "message" with role
            if let role = json["role"] as? String, role == "assistant" {
                return parseAssistantMessage(json)
            }
            return .ignored
        case "tool_use":
            let name = json["name"] as? String ?? "unknown"
            return .toolUse(name: name)
        case "tool_result":
            if let output = json["output"] as? String {
                // Check for MenuBot events inside tool output
                if let eventPayload = EventParser.extractPayload(from: output) {
                    return .menubotEvent(eventPayload)
                }
                return .toolResult(output: output)
            }
            if let content = json["content"] as? String {
                return .toolResult(output: content)
            }
            return .ignored
        case "content_block_delta":
            if let delta = json["delta"] as? [String: Any],
               delta["type"] as? String == "text_delta",
               let text = delta["text"] as? String {
                return .assistantDelta(text)
            }
            return .ignored
        case "content_block_start":
            if let contentBlock = json["content_block"] as? [String: Any],
               contentBlock["type"] as? String == "text",
               let text = contentBlock["text"] as? String,
               !text.isEmpty {
                return .assistantDelta(text)
            }
            return .ignored
        case "result":
            let status = json["status"] as? String
            return .done(exitStatus: status)
        default:
            return .ignored
        }
    }

    // MARK: - Private

    private static func parseAssistantMessage(_ json: [String: Any]) -> ParsedEvent {
        // Content can be a string or an array of content blocks
        if let contentString = json["content"] as? String {
            return .assistantText(contentString)
        }

        if let contentArray = json["content"] as? [[String: Any]] {
            let textParts = contentArray.compactMap { block -> String? in
                guard block["type"] as? String == "text" else { return nil }
                return block["text"] as? String
            }
            let combined = textParts.joined()
            guard !combined.isEmpty else { return .ignored }
            return .assistantText(combined)
        }

        // Try "message" wrapper: { message: { content: [...] } }
        if let message = json["message"] as? [String: Any] {
            return parseAssistantMessage(message)
        }

        return .ignored
    }
}

import Foundation

// MARK: - Event Action

enum EventAction: Codable {
    case openFile(path: String)
    case openURL(url: String)
    case copyText(text: String)

    private enum CodingKeys: String, CodingKey {
        case kind, path, url, text
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "openFile":
            let path = try container.decode(String.self, forKey: .path)
            self = .openFile(path: path)
        case "openURL":
            let url = try container.decode(String.self, forKey: .url)
            self = .openURL(url: url)
        case "copyText":
            let text = try container.decode(String.self, forKey: .text)
            self = .copyText(text: text)
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "Unknown action kind: \(kind)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .openFile(let path):
            try container.encode("openFile", forKey: .kind)
            try container.encode(path, forKey: .path)
        case .openURL(let url):
            try container.encode("openURL", forKey: .kind)
            try container.encode(url, forKey: .url)
        case .copyText(let text):
            try container.encode("copyText", forKey: .kind)
            try container.encode(text, forKey: .text)
        }
    }
}

// MARK: - Payloads

struct ToastPayload: Codable {
    let title: String
    let message: String
    let action: EventAction?
}

struct ResultPayload: Codable {
    let summary: String
    let artifacts: [Artifact]

    struct Artifact: Codable {
        let label: String
        let path: String
        let action: EventAction?
    }
}

struct ErrorPayload: Codable {
    let message: String
    let guidance: String?
}

// MARK: - Top-Level Event

enum MenuBotEvent: Codable {
    case toast(ToastPayload)
    case result(ResultPayload)
    case error(ErrorPayload)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        // Decode the remaining fields from the same top-level container
        let singleValue = try decoder.singleValueContainer()
        switch type {
        case "toast":
            self = .toast(try singleValue.decode(ToastPayload.self))
        case "result":
            self = .result(try singleValue.decode(ResultPayload.self))
        case "error":
            self = .error(try singleValue.decode(ErrorPayload.self))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown event type: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .toast(let payload):
            try container.encode("toast", forKey: .type)
            try payload.encode(to: encoder)
        case .result(let payload):
            try container.encode("result", forKey: .type)
            try payload.encode(to: encoder)
        case .error(let payload):
            try container.encode("error", forKey: .type)
            try payload.encode(to: encoder)
        }
    }
}

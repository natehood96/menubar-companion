import Foundation

struct Skill: Codable, Identifiable, Equatable {
    // Required fields
    let name: String
    let description: String
    let prompt: String

    // Optional fields
    let category: String?
    let tags: [String]?
    let icon: String?
    let suggestedSchedule: String?
    let requiredPermissions: [String]?
    let system: Bool?

    // Runtime properties (not from file)
    var id: String { filePath ?? name }
    var filePath: String?
    var isStarred: Bool = false

    enum CodingKeys: String, CodingKey {
        case name, description, prompt, category, tags, icon
        case suggestedSchedule = "suggested_schedule"
        case requiredPermissions = "required_permissions"
        case system
    }
}

// MARK: - Hashable (needed for NavigationStack destination)

extension Skill: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Prompt Assembly

extension Skill {
    func assemblePrompt(extraInstructions: String? = nil) -> String {
        var result = prompt
        if let extra = extraInstructions, !extra.isEmpty {
            result = result.replacingOccurrences(of: "{extra_instructions}", with: extra)
        } else {
            result = result.replacingOccurrences(of: "{extra_instructions}", with: "")
        }
        // Strip unused context variables (Phase 4 will populate these)
        result = result.replacingOccurrences(of: "{context.screenshot}", with: "")
        result = result.replacingOccurrences(of: "{context.clipboard}", with: "")
        result = result.replacingOccurrences(of: "{context.active_app}", with: "")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - File Loading

extension Skill {
    static func load(from url: URL) throws -> Skill {
        let data = try Data(contentsOf: url)
        var skill = try JSONDecoder().decode(Skill.self, from: data)
        skill.filePath = url.lastPathComponent
        return skill
    }
}

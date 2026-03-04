import Foundation

struct Skill: Identifiable, Equatable {
    // Metadata (from skill.json)
    let name: String
    let description: String
    let category: String?
    let tags: [String]?
    let icon: String?
    let suggestedSchedule: String?
    let requiredPermissions: [String]?
    let system: Bool?

    // Prompt template (from prompt.md)
    var prompt: String

    // Runtime properties
    var id: String { directoryName ?? name }
    var directoryName: String?
    var isStarred: Bool = false
}

// MARK: - JSON Metadata Decoding

struct SkillMetadata: Codable {
    let name: String
    let description: String
    let category: String?
    let tags: [String]?
    let icon: String?
    let suggestedSchedule: String?
    let requiredPermissions: [String]?
    let system: Bool?

    enum CodingKeys: String, CodingKey {
        case name, description, category, tags, icon
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

// MARK: - Directory Loading

extension Skill {
    /// Load a skill from a directory containing skill.json and prompt.md
    static func load(from directoryURL: URL) throws -> Skill {
        let metadataURL = directoryURL.appendingPathComponent("skill.json")
        let promptURL = directoryURL.appendingPathComponent("prompt.md")

        let metadataData = try Data(contentsOf: metadataURL)
        let metadata = try JSONDecoder().decode(SkillMetadata.self, from: metadataData)

        let prompt = try String(contentsOf: promptURL, encoding: .utf8)

        var skill = Skill(
            name: metadata.name,
            description: metadata.description,
            category: metadata.category,
            tags: metadata.tags,
            icon: metadata.icon,
            suggestedSchedule: metadata.suggestedSchedule,
            requiredPermissions: metadata.requiredPermissions,
            system: metadata.system,
            prompt: prompt
        )
        skill.directoryName = directoryURL.lastPathComponent
        return skill
    }
}

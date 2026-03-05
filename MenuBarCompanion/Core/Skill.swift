import Foundation

struct Skill: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let category: String?
    let icon: String?
    let file: String

    // Prompt template (from .md file)
    var prompt: String

    // Runtime
    var isStarred: Bool = false
}

// MARK: - JSON Index Entry

struct SkillIndexEntry: Codable {
    let id: String
    let name: String
    let description: String
    let icon: String?
    let category: String?
    let file: String
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
        result = result.replacingOccurrences(of: "{context.screenshot}", with: "")
        result = result.replacingOccurrences(of: "{context.clipboard}", with: "")
        result = result.replacingOccurrences(of: "{context.active_app}", with: "")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Loading from Index

extension Skill {
    /// Load a skill from an index entry, reading the prompt from the .md file in the skills directory
    static func load(from entry: SkillIndexEntry, skillsDirectory: URL) -> Skill? {
        let promptURL = skillsDirectory.appendingPathComponent(entry.file)
        guard let prompt = try? String(contentsOf: promptURL, encoding: .utf8) else {
            print("[Skill] Failed to read prompt file: \(entry.file)")
            return nil
        }

        return Skill(
            id: entry.id,
            name: entry.name,
            description: entry.description,
            category: entry.category,
            icon: entry.icon,
            file: entry.file,
            prompt: prompt
        )
    }
}

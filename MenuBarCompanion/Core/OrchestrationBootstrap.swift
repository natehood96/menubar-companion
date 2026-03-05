import Foundation

/// Installs orchestration files on every app launch.
///
/// Writes protocol/output-rules to ~/Library/Application Support/MenuBot/
/// and skill files to ~/.claude/skills/ so Claude Code can use them.
enum OrchestrationBootstrap {

    static func install() {
        let fm = FileManager.default

        // Destinations
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let menubotDir = appSupport.appendingPathComponent("MenuBot", isDirectory: true)
        let claudeSkillsDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/skills", isDirectory: true)

        // Ensure directories exist
        try? fm.createDirectory(at: menubotDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: menubotDir.appendingPathComponent("doer-logs", isDirectory: true), withIntermediateDirectories: true)
        try? fm.createDirectory(at: claudeSkillsDir, withIntermediateDirectories: true)

        // App Support files: protocol.md, output-rules.md
        writeResource("protocol", to: menubotDir.appendingPathComponent("protocol.md"))
        writeResource("output-rules", to: menubotDir.appendingPathComponent("output-rules.md"))

        // Claude skills: menubot-orchestrator, menubot-doer
        let orchestratorDir = claudeSkillsDir.appendingPathComponent("menubot-orchestrator", isDirectory: true)
        let doerDir = claudeSkillsDir.appendingPathComponent("menubot-doer", isDirectory: true)
        try? fm.createDirectory(at: orchestratorDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: doerDir, withIntermediateDirectories: true)

        writeResource("menubot-orchestrator-SKILL", to: orchestratorDir.appendingPathComponent("SKILL.md"))
        writeResource("menubot-doer-SKILL", to: doerDir.appendingPathComponent("SKILL.md"))

        print("[OrchestrationBootstrap] Installed orchestration files")
    }

    private static func writeResource(_ name: String, to destination: URL) {
        guard let sourceURL = Bundle.main.url(forResource: name, withExtension: "md") else {
            print("[OrchestrationBootstrap] Missing bundled resource: \(name).md")
            return
        }
        do {
            let content = try Data(contentsOf: sourceURL)
            try content.write(to: destination, options: .atomic)
        } catch {
            print("[OrchestrationBootstrap] Failed to write \(destination.lastPathComponent): \(error)")
        }
    }
}

import Foundation

/// Installs orchestration files and seeds default skills on every app launch.
///
/// Writes protocol/output-rules to ~/Library/Application Support/MenuBot/
/// skill files to ~/.claude/skills/ so Claude Code can use them,
/// and seeds default MenuBot skills to ~/Library/Application Support/MenuBot/skills/.
enum OrchestrationBootstrap {

    static func install() {
        let fm = FileManager.default

        // Destinations
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let menubotDir = appSupport.appendingPathComponent("MenuBot", isDirectory: true)
        let skillsDir = menubotDir.appendingPathComponent("skills", isDirectory: true)
        let claudeSkillsDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/skills", isDirectory: true)

        // Ensure directories exist
        try? fm.createDirectory(at: menubotDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: menubotDir.appendingPathComponent("doer-logs", isDirectory: true), withIntermediateDirectories: true)
        try? fm.createDirectory(at: skillsDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: claudeSkillsDir, withIntermediateDirectories: true)

        // App Support files: protocol.md, output-rules.md
        writeResource("protocol", ext: "md", to: menubotDir.appendingPathComponent("protocol.md"))
        writeResource("output-rules", ext: "md", to: menubotDir.appendingPathComponent("output-rules.md"))

        // Claude skills: menubot-orchestrator, menubot-doer
        let orchestratorDir = claudeSkillsDir.appendingPathComponent("menubot-orchestrator", isDirectory: true)
        let doerDir = claudeSkillsDir.appendingPathComponent("menubot-doer", isDirectory: true)
        try? fm.createDirectory(at: orchestratorDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: doerDir, withIntermediateDirectories: true)

        writeResource("menubot-orchestrator-SKILL", ext: "md", to: orchestratorDir.appendingPathComponent("SKILL.md"))
        writeResource("menubot-doer-SKILL", ext: "md", to: doerDir.appendingPathComponent("SKILL.md"))

        // Seed default MenuBot skills (index + .md files)
        seedDefaultSkills(to: skillsDir)

        // Clean up old subdirectory-based skills
        cleanupLegacySkills(in: skillsDir)

        // Register Playwright MCP server so doers get browser_* tools
        registerPlaywrightMCP()

        print("[OrchestrationBootstrap] Installed orchestration files and seeded skills")
    }

    // MARK: - Skill Seeding

    private static func seedDefaultSkills(to skillsDir: URL) {
        // Always overwrite the index with defaults + any user additions
        let indexURL = skillsDir.appendingPathComponent("skills-index.json")

        // Seed the default skill .md files (always overwrite so bundle updates propagate)
        let defaultSkillFiles = ["browse-web", "create-skill", "summarize-clipboard"]
        for skillFile in defaultSkillFiles {
            let destURL = skillsDir.appendingPathComponent("\(skillFile).md")
            writeResource(skillFile, ext: "md", to: destURL, subdirectory: "skills")
        }

        // Seed the index: merge defaults with any user-added entries
        let defaultEntries = loadDefaultIndexEntries()
        let existingEntries = loadExistingIndexEntries(from: indexURL)

        // Keep user entries that aren't in the defaults
        let defaultIDs = Set(defaultEntries.map(\.id))
        let userEntries = existingEntries.filter { !defaultIDs.contains($0.id) }
        let mergedEntries = defaultEntries + userEntries

        if let data = try? JSONEncoder.prettyEncoder.encode(mergedEntries) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }

    private static func loadDefaultIndexEntries() -> [SkillIndexEntry] {
        guard let url = Bundle.main.url(forResource: "skills-index", withExtension: "json", subdirectory: "skills") else {
            print("[OrchestrationBootstrap] Missing bundled skills-index.json")
            return []
        }
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([SkillIndexEntry].self, from: data) else {
            return []
        }
        return entries
    }

    private static func loadExistingIndexEntries(from url: URL) -> [SkillIndexEntry] {
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([SkillIndexEntry].self, from: data) else {
            return []
        }
        return entries
    }

    // MARK: - Legacy Cleanup

    private static func cleanupLegacySkills(in skillsDir: URL) {
        let fm = FileManager.default
        let legacyDirs = ["bridge-skill", "sample-skill", "test-skill"]
        for dir in legacyDirs {
            let dirURL = skillsDir.appendingPathComponent(dir)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: dirURL.path, isDirectory: &isDir), isDir.boolValue {
                try? fm.removeItem(at: dirURL)
            }
        }
    }

    // MARK: - Playwright MCP Registration

    private static func registerPlaywrightMCP() {
        // Find the claude binary
        let candidates = [
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".local/bin/claude").path,
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude"
        ]
        guard let claudePath = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            print("[OrchestrationBootstrap] claude binary not found, skipping MCP registration")
            return
        }

        // Find npx — must use full path because GUI apps don't inherit shell PATH (nvm, etc.)
        let npxCandidates = [
            // nvm (most common)
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".nvm/versions/node").path,
            // Homebrew
            "/opt/homebrew/bin/npx",
            "/usr/local/bin/npx",
            // System
            "/usr/bin/npx"
        ]
        let npxPath: String? = {
            // Check nvm first — find the latest installed version
            let nvmBase = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".nvm/versions/node")
            if let versions = try? FileManager.default.contentsOfDirectory(atPath: nvmBase.path),
               !versions.isEmpty {
                let sorted = versions.sorted { $0.compare($1, options: .numeric) > .orderedSame }
                for version in sorted {
                    let candidate = nvmBase
                        .appendingPathComponent(version)
                        .appendingPathComponent("bin/npx").path
                    if FileManager.default.isExecutableFile(atPath: candidate) {
                        return candidate
                    }
                }
            }
            // Fall back to known paths
            for candidate in ["/opt/homebrew/bin/npx", "/usr/local/bin/npx", "/usr/bin/npx"] {
                if FileManager.default.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
            return nil
        }()

        guard let npxPath else {
            // npx not found — try to install Node.js via Homebrew
            print("[OrchestrationBootstrap] npx not found, attempting to install Node.js")
            if let installedNpx = installNodeAndReturnNpxPath() {
                registerPlaywrightMCPWithNpx(installedNpx, claudePath: claudePath)
            } else {
                print("[OrchestrationBootstrap] Could not install Node.js — skipping Playwright MCP registration")
            }
            return
        }
        print("[OrchestrationBootstrap] Found npx at: \(npxPath)")
        registerPlaywrightMCPWithNpx(npxPath, claudePath: claudePath)
    }

    private static func registerPlaywrightMCPWithNpx(_ npxPath: String, claudePath: String) {
        // Check if already registered by looking for playwright in mcp list
        let checkProcess = Process()
        let checkPipe = Pipe()
        checkProcess.executableURL = URL(fileURLWithPath: claudePath)
        checkProcess.arguments = ["mcp", "list"]
        checkProcess.standardOutput = checkPipe
        checkProcess.standardError = Pipe()
        do {
            try checkProcess.run()
            checkProcess.waitUntilExit()
            let output = String(data: checkPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            if output.contains("playwright") {
                print("[OrchestrationBootstrap] Playwright MCP already registered")
                return
            }
        } catch {
            print("[OrchestrationBootstrap] Could not check MCP list: \(error)")
        }

        // Register the Playwright MCP server with Brave as the browser
        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.arguments = [
            "mcp", "add",
            "--scope", "user",
            "playwright",
            "--",
            npxPath, "@playwright/mcp@latest",
            "--browser", "chromium",
            "--executable-path", "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
        ]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                print("[OrchestrationBootstrap] Registered Playwright MCP server with Brave")
            } else {
                let stderr = String(data: (process.standardError as! Pipe).fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                print("[OrchestrationBootstrap] Failed to register Playwright MCP: \(stderr)")
            }
        } catch {
            print("[OrchestrationBootstrap] Failed to run claude mcp add: \(error)")
        }
    }

    private static func installNodeAndReturnNpxPath() -> String? {
        // Try Homebrew first
        let brewCandidates = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        guard let brewPath = brewCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            print("[OrchestrationBootstrap] Homebrew not found — cannot auto-install Node.js")
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = ["install", "node"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                print("[OrchestrationBootstrap] brew install node failed")
                return nil
            }
        } catch {
            print("[OrchestrationBootstrap] Failed to run brew install node: \(error)")
            return nil
        }

        // After install, npx should be at the Homebrew prefix
        let homebrewNpx = URL(fileURLWithPath: brewPath)
            .deletingLastPathComponent()
            .appendingPathComponent("npx").path
        if FileManager.default.isExecutableFile(atPath: homebrewNpx) {
            print("[OrchestrationBootstrap] Installed Node.js via Homebrew, npx at: \(homebrewNpx)")
            return homebrewNpx
        }

        // Also check the common Homebrew paths
        for candidate in ["/opt/homebrew/bin/npx", "/usr/local/bin/npx"] {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                print("[OrchestrationBootstrap] Installed Node.js via Homebrew, npx at: \(candidate)")
                return candidate
            }
        }

        print("[OrchestrationBootstrap] Node.js installed but npx not found at expected paths")
        return nil
    }

    // MARK: - Helpers

    private static func writeResource(_ name: String, ext: String, to destination: URL, subdirectory: String? = nil) {
        let sourceURL: URL?
        if let subdirectory {
            sourceURL = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdirectory)
        } else {
            sourceURL = Bundle.main.url(forResource: name, withExtension: ext)
        }
        guard let sourceURL else {
            print("[OrchestrationBootstrap] Missing bundled resource: \(name).\(ext)")
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

// MARK: - JSONEncoder Extension

private extension JSONEncoder {
    static let prettyEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}

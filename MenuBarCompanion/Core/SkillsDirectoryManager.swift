import Foundation
import Combine

@MainActor
class SkillsDirectoryManager: ObservableObject {
    @Published var skills: [Skill] = []

    static let skillsDirectoryURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("MenuBot/skills", isDirectory: true)
    }()

    private var directorySource: DispatchSourceFileSystemObject?
    private var directoryFD: Int32 = -1

    init() {
        ensureDirectoryExists()
        cleanupLegacyFiles()
        ensureBridgeSkillExists()
        ensureSampleSkillExists()
        scan()
        startWatching()
    }

    deinit {
        directorySource?.cancel()
        directorySource = nil
    }

    // MARK: - Public

    func rescanIfNeeded() {
        scan()
    }

    func scan() {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: Self.skillsDirectoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            skills = []
            return
        }

        let parsed = contents
            .filter { url in
                var isDir: ObjCBool = false
                fm.fileExists(atPath: url.path, isDirectory: &isDir)
                return isDir.boolValue
            }
            .compactMap { dirURL -> Skill? in
                do {
                    return try Skill.load(from: dirURL)
                } catch {
                    print("[SkillsDirectoryManager] Failed to load skill from \(dirURL.lastPathComponent): \(error)")
                    return nil
                }
            }
            .filter { $0.system != true }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        self.skills = parsed
    }

    // MARK: - Private

    private func ensureDirectoryExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: Self.skillsDirectoryURL.path) {
            try? fm.createDirectory(at: Self.skillsDirectoryURL, withIntermediateDirectories: true)
        }
    }

    private func cleanupLegacyFiles() {
        let legacyBridge = Self.skillsDirectoryURL.appendingPathComponent("bridge-skill.json")
        let legacySample = Self.skillsDirectoryURL.appendingPathComponent("sample-skill.json")
        let fm = FileManager.default
        if fm.fileExists(atPath: legacyBridge.path) {
            try? fm.removeItem(at: legacyBridge)
        }
        if fm.fileExists(atPath: legacySample.path) {
            try? fm.removeItem(at: legacySample)
        }
    }

    private func ensureBridgeSkillExists() {
        let bridgeDirURL = Self.skillsDirectoryURL.appendingPathComponent("bridge-skill")
        let fm = FileManager.default
        guard !fm.fileExists(atPath: bridgeDirURL.path) else { return }
        if let bundledURL = Bundle.main.url(forResource: "bridge-skill", withExtension: nil) {
            do {
                try fm.copyItem(at: bundledURL, to: bridgeDirURL)
            } catch {
                print("[SkillsDirectoryManager] Failed to copy bridge skill: \(error)")
            }
        }
    }

    private func ensureSampleSkillExists() {
        let sampleDirURL = Self.skillsDirectoryURL.appendingPathComponent("sample-skill")
        let fm = FileManager.default
        guard !fm.fileExists(atPath: sampleDirURL.path) else { return }
        if let bundledURL = Bundle.main.url(forResource: "sample-skill", withExtension: nil) {
            try? fm.copyItem(at: bundledURL, to: sampleDirURL)
        }
    }

    private func startWatching() {
        let path = Self.skillsDirectoryURL.path
        directoryFD = open(path, O_EVTONLY)
        guard directoryFD >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: directoryFD,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.scan()
        }
        source.setCancelHandler { [weak self] in
            if let fd = self?.directoryFD, fd >= 0 {
                close(fd)
            }
        }
        source.resume()
        directorySource = source
    }

    private func stopWatching() {
        directorySource?.cancel()
        directorySource = nil
    }
}

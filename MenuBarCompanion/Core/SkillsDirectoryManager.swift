import Foundation
import Combine

@MainActor
class SkillsDirectoryManager: ObservableObject {
    @Published var skills: [Skill] = []

    static let skillsDirectoryURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("MenuBot/skills", isDirectory: true)
    }()

    static var indexFileURL: URL {
        skillsDirectoryURL.appendingPathComponent("skills-index.json")
    }

    private var fileSource: DispatchSourceFileSystemObject?
    private var fileFD: Int32 = -1

    init() {
        ensureDirectoryExists()
        scan()
        startWatching()
    }

    deinit {
        fileSource?.cancel()
        fileSource = nil
    }

    // MARK: - Public

    func rescanIfNeeded() {
        scan()
    }

    func scan() {
        let indexURL = Self.indexFileURL
        guard let data = try? Data(contentsOf: indexURL) else {
            print("[SkillsDirectoryManager] No skills-index.json found")
            skills = []
            return
        }

        guard let entries = try? JSONDecoder().decode([SkillIndexEntry].self, from: data) else {
            print("[SkillsDirectoryManager] Failed to decode skills-index.json")
            skills = []
            return
        }

        let parsed = entries.compactMap { entry in
            Skill.load(from: entry, skillsDirectory: Self.skillsDirectoryURL)
        }

        self.skills = parsed
    }

    // MARK: - Private

    private func ensureDirectoryExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: Self.skillsDirectoryURL.path) {
            try? fm.createDirectory(at: Self.skillsDirectoryURL, withIntermediateDirectories: true)
        }
    }

    private func startWatching() {
        // Watch the skills directory for changes to skills-index.json or any .md files
        let path = Self.skillsDirectoryURL.path
        fileFD = open(path, O_EVTONLY)
        guard fileFD >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileFD,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.scan()
        }
        source.setCancelHandler { [weak self] in
            if let fd = self?.fileFD, fd >= 0 {
                close(fd)
            }
        }
        source.resume()
        fileSource = source
    }
}

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
        ensureBridgeSkillExists()
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
        guard let files = try? fm.contentsOfDirectory(
            at: Self.skillsDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            skills = []
            return
        }

        let parsed = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> Skill? in
                do {
                    return try Skill.load(from: url)
                } catch {
                    print("[SkillsDirectoryManager] Failed to parse \(url.lastPathComponent): \(error)")
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

    private func ensureBridgeSkillExists() {
        let bridgeURL = Self.skillsDirectoryURL.appendingPathComponent("bridge-skill.json")
        guard !FileManager.default.fileExists(atPath: bridgeURL.path) else { return }
        if let bundledURL = Bundle.main.url(forResource: "bridge-skill", withExtension: "json") {
            try? FileManager.default.copyItem(at: bundledURL, to: bridgeURL)
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

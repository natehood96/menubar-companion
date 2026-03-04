import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isRunning: Bool = false
    @Published var claudeDetected: Bool = false
    @Published var allSkills: [Skill] = []
    @Published var starredSkillIDs: Set<String> = []

    private var runner: CommandRunner?
    private let notificationManager: NotificationManager
    private let skillsManager: SkillsDirectoryManager
    private var cancellables = Set<AnyCancellable>()

    init(notificationManager: NotificationManager) {
        self.notificationManager = notificationManager
        self.skillsManager = SkillsDirectoryManager()
        self.messages = ChatStore.load()
        detectClaude()
        skillsManager.$skills
            .receive(on: RunLoop.main)
            .assign(to: &$allSkills)
    }

    // MARK: - Skills

    var starredSkills: [Skill] {
        allSkills.filter { starredSkillIDs.contains($0.id) }
    }

    func isStarred(_ skill: Skill) -> Bool {
        starredSkillIDs.contains(skill.id)
    }

    func toggleStar(_ skill: Skill) {
        if starredSkillIDs.contains(skill.id) {
            starredSkillIDs.remove(skill.id)
        } else {
            starredSkillIDs.insert(skill.id)
        }
    }

    func runSkill(_ skill: Skill, extraInstructions: String? = nil) {
        let assembledPrompt = skill.assemblePrompt(extraInstructions: extraInstructions)
        inputText = assembledPrompt
        sendMessage()
    }

    func rescanSkills() {
        skillsManager.rescanIfNeeded()
    }

    // MARK: - Chat

    func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isRunning else { return }

        // Add user message
        let userMessage = ChatMessage(role: .user, content: trimmed)
        messages.append(userMessage)
        inputText = ""

        // Start streaming assistant response
        let assistantMessage = ChatMessage(role: .assistant, content: "", isStreaming: true)
        messages.append(assistantMessage)
        isRunning = true

        let command = buildCommand(for: trimmed)

        runner = CommandRunner(
            command: command.executable,
            arguments: command.arguments
        )

        runner?.start(
            onOutput: { [weak self] line in
                Task { @MainActor in
                    self?.handleOutputLine(line)
                }
            },
            onComplete: { [weak self] exitCode in
                Task { @MainActor in
                    self?.finishRun(exitCode: exitCode)
                }
            }
        )
    }

    func cancel() {
        runner?.cancel()
        isRunning = false
        if var last = messages.last, last.role == .assistant {
            last.isStreaming = false
            if last.content.isEmpty {
                last.content = "[cancelled]"
            } else {
                last.content += "\n[cancelled]"
            }
            messages[messages.count - 1] = last
        }
        ChatStore.save(messages)
    }

    func clearHistory() {
        messages = []
        ChatStore.save(messages)
    }

    // MARK: - Command Building

    private func buildCommand(for input: String) -> (executable: String, arguments: [String]) {
        return ("/bin/sh", ["-c", input])
    }

    // MARK: - Claude Detection

    private func detectClaude() {
        Task.detached {
            let detected = await Self.checkClaudeCLI()
            await MainActor.run {
                self.claudeDetected = detected
            }
        }
    }

    private static func checkClaudeCLI() async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["claude"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - Event Handling

    private func handleOutputLine(_ line: String) {
        if let json = EventParser.extractPayload(from: line) {
            if let event = EventParser.parseEvent(from: json) {
                notificationManager.handle(event)
            }
            return
        }

        // Append to the current assistant message
        guard !messages.isEmpty, messages[messages.count - 1].role == .assistant else { return }
        if messages[messages.count - 1].content.isEmpty {
            messages[messages.count - 1].content = line
        } else {
            messages[messages.count - 1].content += "\n" + line
        }
    }

    private func finishRun(exitCode: Int32) {
        isRunning = false
        if !messages.isEmpty, messages[messages.count - 1].role == .assistant {
            messages[messages.count - 1].isStreaming = false
            if messages[messages.count - 1].content.isEmpty {
                messages[messages.count - 1].content = "[completed with code \(exitCode)]"
            }
        }
        ChatStore.save(messages)
    }
}

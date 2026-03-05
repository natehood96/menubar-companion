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
    private var claudePath: String?

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
        if let claudePath {
            return (claudePath, [
                "--dangerously-skip-permissions",
                "--permission-mode", "bypassPermissions",
                "--output-format", "stream-json",
                "--verbose",
                "-p", "/menubot-orchestrator The claude binary is at: \(claudePath). Use this full path when launching doers. \(input)"
            ])
        }
        return ("/bin/sh", ["-c", input])
    }

    // MARK: - Claude Detection

    private func detectClaude() {
        print("[ChatViewModel] detectClaude() called")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let path = ClaudeDetector.resolve()
            print("[ChatViewModel] ClaudeDetector returned: \(path ?? "nil")")
            DispatchQueue.main.async {
                self?.claudePath = path
                self?.claudeDetected = path != nil
                print("[ChatViewModel] claudeDetected = \(path != nil)")
            }
        }
    }

    // MARK: - Event Handling

    private func handleOutputLine(_ line: String) {
        print("[Output] \(line)")

        // When Claude CLI is active, output is NDJSON (stream-json format)
        if claudePath != nil {
            handleStreamJsonLine(line)
            return
        }

        // Fallback: plain text mode (shell commands)
        if let json = EventParser.extractPayload(from: line) {
            if let event = EventParser.parseEvent(from: json) {
                notificationManager.handle(event)
            }
            return
        }

        appendToAssistantMessage(line)
    }

    private func handleStreamJsonLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let event = StreamJsonParser.parse(line: trimmed)

        switch event {
        case .assistantText(let text):
            appendToAssistantMessage(text)
        case .assistantDelta(let text):
            streamDeltaToAssistantMessage(text)
        case .toolUse(let name):
            appendToAssistantMessage("[using \(name)...]")
        case .toolResult(let output):
            // Check for MenuBot events inside tool output
            for resultLine in output.components(separatedBy: "\n") {
                if let payload = EventParser.extractPayload(from: resultLine),
                   let event = EventParser.parseEvent(from: payload) {
                    notificationManager.handle(event)
                }
            }
        case .menubotEvent(let payload):
            if let event = EventParser.parseEvent(from: payload) {
                notificationManager.handle(event)
            }
        case .done:
            break // finishRun handles completion
        case .ignored:
            // Show non-JSON lines (likely stderr error messages) to the user
            if !trimmed.starts(with: "{") {
                appendToAssistantMessage(trimmed)
            }
        }
    }

    private func streamDeltaToAssistantMessage(_ text: String) {
        guard !messages.isEmpty, messages[messages.count - 1].role == .assistant else { return }
        messages[messages.count - 1].content += text
    }

    private func appendToAssistantMessage(_ text: String) {
        guard !messages.isEmpty, messages[messages.count - 1].role == .assistant else { return }
        if messages[messages.count - 1].content.isEmpty {
            messages[messages.count - 1].content = text
        } else {
            messages[messages.count - 1].content += "\n" + text
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

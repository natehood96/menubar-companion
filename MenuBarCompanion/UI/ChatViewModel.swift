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

    // MARK: - [SAY] Filtering

    /// Line buffer for streaming deltas — accumulates characters until we can
    /// determine whether a line starts with "[SAY] " (user-facing) or not (internal).
    private var lineBuffer = ""
    /// Whether the current line being streamed has been confirmed as user-facing.
    private var currentLineIsUserFacing = false
    /// The prefix that marks a line as user-facing output.
    private static let sayPrefix = "[SAY] "

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

        // Reset [SAY] filter state for new run
        lineBuffer = ""
        currentLineIsUserFacing = false

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

        // Fallback: plain text mode (shell commands) — no [SAY] filtering
        if let json = EventParser.extractPayload(from: line) {
            if let event = EventParser.parseEvent(from: json) {
                notificationManager.handle(event)
            }
            return
        }

        // In non-Claude mode, show all output directly (no filtering)
        guard !messages.isEmpty, messages[messages.count - 1].role == .assistant else { return }
        if messages[messages.count - 1].content.isEmpty {
            messages[messages.count - 1].content = line
        } else {
            messages[messages.count - 1].content += "\n" + line
        }
    }

    private func handleStreamJsonLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let event = StreamJsonParser.parse(line: trimmed)

        switch event {
        case .assistantText(let text):
            appendFilteredAssistantText(text)
        case .assistantDelta(let text):
            streamFilteredDelta(text)
        case .toolUse:
            // Internal — don't show tool names to the user
            break
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
            // Don't show raw stderr/non-JSON lines — they're internal
            break
        }
    }

    // MARK: - [SAY] Filtered Output

    /// Process streaming deltas through the [SAY] filter.
    /// Buffers characters line-by-line. Only lines starting with "[SAY] " are displayed.
    private func streamFilteredDelta(_ text: String) {
        guard !messages.isEmpty, messages[messages.count - 1].role == .assistant else { return }

        for char in text {
            if char == "\n" {
                // Line complete
                if currentLineIsUserFacing {
                    // Add a newline to separate from the next [SAY] line
                    messages[messages.count - 1].content += "\n"
                }
                lineBuffer = ""
                currentLineIsUserFacing = false
            } else {
                lineBuffer.append(char)

                if currentLineIsUserFacing {
                    // Already confirmed user-facing — stream directly to UI
                    messages[messages.count - 1].content += String(char)
                } else {
                    // Still checking if this line starts with [SAY]
                    let prefix = Self.sayPrefix
                    if lineBuffer.count < prefix.count {
                        // Too short to decide — check if it could still match
                        if !prefix.hasPrefix(lineBuffer) {
                            // Can't possibly be [SAY], skip rest of line
                            // currentLineIsUserFacing stays false
                        }
                    } else if lineBuffer.count == prefix.count {
                        if lineBuffer == prefix {
                            // Confirmed [SAY] line — start streaming (prefix itself is not shown)
                            currentLineIsUserFacing = true
                        }
                    }
                    // If count > prefix.count and not user-facing, silently skip
                }
            }
        }
    }

    /// Filter a complete assistant text block through [SAY]. Only [SAY]-prefixed lines are shown.
    private func appendFilteredAssistantText(_ text: String) {
        guard !messages.isEmpty, messages[messages.count - 1].role == .assistant else { return }

        let lines = text.components(separatedBy: "\n")
        let userFacingLines = lines.compactMap { line -> String? in
            if line.hasPrefix(Self.sayPrefix) {
                return String(line.dropFirst(Self.sayPrefix.count))
            }
            return nil
        }

        guard !userFacingLines.isEmpty else { return }
        let filtered = userFacingLines.joined(separator: "\n")

        if messages[messages.count - 1].content.isEmpty {
            messages[messages.count - 1].content = filtered
        } else {
            messages[messages.count - 1].content += "\n" + filtered
        }
    }

    private func finishRun(exitCode: Int32) {
        isRunning = false

        // Flush any remaining buffered [SAY] content
        if currentLineIsUserFacing && !lineBuffer.isEmpty {
            if !messages.isEmpty, messages[messages.count - 1].role == .assistant {
                // lineBuffer still has the prefix stripped (we streamed chars after [SAY] )
                // Nothing to flush — chars were streamed live. Just clean up state.
            }
        }
        lineBuffer = ""
        currentLineIsUserFacing = false

        if !messages.isEmpty, messages[messages.count - 1].role == .assistant {
            messages[messages.count - 1].isStreaming = false
            // Trim trailing newlines from [SAY] line breaks
            messages[messages.count - 1].content = messages[messages.count - 1].content
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if messages[messages.count - 1].content.isEmpty {
                messages[messages.count - 1].content = exitCode == 0 ? "[done]" : "[error — exit code \(exitCode)]"
            }
        }
        ChatStore.save(messages)
    }
}

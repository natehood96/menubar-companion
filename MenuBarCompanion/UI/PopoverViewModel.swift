import Foundation

@MainActor
final class PopoverViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var output: String = ""
    @Published var isRunning: Bool = false
    @Published var claudeDetected: Bool = false

    private var runner: CommandRunner?
    private let notificationManager: NotificationManager

    init(notificationManager: NotificationManager) {
        self.notificationManager = notificationManager
        detectClaude()
    }

    func run() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isRunning else { return }

        output = ""
        isRunning = true

        // Build the command — swap this to Claude CLI later
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
                    self?.isRunning = false
                    self?.output += "\n[exited with code \(exitCode)]"
                }
            }
        )
    }

    func cancel() {
        runner?.cancel()
        isRunning = false
        output += "\n[cancelled]"
    }

    func clearOutput() {
        output = ""
    }

    // MARK: - Command Building

    /// Single place to swap in Claude CLI invocation later.
    private func buildCommand(for input: String) -> (executable: String, arguments: [String]) {
        // TODO: When Claude CLI is available, return something like:
        // ("/usr/local/bin/claude", ["--output-format", "stream-json", input])
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
        output += line + "\n"
    }
}

import Foundation

/// Runs an external process and streams stdout/stderr line-by-line.
///
/// Usage:
///   let runner = CommandRunner(command: "/bin/echo", arguments: ["hello"])
///   runner.start(onOutput: { line in … }, onComplete: { code in … })
///   runner.cancel()
final class CommandRunner {
    private let process = Process()
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()
    private var onOutput: ((String) -> Void)?
    private var onComplete: ((Int32) -> Void)?

    init(command: String, arguments: [String] = []) {
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
    }

    /// Start the process. Callbacks may be invoked from background threads.
    func start(
        onOutput: @escaping (String) -> Void,
        onComplete: @escaping (Int32) -> Void
    ) {
        self.onOutput = onOutput
        self.onComplete = onComplete

        streamHandle(stdoutPipe.fileHandleForReading)
        streamHandle(stderrPipe.fileHandleForReading)

        process.terminationHandler = { [weak self] proc in
            self?.onComplete?(proc.terminationStatus)
        }

        do {
            try process.run()
        } catch {
            onOutput("[error: \(error.localizedDescription)]")
            onComplete(1)
        }
    }

    /// Terminate the running process.
    func cancel() {
        guard process.isRunning else { return }
        process.terminate()
    }

    // MARK: - Private

    private func streamHandle(_ handle: FileHandle) {
        handle.readabilityHandler = { [weak self] fh in
            let data = fh.availableData
            guard !data.isEmpty else {
                fh.readabilityHandler = nil
                return
            }
            if let text = String(data: data, encoding: .utf8) {
                // Split into lines, emit each
                let lines = text.components(separatedBy: "\n")
                for (i, line) in lines.enumerated() {
                    // Skip trailing empty string from split
                    if i == lines.count - 1 && line.isEmpty { continue }
                    self?.onOutput?(line)
                }
            }
        }
    }
}

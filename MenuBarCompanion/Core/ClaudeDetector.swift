import Foundation

/// Resolves the Claude CLI path by launching a login shell to pick up the user's full PATH.
/// This is NOT @MainActor so it can safely run on background threads.
enum ClaudeDetector {
    /// Returns the full path to the `claude` binary, or nil if not found.
    static func resolve() -> String? {
        // Use -l (login) AND -i (interactive) so both .zprofile and .zshrc are sourced.
        // This ensures we pick up PATH modifications regardless of which config file sets them.
        let process = Process()
        let pipe = Pipe()
        let errPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lic", "which claude"]
        process.standardOutput = pipe
        process.standardError = errPipe

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            let status = process.terminationStatus
            print("[ClaudeDetector] exit status: \(status)")

            guard status == 0 else {
                print("[ClaudeDetector] which claude failed with status \(status)")
                return nil
            }

            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let path, !path.isEmpty else {
                print("[ClaudeDetector] empty path returned")
                return nil
            }

            let exists = FileManager.default.isExecutableFile(atPath: path)
            print("[ClaudeDetector] found: \(path), executable: \(exists)")

            guard exists else { return nil }
            return path
        } catch {
            print("[ClaudeDetector] error: \(error)")
            return nil
        }
    }
}

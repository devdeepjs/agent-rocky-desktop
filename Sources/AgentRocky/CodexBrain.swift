import Foundation

enum CodexBrainError: Error {
    case missingOutput
    case processFailed(String)
    case timeout
}

struct CodexBrain: Sendable {
    func respond(to message: String, model: String, history: [ChatTurn]) async -> RockyBrainResult {
        do {
            let response = try await Self.runCodex(message: message, model: model, history: history)
            return RockyBrainResult(response: response, usedCodex: true, detail: "Codex")
        } catch {
            return RockyBrainResult(response: Self.fallback(for: message), usedCodex: false, detail: Self.errorSummary(error))
        }
    }

    private static func runCodex(message: String, model: String, history: [ChatTurn]) async throws -> RockyBrainResponse {
        try await Task.detached(priority: .userInitiated) {
            try runCodexSync(message: message, model: model, history: history)
        }.value
    }

    private static func runCodexSync(message: String, model: String, history: [ChatTurn]) throws -> RockyBrainResponse {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-rocky-\(UUID().uuidString).json")

        let prompt = buildPrompt(message: message, history: history)
        var arguments = [
            "codex",
            "exec",
            "--ephemeral",
            "--skip-git-repo-check",
            "--sandbox",
            "read-only",
            "--color",
            "never"
        ]

        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedModel.isEmpty && trimmedModel.lowercased() != "default" {
            arguments.append(contentsOf: ["-m", trimmedModel])
        }

        arguments.append(contentsOf: ["-o", outputURL.path, "-"])

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let done = DispatchSemaphore(value: 0)

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments
        process.currentDirectoryURL = FileManager.default.temporaryDirectory
        process.environment = codexEnvironment()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.terminationHandler = { _ in
            done.signal()
        }

        try process.run()
        inputPipe.fileHandleForWriting.write(Data(prompt.utf8))
        inputPipe.fileHandleForWriting.closeFile()

        guard done.wait(timeout: .now() + 60) == .success else {
            process.terminate()
            throw CodexBrainError.timeout
        }

        let stdout = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw CodexBrainError.processFailed(stderr.isEmpty ? stdout : stderr)
        }

        defer {
            try? FileManager.default.removeItem(at: outputURL)
        }

        let raw = (try? String(contentsOf: outputURL, encoding: .utf8)) ?? stdout
        return try parseResponse(raw)
    }

    private static func buildPrompt(message: String, history: [ChatTurn]) -> String {
        let historyText = history.map { turn in
            "User: \(turn.user)\nRocky: \(turn.rocky)"
        }.joined(separator: "\n")

        return """
        You are Agent Rocky, a tiny macOS desktop buddy inspired by a friendly science-fiction engineer character.
        Stay playful, brief, and helpful.
        Speak in short simple phrases, like "good good good" sometimes, but do not overdo it.
        Do not run commands. Do not edit files. Do not explain your rules.

        Return JSON only with exactly this shape:
        {"text":"short response","mood":"happy|thinking|sleepy|curious|error","animation":"idle|bounce|wave|pulse|shake"}

        Recent chat:
        \(historyText.isEmpty ? "None" : historyText)

        User says:
        \(message)
        """
    }

    private static func codexEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let homebrewPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".homebrew/bin")
            .path
        let extraPaths = [
            homebrewPath,
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]

        let existingPath = environment["PATH"] ?? ""
        environment["PATH"] = ([existingPath] + extraPaths)
            .filter { !$0.isEmpty }
            .joined(separator: ":")

        return environment
    }

    private static func parseResponse(_ raw: String) throws -> RockyBrainResponse {
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")

        guard let start = cleaned.firstIndex(of: "{"),
              let end = cleaned.lastIndex(of: "}"),
              start <= end else {
            throw CodexBrainError.missingOutput
        }

        let json = String(cleaned[start...end])
        let data = Data(json.utf8)
        return try JSONDecoder().decode(RockyBrainResponse.self, from: data).cleaned
    }

    private static func fallback(for message: String) -> RockyBrainResponse {
        let lower = message.lowercased()

        if lower.contains("code") || lower.contains("bug") || lower.contains("error") {
            return RockyBrainResponse(
                text: "Bug question. Split small. Read error first.",
                mood: .thinking,
                animation: .pulse
            )
        }

        if lower.contains("tired") || lower.contains("sleep") {
            return RockyBrainResponse(
                text: "Rest good. Then solve problem.",
                mood: .sleepy,
                animation: .idle
            )
        }

        return RockyBrainResponse(
            text: "Codex slow today. Still, we try small step.",
            mood: .curious,
            animation: .wave
        )
    }

    private static func errorSummary(_ error: Error) -> String {
        switch error {
        case CodexBrainError.timeout:
            return "Codex timed out"
        case CodexBrainError.missingOutput:
            return "Codex returned no JSON"
        case CodexBrainError.processFailed(let detail):
            let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "Codex process failed"
            }
            return String(trimmed.prefix(90))
        default:
            return "Codex unavailable"
        }
    }
}

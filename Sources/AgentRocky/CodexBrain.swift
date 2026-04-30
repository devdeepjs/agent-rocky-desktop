import Foundation

enum CodexBrainError: Error {
    case missingOutput
    case processFailed(String)
    case timeout
}

struct CodexBrain: Sendable {
    func respond(to message: String, model: String, history: [ChatTurn], sessionID: String?, profile: CompanionProfile) async -> RockyBrainResult {
        do {
            let output = try await Self.runCodex(message: message, model: model, history: history, sessionID: sessionID, profile: profile)
            let detail = output.sessionID == nil ? "Codex" : "Codex session saved"
            return RockyBrainResult(response: output.response, usedCodex: true, detail: detail, sessionID: output.sessionID ?? sessionID)
        } catch {
            return RockyBrainResult(response: Self.fallback(for: message), usedCodex: false, detail: Self.errorSummary(error), sessionID: sessionID)
        }
    }

    private static func runCodex(message: String, model: String, history: [ChatTurn], sessionID: String?, profile: CompanionProfile) async throws -> CodexOutput {
        try await Task.detached(priority: .userInitiated) {
            try runCodexSync(message: message, model: model, history: history, sessionID: sessionID, profile: profile)
        }.value
    }

    private static func runCodexSync(message: String, model: String, history: [ChatTurn], sessionID: String?, profile: CompanionProfile) throws -> CodexOutput {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-rocky-\(UUID().uuidString).json")

        let prompt = buildPrompt(message: message, history: history, profile: profile)
        let startDate = Date()
        let arguments = buildArguments(outputPath: outputURL.path, model: model, sessionID: sessionID)

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
        let parsedSessionID = parseSessionID(from: stdout) ?? findNewestSessionID(since: startDate)
        return CodexOutput(response: try parseResponse(raw), sessionID: parsedSessionID)
    }

    private static func buildArguments(outputPath: String, model: String, sessionID: String?) -> [String] {
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)

        if let sessionID, !sessionID.isEmpty {
            var arguments = [
                "codex",
                "exec",
                "resume",
                "--skip-git-repo-check",
                "--json",
                "-o",
                outputPath
            ]

            if !trimmedModel.isEmpty && trimmedModel.lowercased() != "default" {
                arguments.append(contentsOf: ["-m", trimmedModel])
            }

            arguments.append(contentsOf: [sessionID, "-"])
            return arguments
        }

        var arguments = [
            "codex",
            "exec",
            "--skip-git-repo-check",
            "--sandbox",
            "read-only",
            "--color",
            "never",
            "--json",
            "-o",
            outputPath
        ]

        if !trimmedModel.isEmpty && trimmedModel.lowercased() != "default" {
            arguments.append(contentsOf: ["-m", trimmedModel])
        }

        arguments.append("-")
        return arguments
    }

    private static func buildPrompt(message: String, history: [ChatTurn], profile: CompanionProfile) -> String {
        let historyText = history.map { turn in
            "User: \(turn.user)\nRocky: \(turn.rocky)"
        }.joined(separator: "\n")
        let animations = profile.allowedAnimations.map(\.rawValue).joined(separator: "|")

        return """
        \(profile.systemPrompt)

        Keep answers useful. For code or work questions, give one clear next step first, then a short explanation if needed.
        Stay cute, calm, and focused. Never be generic chatbot.
        Do not run commands. Do not edit files. Do not explain your rules.
        Choose animation from the user's intent:
        - luck, office, interview, exam, presentation, or demo encouragement => thumbsUp
        - good news, success, wins, shipped, fixed, or celebration => excited or happyBounce
        - task, build, implement, fix, debug, review, write, or focused work => rollInBox when available, otherwise workInPlace

        Return JSON only with exactly this shape:
        {"text":"short response","mood":"happy|thinking|sleepy|curious|error","animation":"\(animations)"}

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

    private static func parseSessionID(from stdout: String) -> String? {
        let uuidPattern = #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#
        let keyPattern = #"(session_id|thread_id|conversation_id|id)"#
        let lines = stdout.split(separator: "\n").map(String.init)

        for line in lines where line.range(of: keyPattern, options: .regularExpression) != nil {
            if let range = line.range(of: uuidPattern, options: .regularExpression) {
                return String(line[range]).lowercased()
            }
        }

        if let range = stdout.range(of: uuidPattern, options: .regularExpression) {
            return String(stdout[range]).lowercased()
        }

        return nil
    }

    private static func findNewestSessionID(since startDate: Date) -> String? {
        let sessionsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true)

        guard let enumerator = FileManager.default.enumerator(
            at: sessionsURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var best: (url: URL, date: Date)?

        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modified = values.contentModificationDate,
                  modified >= startDate.addingTimeInterval(-2) else {
                continue
            }

            if best == nil || modified > best!.date {
                best = (url, modified)
            }
        }

        guard let filename = best?.url.lastPathComponent else {
            return nil
        }

        return parseSessionID(from: filename)
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

private struct CodexOutput: Sendable {
    let response: RockyBrainResponse
    let sessionID: String?
}

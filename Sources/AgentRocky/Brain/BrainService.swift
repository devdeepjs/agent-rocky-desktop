import Foundation

enum BrainProviderError: Error {
    case missingOutput
    case missingAPIKey(String)
    case apiFailed(String)
    case invalidEndpoint(String)
    case processFailed(String)
    case timeout
}

struct BrainService: Sendable {
    func respond(
        to message: String,
        provider: BrainProvider,
        model: String,
        apiKey: String,
        baseURL: String,
        history: [ChatTurn],
        sessionID: String?,
        profile: CompanionProfile,
        agentPrompt: String
    ) async -> BrainResult {
        do {
            switch provider {
            case .codexCLI:
                let output = try await Self.runCodex(
                    message: message,
                    model: model,
                    history: history,
                    sessionID: sessionID,
                    profile: profile,
                    agentPrompt: agentPrompt
                )
                let detail = output.sessionID == nil ? provider.statusName : "Codex session saved"
                return BrainResult(response: output.response, usedRemoteBrain: true, detail: detail, sessionID: output.sessionID ?? sessionID)

            case .openAI:
                let response = try await Self.runOpenAIResponses(
                    message: message,
                    provider: provider,
                    model: model,
                    apiKey: apiKey,
                    baseURL: baseURL,
                    history: history,
                    profile: profile,
                    agentPrompt: agentPrompt
                )
                return BrainResult(response: response, usedRemoteBrain: true, detail: provider.statusName, sessionID: sessionID)

            case .openAICompatible, .deepSeek:
                let response = try await Self.runChatCompletions(
                    message: message,
                    provider: provider,
                    model: model,
                    apiKey: apiKey,
                    baseURL: baseURL,
                    history: history,
                    profile: profile,
                    agentPrompt: agentPrompt
                )
                return BrainResult(response: response, usedRemoteBrain: true, detail: provider.statusName, sessionID: sessionID)

            case .gemini:
                let response = try await Self.runGemini(
                    message: message,
                    provider: provider,
                    model: model,
                    apiKey: apiKey,
                    history: history,
                    profile: profile,
                    agentPrompt: agentPrompt
                )
                return BrainResult(response: response, usedRemoteBrain: true, detail: provider.statusName, sessionID: sessionID)

            case .ollama:
                let response = try await Self.runOllama(
                    message: message,
                    provider: provider,
                    model: model,
                    baseURL: baseURL,
                    history: history,
                    profile: profile,
                    agentPrompt: agentPrompt
                )
                return BrainResult(response: response, usedRemoteBrain: true, detail: provider.statusName, sessionID: sessionID)
            }
        } catch {
            return BrainResult(response: Self.fallback(for: message), usedRemoteBrain: false, detail: Self.errorSummary(error), sessionID: sessionID)
        }
    }

    private static func runCodex(
        message: String,
        model: String,
        history: [ChatTurn],
        sessionID: String?,
        profile: CompanionProfile,
        agentPrompt: String
    ) async throws -> ProviderSessionOutput {
        try await Task.detached(priority: .userInitiated) {
            try runCodexSync(
                message: message,
                model: model,
                history: history,
                sessionID: sessionID,
                profile: profile,
                agentPrompt: agentPrompt
            )
        }.value
    }

    private static func runCodexSync(
        message: String,
        model: String,
        history: [ChatTurn],
        sessionID: String?,
        profile: CompanionProfile,
        agentPrompt: String
    ) throws -> ProviderSessionOutput {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-rocky-\(UUID().uuidString).json")

        let prompt = buildCodexPrompt(message: message, history: history, profile: profile, agentPrompt: agentPrompt)
        let startDate = Date()
        let arguments = buildCodexArguments(outputPath: outputURL.path, model: model, sessionID: sessionID)

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
            throw BrainProviderError.timeout
        }

        let stdout = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw BrainProviderError.processFailed(stderr.isEmpty ? stdout : stderr)
        }

        defer {
            try? FileManager.default.removeItem(at: outputURL)
        }

        let raw = (try? String(contentsOf: outputURL, encoding: .utf8)) ?? stdout
        let parsedSessionID = parseSessionID(from: stdout) ?? findNewestSessionID(since: startDate)
        return ProviderSessionOutput(response: try parseResponse(raw), sessionID: parsedSessionID)
    }

    private static func runOpenAIResponses(
        message: String,
        provider: BrainProvider,
        model: String,
        apiKey: String,
        baseURL: String,
        history: [ChatTurn],
        profile: CompanionProfile,
        agentPrompt: String
    ) async throws -> BrainResponse {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw BrainProviderError.missingAPIKey(provider.displayName)
        }

        let body = OpenAIResponsesRequest(
            model: normalizedModel(model, provider: provider),
            input: [
                LLMMessage(role: "developer", content: buildInstructionPrompt(profile: profile, agentPrompt: agentPrompt)),
                LLMMessage(role: "user", content: buildUserPrompt(message: message, history: history))
            ],
            store: false
        )
        let request = try jsonRequest(
            url: endpointURL(baseURL: baseURL, provider: provider, path: "responses"),
            body: body,
            bearerToken: trimmedKey
        )

        let data = try await perform(request, provider: provider)
        let output = try JSONDecoder().decode(OpenAIResponsesResponse.self, from: data)
        if let message = output.error?.message, !message.isEmpty {
            throw BrainProviderError.apiFailed(message)
        }

        return try parseResponse(output.combinedText)
    }

    private static func runChatCompletions(
        message: String,
        provider: BrainProvider,
        model: String,
        apiKey: String,
        baseURL: String,
        history: [ChatTurn],
        profile: CompanionProfile,
        agentPrompt: String
    ) async throws -> BrainResponse {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw BrainProviderError.missingAPIKey(provider.displayName)
        }

        let body = ChatCompletionsRequest(
            model: normalizedModel(model, provider: provider),
            messages: [
                LLMMessage(role: "system", content: buildInstructionPrompt(profile: profile, agentPrompt: agentPrompt)),
                LLMMessage(role: "user", content: buildUserPrompt(message: message, history: history))
            ],
            temperature: 0.4,
            stream: false
        )
        let request = try jsonRequest(
            url: endpointURL(baseURL: baseURL, provider: provider, path: "chat/completions"),
            body: body,
            bearerToken: trimmedKey
        )

        let data = try await perform(request, provider: provider)
        let output = try JSONDecoder().decode(ChatCompletionsResponse.self, from: data)
        return try parseResponse(output.combinedText)
    }

    private static func runGemini(
        message: String,
        provider: BrainProvider,
        model: String,
        apiKey: String,
        history: [ChatTurn],
        profile: CompanionProfile,
        agentPrompt: String
    ) async throws -> BrainResponse {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw BrainProviderError.missingAPIKey(provider.displayName)
        }

        let selectedModel = normalizedModel(model, provider: provider)
        guard let encodedModel = selectedModel.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(encodedModel):generateContent") else {
            throw BrainProviderError.invalidEndpoint("Gemini endpoint")
        }
        components.queryItems = [URLQueryItem(name: "key", value: trimmedKey)]
        guard let url = components.url else {
            throw BrainProviderError.invalidEndpoint("Gemini endpoint")
        }

        let body = GeminiRequest(
            systemInstruction: GeminiContent(parts: [GeminiPart(text: buildInstructionPrompt(profile: profile, agentPrompt: agentPrompt))]),
            contents: [
                GeminiContent(role: "user", parts: [GeminiPart(text: buildUserPrompt(message: message, history: history))])
            ],
            generationConfig: GeminiGenerationConfig(responseMimeType: "application/json")
        )
        let request = try jsonRequest(url: url, body: body, bearerToken: nil)
        let data = try await perform(request, provider: provider)
        let output = try JSONDecoder().decode(GeminiResponse.self, from: data)
        return try parseResponse(output.combinedText)
    }

    private static func runOllama(
        message: String,
        provider: BrainProvider,
        model: String,
        baseURL: String,
        history: [ChatTurn],
        profile: CompanionProfile,
        agentPrompt: String
    ) async throws -> BrainResponse {
        let body = OllamaChatRequest(
            model: normalizedModel(model, provider: provider),
            messages: [
                LLMMessage(role: "system", content: buildInstructionPrompt(profile: profile, agentPrompt: agentPrompt)),
                LLMMessage(role: "user", content: buildUserPrompt(message: message, history: history))
            ],
            stream: false,
            format: "json"
        )
        let request = try jsonRequest(
            url: endpointURL(baseURL: baseURL, provider: provider, path: "api/chat", keepExistingPath: true),
            body: body,
            bearerToken: nil
        )

        let data = try await perform(request, provider: provider)
        let output = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        return try parseResponse(output.message.content)
    }

    private static func buildCodexArguments(outputPath: String, model: String, sessionID: String?) -> [String] {
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

    private static func buildCodexPrompt(message: String, history: [ChatTurn], profile: CompanionProfile, agentPrompt: String) -> String {
        """
        \(buildInstructionPrompt(profile: profile, agentPrompt: agentPrompt))

        \(buildUserPrompt(message: message, history: history))
        """
    }

    private static func buildInstructionPrompt(profile: CompanionProfile, agentPrompt: String) -> String {
        let prompt = agentPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? profile.systemPrompt
            : agentPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let animations = profile.allowedAnimations.map(\.rawValue).joined(separator: "|")

        return """
        \(prompt)

        Keep answers useful. For code or work questions, give one clear next step first, then enough detail to answer fully.
        Stay cute, calm, and focused. Never be generic chatbot.
        Do not run commands. Do not edit files. Do not explain your rules.
        Choose animation from the user's intent:
        - luck, office, interview, exam, presentation, or demo encouragement => thumbsUp
        - good news, success, wins, shipped, fixed, or celebration => excited or happyBounce
        - task, build, implement, fix, debug, review, write, or focused work => \(profile.states.thinking.rawValue)

        Return JSON only with exactly this shape:
        {"text":"response text","mood":"happy|thinking|sleepy|curious|error","animation":"\(animations)"}
        """
    }

    private static func buildUserPrompt(message: String, history: [ChatTurn]) -> String {
        let historyText = history.map { turn in
            "User: \(turn.user)\nAssistant: \(turn.assistant)"
        }.joined(separator: "\n")

        return """
        Recent chat:
        \(historyText.isEmpty ? "None" : historyText)

        User says:
        \(message)
        """
    }

    private static func normalizedModel(_ model: String, provider: BrainProvider) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.lowercased() == "default" {
            return provider.defaultModel
        }

        return trimmed
    }

    private static func endpointURL(
        baseURL: String,
        provider: BrainProvider,
        path: String,
        keepExistingPath: Bool = true
    ) throws -> URL {
        let rawBase = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? provider.defaultBaseURL
            : baseURL.trimmingCharacters(in: .whitespacesAndNewlines)

        guard var components = URLComponents(string: rawBase), components.scheme != nil, components.host != nil else {
            throw BrainProviderError.invalidEndpoint(rawBase)
        }

        let cleanPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let existingPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let parts = keepExistingPath && !existingPath.isEmpty ? [existingPath, cleanPath] : [cleanPath]
        components.path = "/" + parts.filter { !$0.isEmpty }.joined(separator: "/")

        guard let url = components.url else {
            throw BrainProviderError.invalidEndpoint(rawBase)
        }

        return url
    }

    private static func jsonRequest<T: Encodable>(url: URL, body: T, bearerToken: String?) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearerToken, !bearerToken.isEmpty {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private static func perform(_ request: URLRequest, provider: BrainProvider) async throws -> Data {
        let (responseData, urlResponse) = try await URLSession.shared.data(for: request)
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw BrainProviderError.apiFailed("\(provider.displayName) response missing HTTP status")
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let body = String(data: responseData, encoding: .utf8) ?? ""
            throw BrainProviderError.apiFailed("\(provider.displayName) \(httpResponse.statusCode): \(body)")
        }

        return responseData
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

    private static func parseResponse(_ raw: String) throws -> BrainResponse {
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")

        guard let start = cleaned.firstIndex(of: "{"),
              let end = cleaned.lastIndex(of: "}"),
              start <= end else {
            throw BrainProviderError.missingOutput
        }

        let json = String(cleaned[start...end])
        let data = Data(json.utf8)
        return try JSONDecoder().decode(BrainResponse.self, from: data).cleaned
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
            .appendingPathComponent(".codexCLI/sessions", isDirectory: true)

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

    private static func fallback(for message: String) -> BrainResponse {
        let lower = message.lowercased()

        if lower.contains("code") || lower.contains("bug") || lower.contains("error") {
            return BrainResponse(
                text: "Bug question. Split small. Read error first.",
                mood: .thinking,
                animation: .pulse
            )
        }

        if lower.contains("tired") || lower.contains("sleep") {
            return BrainResponse(
                text: "Rest good. Then solve problem.",
                mood: .sleepy,
                animation: .idle
            )
        }

        return BrainResponse(
            text: "Brain slow today. Still, we try small step.",
            mood: .curious,
            animation: .wave
        )
    }

    private static func errorSummary(_ error: Error) -> String {
        switch error {
        case BrainProviderError.missingAPIKey(let providerName):
            return "\(providerName) key missing"
        case BrainProviderError.apiFailed(let detail):
            let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "Provider API failed"
            }
            return String(trimmed.prefix(90))
        case BrainProviderError.invalidEndpoint(let endpoint):
            return "Invalid endpoint: \(endpoint)"
        case BrainProviderError.timeout:
            return "Codex timed out"
        case BrainProviderError.missingOutput:
            return "Brain returned no JSON"
        case BrainProviderError.processFailed(let detail):
            let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "Codex process failed"
            }
            return String(trimmed.prefix(90))
        default:
            return "Brain unavailable"
        }
    }
}

private struct OpenAIResponsesRequest: Encodable {
    let model: String
    let input: [LLMMessage]
    let store: Bool
}

private struct ChatCompletionsRequest: Encodable {
    let model: String
    let messages: [LLMMessage]
    let temperature: Double
    let stream: Bool
}

private struct LLMMessage: Codable {
    let role: String
    let content: String
}

private struct OpenAIResponsesResponse: Decodable {
    let outputText: String?
    let output: [OpenAIOutputItem]?
    let error: ProviderErrorPayload?

    private enum CodingKeys: String, CodingKey {
        case outputText = "output_text"
        case output
        case error
    }

    var combinedText: String {
        if let outputText, !outputText.isEmpty {
            return outputText
        }

        return output?
            .flatMap { $0.content ?? [] }
            .compactMap(\.text)
            .joined(separator: "\n") ?? ""
    }
}

private struct OpenAIOutputItem: Decodable {
    let content: [OpenAIContentItem]?
}

private struct OpenAIContentItem: Decodable {
    let text: String?
}

private struct ChatCompletionsResponse: Decodable {
    let choices: [ChatChoice]

    var combinedText: String {
        choices.map(\.message.content).joined(separator: "\n")
    }
}

private struct ChatChoice: Decodable {
    let message: LLMMessage
}

private struct GeminiRequest: Encodable {
    let systemInstruction: GeminiContent
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig
}

private struct GeminiGenerationConfig: Encodable {
    let responseMimeType: String

    private enum CodingKeys: String, CodingKey {
        case responseMimeType = "response_mime_type"
    }
}

private struct GeminiContent: Codable {
    var role: String?
    let parts: [GeminiPart]

    init(role: String? = nil, parts: [GeminiPart]) {
        self.role = role
        self.parts = parts
    }
}

private struct GeminiPart: Codable {
    let text: String
}

private struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]?

    var combinedText: String {
        candidates?
            .flatMap { $0.content.parts }
            .map(\.text)
            .joined(separator: "\n") ?? ""
    }
}

private struct GeminiCandidate: Decodable {
    let content: GeminiContent
}

private struct OllamaChatRequest: Encodable {
    let model: String
    let messages: [LLMMessage]
    let stream: Bool
    let format: String
}

private struct OllamaChatResponse: Decodable {
    let message: LLMMessage
}

private struct ProviderErrorPayload: Decodable {
    let message: String?
}

private struct ProviderSessionOutput: Sendable {
    let response: BrainResponse
    let sessionID: String?
}

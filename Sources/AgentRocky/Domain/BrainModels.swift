import Foundation

enum CompanionMood: String, Codable, Sendable {
    case happy
    case thinking
    case sleepy
    case curious
    case error
}

struct BrainResponse: Codable, Sendable {
    var text: String
    var mood: CompanionMood
    var animation: CompanionAnimation

    var cleaned: BrainResponse {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeText = trimmed.isEmpty ? "Thinking empty. Try again question." : trimmed

        return BrainResponse(text: safeText, mood: mood, animation: animation)
    }

    func validated(for profile: CompanionProfile) -> BrainResponse {
        let cleaned = cleaned

        return BrainResponse(
            text: cleaned.text,
            mood: cleaned.mood,
            animation: profile.animationOrDefault(cleaned.animation)
        )
    }

    func applyingMessageAnimationHint(for message: String, profile: CompanionProfile) -> BrainResponse {
        guard let animation = Self.messageAnimationHint(for: message, profile: profile) else {
            return self
        }

        return BrainResponse(
            text: text,
            mood: Self.mood(for: animation),
            animation: animation
        )
    }

    static func messageAnimationHint(for message: String, profile: CompanionProfile) -> CompanionAnimation? {
        let lower = message.lowercased()

        if containsAny(lower, [
            "wish me luck",
            "best of luck",
            "good luck",
            "going to office",
            "going office",
            "heading to office",
            "interview",
            "exam",
            "presentation",
            "demo today"
        ]) {
            return firstAllowed([.thumbsUp, .happyBounce, .excited], for: profile)
        }

        if containsAny(lower, [
            "good news",
            "great news",
            "big news",
            "i did it",
            "we did it",
            "we won",
            "i won",
            "got promoted",
            "promotion",
            "passed",
            "success",
            "shipped",
            "it worked",
            "fixed it",
            "celebrate"
        ]) {
            return firstAllowed([.excited, .happyBounce], for: profile)
        }

        if containsAny(lower, [
            "do this",
            "do it",
            "task",
            "work on",
            "help me with",
            "make ",
            "build ",
            "create ",
            "implement",
            "fix ",
            "debug",
            "review ",
            "write ",
            "test "
        ]) {
            return firstAllowed([.rollInBox, .workInPlace, .think], for: profile)
        }

        return nil
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    private static func firstAllowed(_ animations: [CompanionAnimation], for profile: CompanionProfile) -> CompanionAnimation? {
        animations.first { profile.allowedAnimations.contains($0) }
    }

    static func mood(for animation: CompanionAnimation) -> CompanionMood {
        switch animation {
        case .sleep:
            return .sleepy
        case .think, .workInPlace, .rollInBox:
            return .thinking
        case .error:
            return .error
        case .happyBounce, .excited, .thumbsUp:
            return .happy
        case .idle, .bounce, .pulse, .shake, .walk, .wave, .play, .playBall, .lick, .purr:
            return .curious
        }
    }
}

struct ChatTurn: Codable, Equatable, Sendable {
    let user: String
    let assistant: String

    init(user: String, assistant: String) {
        self.user = user
        self.assistant = assistant
    }

    private enum CodingKeys: String, CodingKey {
        case user
        case assistant
        case rocky
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        user = try container.decode(String.self, forKey: .user)
        assistant = try container.decodeIfPresent(String.self, forKey: .assistant)
            ?? (try container.decodeIfPresent(String.self, forKey: .rocky))
            ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(user, forKey: .user)
        try container.encode(assistant, forKey: .assistant)
    }
}

enum BrainProvider: String, CaseIterable, Codable, Sendable {
    case codexCLI = "codex-cli"
    case openAI = "openai"
    case openAICompatible = "openai-compatible"
    case deepSeek = "deepseek"
    case gemini = "gemini"
    case ollama = "ollama"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case "codex", "codexCLI", "Codex CLI":
            self = .codexCLI
        case "openAI", "openai", "OpenAI BYOK":
            self = .openAI
        default:
            guard let provider = BrainProvider(rawValue: raw) else {
                self = .codexCLI
                return
            }
            self = provider
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var displayName: String {
        switch self {
        case .codexCLI:
            return "Codex CLI"
        case .openAI:
            return "OpenAI"
        case .openAICompatible:
            return "OpenAI-compatible"
        case .deepSeek:
            return "DeepSeek"
        case .gemini:
            return "Gemini"
        case .ollama:
            return "Ollama"
        }
    }

    var statusName: String {
        switch self {
        case .codexCLI:
            return "Codex CLI"
        case .openAI:
            return "OpenAI API"
        case .openAICompatible:
            return "OpenAI-compatible API"
        case .deepSeek:
            return "DeepSeek API"
        case .gemini:
            return "Gemini API"
        case .ollama:
            return "Ollama"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .codexCLI, .ollama:
            return false
        case .openAI, .openAICompatible, .deepSeek, .gemini:
            return true
        }
    }

    var supportsBaseURL: Bool {
        switch self {
        case .codexCLI, .gemini:
            return false
        case .openAI, .openAICompatible, .deepSeek, .ollama:
            return true
        }
    }

    var apiKeyPlaceholder: String {
        switch self {
        case .codexCLI:
            return "Codex uses local login"
        case .openAI:
            return "OpenAI API key"
        case .openAICompatible:
            return "API key"
        case .deepSeek:
            return "DeepSeek API key"
        case .gemini:
            return "Gemini API key"
        case .ollama:
            return "Ollama usually needs no key"
        }
    }

    var defaultModel: String {
        switch self {
        case .codexCLI:
            return ""
        case .openAI:
            return "gpt-5.4-mini"
        case .openAICompatible:
            return "gpt-4o-mini"
        case .deepSeek:
            return "deepseek-v4-flash"
        case .gemini:
            return "gemini-2.5-flash"
        case .ollama:
            return "llama3.2"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .codexCLI, .gemini:
            return ""
        case .openAI:
            return "https://api.openai.com/v1"
        case .openAICompatible:
            return "https://api.openai.com/v1"
        case .deepSeek:
            return "https://api.deepseek.com"
        case .ollama:
            return "http://localhost:11434"
        }
    }

    var modelChoices: [String] {
        switch self {
        case .codexCLI:
            return ["", "gpt-5.5", "gpt-5.4", "gpt-5.4-mini", "gpt-5.4-nano", "gpt-5-mini"]
        case .openAI:
            return ["gpt-5.5", "gpt-5.4", "gpt-5.4-mini", "gpt-5.4-nano", "gpt-5-mini", "gpt-5-nano", "gpt-4.1"]
        case .openAICompatible:
            return ["gpt-4o-mini", "gpt-4.1-mini", "llama-3.1-8b-instruct", "qwen2.5-coder-7b-instruct"]
        case .deepSeek:
            return ["deepseek-v4-flash", "deepseek-v4-pro", "deepseek-chat", "deepseek-reasoner"]
        case .gemini:
            return ["gemini-2.5-flash", "gemini-2.5-pro", "gemini-1.5-flash", "gemini-1.5-pro"]
        case .ollama:
            return ["llama3.2", "llama3.1", "qwen2.5-coder", "mistral", "gemma3"]
        }
    }
}

struct AppPreferences: Codable, Equatable, Sendable {
    var brainProvider: BrainProvider
    var model: String
    var baseURL: String
    var agentPrompt: String

    static let defaults = AppPreferences(
        brainProvider: .codexCLI,
        model: "",
        baseURL: "",
        agentPrompt: ""
    )

    init(
        brainProvider: BrainProvider,
        model: String,
        baseURL: String,
        agentPrompt: String
    ) {
        self.brainProvider = brainProvider
        self.model = model
        self.baseURL = baseURL
        self.agentPrompt = agentPrompt
    }

    private enum CodingKeys: String, CodingKey {
        case brainProvider
        case model
        case baseURL
        case agentPrompt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        brainProvider = try container.decodeIfPresent(BrainProvider.self, forKey: .brainProvider) ?? .codexCLI
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? ""
        agentPrompt = try container.decodeIfPresent(String.self, forKey: .agentPrompt) ?? ""
    }
}

struct BrainResult: Sendable {
    let response: BrainResponse
    let usedRemoteBrain: Bool
    let detail: String
    let sessionID: String?
}

import AppKit
import SwiftUI

@MainActor
final class CompanionAppViewModel: ObservableObject {
    @Published var currentText = "ready"
    @Published var mood: CompanionMood = .curious
    @Published var animation: CompanionAnimation = .idle
    @Published var input = ""
    @Published var model = ""
    @Published var brainProvider: BrainProvider = .codexCLI
    @Published var providerBaseURL = ""
    @Published var agentPrompt = ""
    @Published var providerAPIKey = ""
    @Published var isThinking = false
    @Published var brainStatus = "Codex default"
    @Published var isUsingFallback = false
    @Published var isStageOpen = false
    @Published var activeConversationID = ""
    @Published var conversations: [ConversationSummary] = []
    @Published var availableProfiles = StandardCompanionProfiles.all
    @Published var activeProfile = StandardCompanionProfiles.rocky
    @Published var activeMovementMode: CompanionMovementMode = .static
    @Published var terminalLines = [
        "agent rocky v0.3",
        "hover to talk"
    ]

    private let brain = BrainService()
    private let memoryStore = ConversationStore()
    private var history: [ChatTurn] = []
    private var codexSessionID: String?
    private var conversationCreatedAt = Date()

    private let idleLines: [BrainResponse] = [
        BrainResponse(text: "good good good", mood: .happy, animation: .happyBounce),
        BrainResponse(text: "question?", mood: .curious, animation: .wave),
        BrainResponse(text: "thinking small", mood: .thinking, animation: .pulse),
        BrainResponse(text: "sleep later", mood: .sleepy, animation: .idle)
    ]

    init() {
        availableProfiles = Self.mergedProfiles(
            bundled: StandardCompanionProfiles.all,
            custom: memoryStore.loadCustomProfiles()
        )
        load(memoryStore.loadState())
        loadBrainSettings()
    }

    func poke() {
        guard !isThinking else { return }
        apply(idleLines.randomElement() ?? idleLines[0])
    }

    func previewNormalState() {
        guard !isThinking else { return }
        apply(BrainResponse(text: "normal", mood: .curious, animation: activeProfile.states.normal))
    }

    func previewThinkingState() {
        guard !isThinking else { return }
        apply(BrainResponse(text: "thinking", mood: .thinking, animation: activeProfile.states.thinking))
    }

    func previewIdleAction() {
        guard !isThinking else { return }
        let animation = activeProfile.states.idle.randomElement() ?? activeProfile.states.normal
        apply(BrainResponse(text: animation.rawValue, mood: mood(for: animation), animation: animation))
    }

    func send() {
        let message = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, !isThinking else { return }

        input = ""

        if handleCommand(message) {
            return
        }

        isThinking = true
        appendTerminal("> \(message)")
        appendTerminal("\(profileTerminalName): thinking...")
        apply(BrainResponse(text: "thinking...", mood: .thinking, animation: activeProfile.states.thinking))

        let modelName = normalizedModel
        let baseURL = normalizedBaseURL
        let recentHistory = Array(history.suffix(6))
        let activeSessionID = codexSessionID
        let profile = activeProfile
        let provider = brainProvider
        let apiKey = providerAPIKey
        let prompt = agentPrompt

        Task {
            let result = await brain.respond(
                to: message,
                provider: provider,
                model: modelName,
                apiKey: apiKey,
                baseURL: baseURL,
                history: recentHistory,
                sessionID: activeSessionID,
                profile: profile,
                agentPrompt: prompt
            )
            let response = result.response
                .validated(for: profile)
                .applyingMessageAnimationHint(for: message, profile: profile)
            history.append(ChatTurn(user: message, assistant: response.text))
            codexSessionID = result.sessionID ?? codexSessionID
            brainStatus = result.detail
            isUsingFallback = !result.usedRemoteBrain
            replaceLastTerminalLine("\(profile.name.lowercased()): \(response.text)")
            apply(response)
            persist()
            isThinking = false
        }
    }

    func newChat() {
        load(memoryStore.createConversation(profileID: activeProfile.id, model: model))
        currentText = "ready"
        mood = .curious
        animation = activeProfile.states.normal
        brainStatus = brainProvider == .codexCLI ? "New Codex session on next message" : apiKeyStatus
        isUsingFallback = false
        input = ""
    }

    func selectChat(_ id: String) {
        guard !isThinking, let state = memoryStore.selectConversation(id: id) else {
            return
        }

        load(state)
        input = ""
        currentText = "ready"
        mood = .curious
        animation = activeProfile.states.normal
        isUsingFallback = false
    }

    func deleteActiveChat() {
        guard !isThinking, !activeConversationID.isEmpty else {
            return
        }

        load(memoryStore.deleteConversation(id: activeConversationID))
        input = ""
        currentText = "ready"
        mood = .curious
        animation = activeProfile.states.normal
        brainStatus = codexSessionID == nil ? "Codex default" : "Codex session saved"
    }

    func switchProfile(_ id: String) {
        guard let profile = availableProfiles.first(where: { $0.id == id }) else {
            appendTerminal("system: unknown profile \(id)")
            persist()
            return
        }

        activeProfile = profile
        activeMovementMode = profile.movementMode
        if agentPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            agentPrompt = profile.systemPrompt
        }
        if model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let defaultModel = profile.defaultModel {
            model = defaultModel
        }
        appendTerminal("system: profile \(profile.name)")
        persist()
    }

    var modelChoices: [String] {
        brainProvider.modelChoices
    }

    var providerLabel: String {
        brainProvider.displayName
    }

    var apiKeyStatus: String {
        if !brainProvider.requiresAPIKey {
            return "\(brainProvider.displayName) uses local auth"
        }

        return providerAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "No \(brainProvider.displayName) key saved"
            : "\(brainProvider.displayName) key saved in Keychain"
    }

    func switchProvider(_ provider: BrainProvider) {
        guard brainProvider != provider else { return }
        brainProvider = provider
        providerAPIKey = KeychainSecretStore.readAPIKey(for: provider)

        if model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "default" {
            model = provider.defaultModel
        }

        if provider.supportsBaseURL,
           providerBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            providerBaseURL = provider.defaultBaseURL
        }

        brainStatus = provider == .codexCLI ? "Codex CLI" : apiKeyStatus
        saveBrainSettings(appendLine: false)
    }

    func selectModel(_ selectedModel: String) {
        model = selectedModel
        saveBrainSettings(appendLine: false)
    }

    func resetAgentPrompt() {
        agentPrompt = activeProfile.systemPrompt
        saveBrainSettings()
    }

    func saveBrainSettings(appendLine: Bool = true) {
        if brainProvider.requiresAPIKey {
            KeychainSecretStore.saveAPIKey(providerAPIKey, for: brainProvider)
        }

        memoryStore.savePreferences(AppPreferences(
            brainProvider: brainProvider,
            model: model,
            baseURL: providerBaseURL,
            agentPrompt: agentPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? activeProfile.systemPrompt : agentPrompt
        ))

        brainStatus = brainProvider == .codexCLI ? "Codex CLI settings saved" : apiKeyStatus
        if appendLine {
            appendTerminal("system: brain settings saved")
            persist()
        }
    }

    func hidePanel() {
        NSApp.windows.first(where: { $0.title == "Agent Rocky" })?.orderOut(nil)
    }

    func openStage() {
        guard !isStageOpen else { return }
        isStageOpen = true
        appendTerminal("system: stage open")
        persist()
    }

    func closeStage() {
        guard isStageOpen else { return }
        isStageOpen = false
        appendTerminal("system: mini mode")
        persist()
    }

    func performIdleBehavior() {
        guard !isThinking, input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        previewIdleAction()
    }

    func nextIdleDelayMilliseconds() -> Int {
        let cooldown = max(3, activeProfile.states.idleCooldownSeconds)
        let jitter = max(0, activeProfile.states.idleJitterSeconds)
        let next = cooldown + Double.random(in: 0...jitter)
        return max(3_000, Int(next * 1_000))
    }

    private func apply(_ response: BrainResponse) {
        let cleaned = response.cleaned
        withAnimation(.spring(response: 0.35, dampingFraction: 0.74)) {
            currentText = cleaned.text
            mood = cleaned.mood
            animation = cleaned.animation
        }
    }

    private func appendTerminal(_ line: String) {
        terminalLines.append(line)
        if terminalLines.count > 40 {
            terminalLines.removeFirst(terminalLines.count - 40)
        }
    }

    private func replaceLastTerminalLine(_ line: String) {
        if terminalLines.isEmpty {
            appendTerminal(line)
        } else {
            terminalLines[terminalLines.count - 1] = line
        }
    }

    private func handleCommand(_ message: String) -> Bool {
        guard message.hasPrefix("/") else {
            return false
        }

        let parts = message
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)
        let command = parts.first?.lowercased() ?? ""

        switch command {
        case "/open", "/stage":
            appendTerminal("> \(message)")
            openStage()
            persist()
            return true

        case "/mini", "/close":
            appendTerminal("> \(message)")
            closeStage()
            persist()
            return true

        case "/new":
            newChat()
            return true

        case "/chats":
            appendTerminal("> \(message)")
            if conversations.isEmpty {
                appendTerminal("system: no chats")
            } else {
                conversations.prefix(8).forEach { conversation in
                    let marker = conversation.id == activeConversationID ? "*" : "-"
                    appendTerminal("system: \(marker) \(conversation.title)")
                }
            }
            persist()
            return true

        case "/profiles":
            appendTerminal("> \(message)")
            availableProfiles.forEach { profile in
                let marker = profile.id == activeProfile.id ? "*" : "-"
                appendTerminal("system: \(marker) \(profile.id) - \(profile.name)")
            }
            persist()
            return true

        case "/profile":
            appendTerminal("> \(message)")
            guard parts.count > 1 else {
                appendTerminal("system: usage /profile rocky")
                persist()
                return true
            }
            switchProfile(parts[1])
            return true

        case "/mode":
            appendTerminal("> \(message)")
            guard parts.count > 1 else {
                appendTerminal("system: usage /mode static|dynamic")
                persist()
                return true
            }
            switchMovementMode(parts[1].lowercased())
            return true

        case "/animate":
            appendTerminal("> \(message)")
            guard parts.count > 1 else {
                appendTerminal("system: usage /animate happyBounce")
                persist()
                return true
            }
            runAnimationCommand(parts[1])
            return true

        case "/hide", "/minimize":
            appendTerminal("> \(message)")
            appendTerminal("system: hidden. use menu bar Agent Rocky to show")
            persist()
            hidePanel()
            return true

        case "/delete":
            deleteActiveChat()
            appendTerminal("system: deleted active chat")
            persist()
            return true

        case "/help":
            appendTerminal("> \(message)")
            appendTerminal("system: /open /mini /hide /new /chats /delete /profiles /profile <id> /mode static|dynamic /animate <name>")
            persist()
            return true

        default:
            appendTerminal("> \(message)")
            appendTerminal("system: unknown command. try /help")
            persist()
            return true
        }
    }

    private func persist() {
        var conversation = CompanionConversation(
            id: activeConversationID.isEmpty ? UUID().uuidString.lowercased() : activeConversationID,
            title: titleForCurrentConversation(),
            createdAt: conversationCreatedAt,
            updatedAt: Date(),
            codexSessionID: codexSessionID,
            profileID: activeProfile.id,
            movementMode: activeMovementMode,
            model: model,
            terminalLines: terminalLines,
            history: history
        )
        conversation.title = titleForCurrentConversation()
        memoryStore.saveConversation(conversation, makeActive: true)
        conversations = memoryStore.listSummaries()
    }

    private func load(_ state: ConversationState) {
        let conversation = state.active
        activeConversationID = conversation.id
        conversations = state.summaries
        codexSessionID = conversation.codexSessionID
        activeProfile = availableProfiles.first(where: { $0.id == conversation.profileID })
            ?? StandardCompanionProfiles.profile(id: conversation.profileID)
            ?? StandardCompanionProfiles.rocky
        activeMovementMode = conversation.movementMode ?? activeProfile.movementMode
        conversationCreatedAt = conversation.createdAt
        model = conversation.model
        history = conversation.history
        terminalLines = conversation.terminalLines.isEmpty ? ["agent rocky v0.3", "hover to talk"] : conversation.terminalLines
        brainStatus = conversation.codexSessionID == nil ? providerLabel : "Codex session saved"
    }

    private var normalizedModel: String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.lowercased() == "default" {
            return brainProvider.defaultModel
        }

        return trimmed
    }

    private var normalizedBaseURL: String {
        let trimmed = providerBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return brainProvider.defaultBaseURL
        }

        return trimmed
    }

    private var profileTerminalName: String {
        activeProfile.name.lowercased()
    }

    private func loadBrainSettings() {
        let preferences = memoryStore.loadPreferences()
        brainProvider = preferences.brainProvider
        providerBaseURL = preferences.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? brainProvider.defaultBaseURL
            : preferences.baseURL

        let preferredModel = preferences.model.trimmingCharacters(in: .whitespacesAndNewlines)
        if !preferredModel.isEmpty || model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            model = preferredModel
        }

        let prompt = preferences.agentPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        agentPrompt = prompt.isEmpty ? activeProfile.systemPrompt : preferences.agentPrompt
        providerAPIKey = KeychainSecretStore.readAPIKey(for: brainProvider)
        brainStatus = brainProvider == .codexCLI ? "Codex CLI" : apiKeyStatus
    }

    private func titleForCurrentConversation() -> String {
        if let first = history.first?.user.trimmingCharacters(in: .whitespacesAndNewlines),
           !first.isEmpty {
            return first.count <= 34 ? first : String(first.prefix(31)) + "..."
        }

        return "New chat"
    }

    private func switchMovementMode(_ rawMode: String) {
        guard let mode = CompanionMovementMode(rawValue: rawMode) else {
            appendTerminal("system: mode must be static or dynamic")
            persist()
            return
        }

        if activeMovementMode == mode {
            appendTerminal("system: mode already \(mode.rawValue)")
            persist()
            return
        }

        activeMovementMode = mode
        appendTerminal("system: mode \(mode.rawValue)")
        persist()
    }

    private func runAnimationCommand(_ rawAnimation: String) {
        guard let requested = CompanionAnimation(rawValue: rawAnimation) else {
            appendTerminal("system: unknown animation \(rawAnimation)")
            persist()
            return
        }

        let selected = activeProfile.animationOrDefault(requested)
        if selected != requested {
            appendTerminal("system: \(requested.rawValue) not allowed for \(activeProfile.name), using \(selected.rawValue)")
        } else {
            appendTerminal("system: animate \(selected.rawValue)")
        }

        apply(BrainResponse(
            text: selected.rawValue,
            mood: mood(for: selected),
            animation: selected
        ))
        persist()
    }

    private func response(for behavior: CompanionIdleBehavior) -> BrainResponse {
        switch behavior {
        case .watching:
            return BrainResponse(text: "watching", mood: .curious, animation: .idle)
        case .sleeping:
            return BrainResponse(text: "sleeping", mood: .sleepy, animation: .sleep)
        case .working:
            return BrainResponse(text: "working", mood: .thinking, animation: .workInPlace)
        case .lookingAround:
            return BrainResponse(text: "looking", mood: .curious, animation: .wave)
        case .licking:
            return BrainResponse(text: "lick", mood: .happy, animation: .lick)
        case .playing:
            return BrainResponse(text: "play", mood: .happy, animation: .play)
        }
    }

    private func mood(for animation: CompanionAnimation) -> CompanionMood {
        switch animation {
        case .sleep:
            return .sleepy
        case .think, .workInPlace, .rollInBox:
            return .thinking
        case .error:
            return .error
        case .shake, .walk, .wave, .play, .playBall, .lick, .purr:
            return .curious
        case .bounce, .happyBounce, .excited, .thumbsUp:
            return .happy
        case .idle, .pulse:
            return .curious
        }
    }

    private static func mergedProfiles(
        bundled: [CompanionProfile],
        custom: [CompanionProfile]
    ) -> [CompanionProfile] {
        var byID: [String: CompanionProfile] = [:]
        var order: [String] = []

        for profile in bundled + custom {
            if byID[profile.id] == nil {
                order.append(profile.id)
            }
            byID[profile.id] = profile
        }

        return order.compactMap { byID[$0] }
    }
}

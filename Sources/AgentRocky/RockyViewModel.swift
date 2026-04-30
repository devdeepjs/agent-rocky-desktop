import AppKit
import SwiftUI

@MainActor
final class RockyViewModel: ObservableObject {
    @Published var currentText = "ready"
    @Published var mood: RockyMood = .curious
    @Published var animation: RockyAnimation = .idle
    @Published var input = ""
    @Published var model = ""
    @Published var isThinking = false
    @Published var brainStatus = "Codex default"
    @Published var isUsingFallback = false
    @Published var isStageOpen = false
    @Published var activeConversationID = ""
    @Published var conversations: [RockyConversationSummary] = []
    @Published var availableProfiles = StandardCompanionProfiles.all
    @Published var activeProfile = StandardCompanionProfiles.rocky
    @Published var activeMovementMode: CompanionMovementMode = .static
    @Published var terminalLines = [
        "agent rocky v0.3",
        "hover to talk"
    ]

    private let brain = CodexBrain()
    private let memoryStore = RockyMemoryStore()
    private var history: [ChatTurn] = []
    private var codexSessionID: String?
    private var conversationCreatedAt = Date()

    private let idleLines: [RockyBrainResponse] = [
        RockyBrainResponse(text: "good good good", mood: .happy, animation: .bounce),
        RockyBrainResponse(text: "question?", mood: .curious, animation: .wave),
        RockyBrainResponse(text: "thinking small", mood: .thinking, animation: .pulse),
        RockyBrainResponse(text: "sleep later", mood: .sleepy, animation: .idle)
    ]

    init() {
        load(memoryStore.loadState())
    }

    func poke() {
        guard !isThinking else { return }
        apply(idleLines.randomElement() ?? idleLines[0])
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
        appendTerminal("rocky: thinking...")
        apply(RockyBrainResponse(text: "thinking...", mood: .thinking, animation: .pulse))

        let modelName = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let recentHistory = Array(history.suffix(6))
        let activeSessionID = codexSessionID
        let profile = activeProfile

        Task {
            let result = await brain.respond(to: message, model: modelName, history: recentHistory, sessionID: activeSessionID, profile: profile)
            let response = result.response
                .validated(for: profile)
                .applyingMessageAnimationHint(for: message, profile: profile)
            history.append(ChatTurn(user: message, rocky: response.text))
            codexSessionID = result.sessionID ?? codexSessionID
            brainStatus = result.detail
            isUsingFallback = !result.usedCodex
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
        animation = .idle
        brainStatus = "New Codex session on next message"
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
        animation = .idle
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
        animation = .idle
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
        if model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let defaultModel = profile.defaultModel {
            model = defaultModel
        }
        appendTerminal("system: profile \(profile.name)")
        persist()
    }

    func quit() {
        NSApp.terminate(nil)
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

        let behavior = activeProfile.idleBehaviors.randomElement() ?? .watching
        apply(response(for: behavior))
    }

    private func apply(_ response: RockyBrainResponse) {
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

        case "/delete":
            deleteActiveChat()
            appendTerminal("system: deleted active chat")
            persist()
            return true

        case "/help":
            appendTerminal("> \(message)")
            appendTerminal("system: /open /mini /new /chats /delete /profiles /profile <id> /mode static|dynamic /animate <name>")
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
        var conversation = RockyConversation(
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

    private func load(_ state: RockyConversationState) {
        let conversation = state.active
        activeConversationID = conversation.id
        conversations = state.summaries
        codexSessionID = conversation.codexSessionID
        activeProfile = StandardCompanionProfiles.profile(id: conversation.profileID) ?? StandardCompanionProfiles.rocky
        activeMovementMode = conversation.movementMode ?? activeProfile.movementMode
        conversationCreatedAt = conversation.createdAt
        model = conversation.model
        history = conversation.history
        terminalLines = conversation.terminalLines.isEmpty ? ["agent rocky v0.3", "hover to talk"] : conversation.terminalLines
        brainStatus = conversation.codexSessionID == nil ? "Codex default" : "Codex session saved"
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

        apply(RockyBrainResponse(
            text: selected.rawValue,
            mood: mood(for: selected),
            animation: RockyAnimation(companion: selected)
        ))
        persist()
    }

    private func response(for behavior: CompanionIdleBehavior) -> RockyBrainResponse {
        switch behavior {
        case .watching:
            return RockyBrainResponse(text: "watching", mood: .curious, animation: .idle)
        case .sleeping:
            return RockyBrainResponse(text: "sleeping", mood: .sleepy, animation: .sleep)
        case .working:
            return RockyBrainResponse(text: "working", mood: .thinking, animation: .workInPlace)
        case .lookingAround:
            return RockyBrainResponse(text: "looking", mood: .curious, animation: .wave)
        case .licking:
            return RockyBrainResponse(text: "lick", mood: .happy, animation: .lick)
        case .playing:
            return RockyBrainResponse(text: "play", mood: .happy, animation: .play)
        }
    }

    private func mood(for animation: CompanionAnimation) -> RockyMood {
        switch animation {
        case .sleep:
            return .sleepy
        case .think, .workInPlace:
            return .thinking
        case .error:
            return .error
        case .walk, .wave, .play, .playBall, .lick, .purr:
            return .curious
        case .happyBounce, .excited, .thumbsUp, .rollInBox:
            return .happy
        case .idle, .pulse:
            return .curious
        }
    }
}

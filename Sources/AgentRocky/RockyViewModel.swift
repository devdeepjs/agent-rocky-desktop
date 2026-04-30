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
    @Published var activeConversationID = ""
    @Published var conversations: [RockyConversationSummary] = []
    @Published var terminalLines = [
        "agent rocky v0.3",
        "hover to talk"
    ]

    private let brain = CodexBrain()
    private let memoryStore = RockyMemoryStore()
    private var history: [ChatTurn] = []
    private var codexSessionID: String?
    private var profileID = "rocky"
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
        isThinking = true
        appendTerminal("> \(message)")
        appendTerminal("rocky: thinking...")
        apply(RockyBrainResponse(text: "thinking...", mood: .thinking, animation: .pulse))

        let modelName = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let recentHistory = Array(history.suffix(6))
        let activeSessionID = codexSessionID

        Task {
            let result = await brain.respond(to: message, model: modelName, history: recentHistory, sessionID: activeSessionID)
            history.append(ChatTurn(user: message, rocky: result.response.text))
            codexSessionID = result.sessionID ?? codexSessionID
            brainStatus = result.detail
            isUsingFallback = !result.usedCodex
            replaceLastTerminalLine("rocky: \(result.response.text)")
            apply(result.response)
            persist()
            isThinking = false
        }
    }

    func newChat() {
        load(memoryStore.createConversation(profileID: profileID, model: model))
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

    func quit() {
        NSApp.terminate(nil)
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

    private func persist() {
        var conversation = RockyConversation(
            id: activeConversationID.isEmpty ? UUID().uuidString.lowercased() : activeConversationID,
            title: titleForCurrentConversation(),
            createdAt: conversationCreatedAt,
            updatedAt: Date(),
            codexSessionID: codexSessionID,
            profileID: profileID,
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
        profileID = conversation.profileID
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
}

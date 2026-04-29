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
    @Published var terminalLines = [
        "agent rocky v0.2",
        "hover to talk"
    ]

    private let brain = CodexBrain()
    private var history: [ChatTurn] = []

    private let idleLines: [RockyBrainResponse] = [
        RockyBrainResponse(text: "good good good", mood: .happy, animation: .bounce),
        RockyBrainResponse(text: "question?", mood: .curious, animation: .wave),
        RockyBrainResponse(text: "thinking small", mood: .thinking, animation: .pulse),
        RockyBrainResponse(text: "sleep later", mood: .sleepy, animation: .idle)
    ]

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

        Task {
            let result = await brain.respond(to: message, model: modelName, history: recentHistory)
            history.append(ChatTurn(user: message, rocky: result.response.text))
            brainStatus = result.detail
            isUsingFallback = !result.usedCodex
            replaceLastTerminalLine("rocky: \(result.response.text)")
            apply(result.response)
            isThinking = false
        }
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
}

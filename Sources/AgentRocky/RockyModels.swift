import Foundation

enum RockyMood: String, Codable, Sendable {
    case happy
    case thinking
    case sleepy
    case curious
    case error
}

enum RockyAnimation: String, Codable, Sendable {
    case idle
    case bounce
    case wave
    case pulse
    case shake
    case walk
    case think
    case sleep
    case error
    case excited
    case rollInBox
    case happyBounce
    case workInPlace
    case lick
    case purr
    case thumbsUp
    case play
    case playBall
}

struct RockyBrainResponse: Codable, Sendable {
    var text: String
    var mood: RockyMood
    var animation: RockyAnimation

    var cleaned: RockyBrainResponse {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeText: String

        if trimmed.isEmpty {
            safeText = "Thinking empty. Try again question."
        } else if trimmed.count > 320 {
            safeText = String(trimmed.prefix(317)) + "..."
        } else {
            safeText = trimmed
        }

        return RockyBrainResponse(text: safeText, mood: mood, animation: animation)
    }
}

struct ChatTurn: Codable, Equatable, Sendable {
    let user: String
    let rocky: String
}

struct RockyBrainResult: Sendable {
    let response: RockyBrainResponse
    let usedCodex: Bool
    let detail: String
    let sessionID: String?
}

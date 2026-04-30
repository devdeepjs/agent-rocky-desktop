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
    static let maxTextCharacters = 2_000

    var text: String
    var mood: RockyMood
    var animation: RockyAnimation

    var cleaned: RockyBrainResponse {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeText: String

        if trimmed.isEmpty {
            safeText = "Thinking empty. Try again question."
        } else if trimmed.count > Self.maxTextCharacters {
            safeText = String(trimmed.prefix(Self.maxTextCharacters - 3)) + "..."
        } else {
            safeText = trimmed
        }

        return RockyBrainResponse(text: safeText, mood: mood, animation: animation)
    }

    func validated(for profile: CompanionProfile) -> RockyBrainResponse {
        let cleaned = cleaned
        guard let companionAnimation = CompanionAnimation(rawValue: cleaned.animation.rawValue) else {
            return RockyBrainResponse(
                text: cleaned.text,
                mood: cleaned.mood,
                animation: RockyAnimation(companion: profile.defaultAnimation)
            )
        }

        return RockyBrainResponse(
            text: cleaned.text,
            mood: cleaned.mood,
            animation: RockyAnimation(companion: profile.animationOrDefault(companionAnimation))
        )
    }

    func applyingMessageAnimationHint(for message: String, profile: CompanionProfile) -> RockyBrainResponse {
        guard let animation = Self.messageAnimationHint(for: message, profile: profile) else {
            return self
        }

        return RockyBrainResponse(
            text: text,
            mood: Self.mood(for: animation),
            animation: RockyAnimation(companion: animation)
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

    private static func mood(for animation: CompanionAnimation) -> RockyMood {
        switch animation {
        case .sleep:
            return .sleepy
        case .think, .workInPlace, .rollInBox:
            return .thinking
        case .error:
            return .error
        case .happyBounce, .excited, .thumbsUp:
            return .happy
        case .idle, .pulse, .walk, .wave, .play, .playBall, .lick, .purr:
            return .curious
        }
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

extension RockyAnimation {
    init(companion animation: CompanionAnimation) {
        self = RockyAnimation(rawValue: animation.rawValue) ?? .idle
    }
}

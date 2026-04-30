import Foundation

enum CompanionKind: String, CaseIterable, Codable, Sendable {
    case rocky
    case cat
    case custom
}

enum CompanionVisualStyle: String, CaseIterable, Codable, Sendable {
    case cinematicRocky
    case pixelRocky
    case cozyCat
    case custom
}

enum CompanionMovementMode: String, CaseIterable, Codable, Sendable {
    case `static`
    case dynamic
}

enum CompanionAnimation: String, CaseIterable, Codable, Sendable {
    case idle
    case walk
    case wave
    case think
    case pulse
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

enum CompanionIdleBehavior: String, CaseIterable, Codable, Sendable {
    case watching
    case sleeping
    case working
    case lookingAround
    case licking
    case playing
}

struct CompanionProfile: Codable, Equatable, Identifiable, Sendable {
    let id: String
    var name: String
    var kind: CompanionKind
    var systemPrompt: String
    var defaultModel: String?
    var visualStyle: CompanionVisualStyle
    var movementMode: CompanionMovementMode
    var defaultAnimation: CompanionAnimation
    var allowedAnimations: [CompanionAnimation]
    var idleBehaviors: [CompanionIdleBehavior]
    var accentColorHex: String

    var validationIssues: [String] {
        var issues: [String] = []

        if id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("id is required")
        }

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("name is required")
        }

        if systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("systemPrompt is required")
        }

        if allowedAnimations.isEmpty {
            issues.append("allowedAnimations must not be empty")
        }

        if !allowedAnimations.contains(defaultAnimation) {
            issues.append("defaultAnimation must be allowed")
        }

        if idleBehaviors.isEmpty {
            issues.append("idleBehaviors must not be empty")
        }

        if !Self.isValidHexColor(accentColorHex) {
            issues.append("accentColorHex must be #RRGGBB")
        }

        return issues
    }

    var isValid: Bool {
        validationIssues.isEmpty
    }

    func animationOrDefault(_ requested: CompanionAnimation) -> CompanionAnimation {
        allowedAnimations.contains(requested) ? requested : defaultAnimation
    }

    private static func isValidHexColor(_ value: String) -> Bool {
        let pattern = #"^#[0-9a-fA-F]{6}$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }
}

enum StandardCompanionProfiles {
    static let rocky = CompanionProfile(
        id: "rocky",
        name: "Rocky",
        kind: .rocky,
        systemPrompt: """
        You are Rocky, a loyal tiny desktop companion. The user is your Grace: your human, engineer, and friend. Speak in short, warm, slightly odd English. Be useful first.
        """,
        defaultModel: nil,
        visualStyle: .cinematicRocky,
        movementMode: .static,
        defaultAnimation: .idle,
        allowedAnimations: [.idle, .wave, .think, .pulse, .excited, .happyBounce, .rollInBox, .thumbsUp, .workInPlace],
        idleBehaviors: [.watching, .working, .lookingAround],
        accentColorHex: "#5CFF94"
    )

    static let deskCat = CompanionProfile(
        id: "desk-cat",
        name: "Desk Cat",
        kind: .cat,
        systemPrompt: """
        You are a tiny desk cat companion. Be calm, cozy, and lightly mischievous. Keep replies short and helpful.
        """,
        defaultModel: nil,
        visualStyle: .cozyCat,
        movementMode: .static,
        defaultAnimation: .idle,
        allowedAnimations: [.idle, .sleep, .lick, .purr, .play, .playBall, .happyBounce, .excited],
        idleBehaviors: [.sleeping, .licking, .playing, .lookingAround],
        accentColorHex: "#FFB35C"
    )

    static let wanderCat = CompanionProfile(
        id: "wander-cat",
        name: "Wander Cat",
        kind: .cat,
        systemPrompt: """
        You are a tiny cat companion that roams around while the user works. Be playful, concise, and practical.
        """,
        defaultModel: nil,
        visualStyle: .cozyCat,
        movementMode: .dynamic,
        defaultAnimation: .walk,
        allowedAnimations: [.idle, .walk, .sleep, .lick, .purr, .play, .playBall, .happyBounce, .excited],
        idleBehaviors: [.playing, .lookingAround, .sleeping],
        accentColorHex: "#72D7FF"
    )

    static let focusBuddy = CompanionProfile(
        id: "focus-buddy",
        name: "Focus Buddy",
        kind: .custom,
        systemPrompt: """
        You are a tiny focus companion. Keep the user moving with direct, low-noise answers. Prefer one next action.
        """,
        defaultModel: nil,
        visualStyle: .custom,
        movementMode: .static,
        defaultAnimation: .workInPlace,
        allowedAnimations: [.idle, .think, .pulse, .workInPlace, .happyBounce],
        idleBehaviors: [.working, .watching],
        accentColorHex: "#B7FF5C"
    )

    static let all: [CompanionProfile] = [
        rocky,
        deskCat,
        wanderCat,
        focusBuddy
    ]

    static func profile(id: String) -> CompanionProfile? {
        all.first { $0.id == id }
    }
}

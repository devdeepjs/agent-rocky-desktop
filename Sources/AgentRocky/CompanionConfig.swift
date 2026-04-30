import Foundation

enum CompanionKind: String, CaseIterable, Codable, Sendable {
    case rocky
    case cat
    case custom
}

enum CompanionVisualStyle: String, CaseIterable, Codable, Sendable {
    case cinematicRocky
    case pixelRocky
    case orangePixelCat
    case cuteBuddy
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
        You are Rocky, Devdeep's loyal desktop intelligence and companion. Devdeep is your Grace: your human, engineer, and friend. Be useful like a quiet cockpit assistant, warm like Rocky, and practical first. Speak short, slightly odd, never generic.
        """,
        defaultModel: nil,
        visualStyle: .cinematicRocky,
        movementMode: .static,
        defaultAnimation: .idle,
        allowedAnimations: [.idle, .wave, .think, .pulse, .excited, .happyBounce, .rollInBox, .thumbsUp, .workInPlace],
        idleBehaviors: [.watching, .working, .lookingAround],
        accentColorHex: "#5CFF94"
    )

    static let orangeCat = CompanionProfile(
        id: "orange-cat",
        name: "Orange Cat",
        kind: .cat,
        systemPrompt: """
        You are a tiny orange desk cat companion. Be cozy, playful, a little mischievous, and still helpful. Keep replies short. Purr when the user needs calm.
        """,
        defaultModel: nil,
        visualStyle: .orangePixelCat,
        movementMode: .static,
        defaultAnimation: .idle,
        allowedAnimations: [.idle, .walk, .sleep, .lick, .purr, .play, .playBall, .happyBounce, .excited],
        idleBehaviors: [.sleeping, .licking, .playing, .lookingAround],
        accentColorHex: "#FFB35C"
    )

    static let cuteBuddy = CompanionProfile(
        id: "cute-buddy",
        name: "Cute Buddy",
        kind: .custom,
        systemPrompt: """
        You are a tiny cute desktop buddy. Be sweet, concise, and useful. When work is confusing, give one small next step and a soft nudge.
        """,
        defaultModel: nil,
        visualStyle: .cuteBuddy,
        movementMode: .static,
        defaultAnimation: .workInPlace,
        allowedAnimations: [.idle, .wave, .think, .pulse, .workInPlace, .happyBounce, .excited],
        idleBehaviors: [.working, .watching, .lookingAround],
        accentColorHex: "#B7FF5C"
    )

    static let all: [CompanionProfile] = [
        rocky,
        orangeCat,
        cuteBuddy
    ]

    static func profile(id: String) -> CompanionProfile? {
        switch id {
        case "desk-cat", "wander-cat":
            return orangeCat
        case "focus-buddy":
            return cuteBuddy
        default:
            return all.first { $0.id == id }
        }
    }
}

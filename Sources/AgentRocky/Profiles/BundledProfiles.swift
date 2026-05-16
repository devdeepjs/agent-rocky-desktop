import Foundation

enum CompanionKind: String, CaseIterable, Codable, Sendable {
    case rocky
    case cat
    case custom
}

enum CompanionVisualStyle: String, CaseIterable, Codable, Sendable {
    case cinematicRocky
    case pixelRocky
    case cartoonCat
    case cuteBuddy
}

enum CompanionMovementMode: String, CaseIterable, Codable, Sendable {
    case `static`
    case dynamic
}

enum CompanionAnimation: String, CaseIterable, Codable, Sendable {
    case idle
    case bounce
    case walk
    case wave
    case think
    case pulse
    case shake
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

enum CompanionAssetKind: String, CaseIterable, Codable, Sendable {
    case image
    case gif
}

struct CompanionVisualAsset: Codable, Equatable, Sendable {
    var kind: CompanionAssetKind
    var path: String
}

struct CompanionStateSet: Codable, Equatable, Sendable {
    var normal: CompanionAnimation
    var thinking: CompanionAnimation
    var idle: [CompanionAnimation]
    var animationAssets: [String: CompanionVisualAsset]
    var idleCooldownSeconds: Double
    var idleJitterSeconds: Double

    static let defaults = CompanionStateSet(
        normal: .idle,
        thinking: .think,
        idle: [.idle],
        animationAssets: [:],
        idleCooldownSeconds: 14,
        idleJitterSeconds: 5
    )

    init(
        normal: CompanionAnimation,
        thinking: CompanionAnimation,
        idle: [CompanionAnimation],
        animationAssets: [String: CompanionVisualAsset] = [:],
        idleCooldownSeconds: Double = 14,
        idleJitterSeconds: Double = 5
    ) {
        self.normal = normal
        self.thinking = thinking
        self.idle = idle
        self.animationAssets = animationAssets
        self.idleCooldownSeconds = idleCooldownSeconds
        self.idleJitterSeconds = idleJitterSeconds
    }
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
    var states: CompanionStateSet
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

        if !allowedAnimations.contains(states.normal) {
            issues.append("states.normal must be allowed")
        }

        if !allowedAnimations.contains(states.thinking) {
            issues.append("states.thinking must be allowed")
        }

        if states.idle.isEmpty {
            issues.append("states.idle must not be empty")
        }

        if states.idleCooldownSeconds < 3 {
            issues.append("states.idleCooldownSeconds must be at least 3")
        }

        if states.idleJitterSeconds < 0 {
            issues.append("states.idleJitterSeconds must not be negative")
        }

        let disallowedIdleStates = states.idle.filter { !allowedAnimations.contains($0) }
        if !disallowedIdleStates.isEmpty {
            issues.append("states.idle must only contain allowed animations")
        }

        let invalidAssetKeys = states.animationAssets.keys.filter { key in
            guard let animation = CompanionAnimation(rawValue: key) else {
                return true
            }

            return !allowedAnimations.contains(animation)
        }
        if !invalidAssetKeys.isEmpty {
            issues.append("states.animationAssets must only reference allowed animations")
        }

        let emptyAssetPaths = states.animationAssets.values.filter {
            $0.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if !emptyAssetPaths.isEmpty {
            issues.append("states.animationAssets paths must not be empty")
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

    func asset(for animation: CompanionAnimation) -> CompanionVisualAsset? {
        states.animationAssets[animation.rawValue]
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
        You are Rocky, a loyal desktop intelligence and companion. Be useful like a quiet cockpit assistant, warm, practical first, and slightly odd without becoming noisy. Speak short and never generic.
        """,
        defaultModel: nil,
        visualStyle: .cinematicRocky,
        movementMode: .static,
        defaultAnimation: .idle,
        allowedAnimations: [.idle, .wave, .think, .pulse, .excited, .happyBounce, .rollInBox, .thumbsUp, .workInPlace],
        states: CompanionStateSet(
            normal: .idle,
            thinking: .workInPlace,
            idle: [.idle, .wave, .pulse],
            idleCooldownSeconds: 16,
            idleJitterSeconds: 6
        ),
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
        visualStyle: .cartoonCat,
        movementMode: .static,
        defaultAnimation: .idle,
        allowedAnimations: [.idle, .walk, .think, .sleep, .lick, .purr, .play, .playBall, .happyBounce, .excited],
        states: CompanionStateSet(
            normal: .idle,
            thinking: .think,
            idle: [.sleep, .lick, .play, .purr],
            idleCooldownSeconds: 12,
            idleJitterSeconds: 8
        ),
        idleBehaviors: [.sleeping, .licking, .playing, .lookingAround],
        accentColorHex: "#FFB35C"
    )

    static let cuteBuddy = CompanionProfile(
        id: "cute-buddy",
        name: "Little Box Guy",
        kind: .custom,
        systemPrompt: """
        You are a tiny little box desktop buddy. Be sweet, concise, and useful. When work is confusing, give one small next step and a soft nudge.
        """,
        defaultModel: nil,
        visualStyle: .cuteBuddy,
        movementMode: .static,
        defaultAnimation: .workInPlace,
        allowedAnimations: [.idle, .wave, .think, .pulse, .workInPlace, .happyBounce, .excited],
        states: CompanionStateSet(
            normal: .idle,
            thinking: .workInPlace,
            idle: [.idle, .wave, .pulse],
            idleCooldownSeconds: 14,
            idleJitterSeconds: 5
        ),
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

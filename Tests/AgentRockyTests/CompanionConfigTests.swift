import XCTest
@testable import AgentRocky

final class CompanionConfigTests: XCTestCase {
    func testStandardProfilesAreValid() {
        XCTAssertFalse(StandardCompanionProfiles.all.isEmpty)

        for profile in StandardCompanionProfiles.all {
            XCTAssertTrue(profile.isValid, "\(profile.id): \(profile.validationIssues.joined(separator: ", "))")
        }
    }

    func testStandardProfilesIncludeBundledCompanions() {
        let ids = Set(StandardCompanionProfiles.all.map(\.id))

        XCTAssertEqual(ids.count, 3)
        XCTAssertTrue(ids.contains("rocky"))
        XCTAssertTrue(ids.contains("orange-cat"))
        XCTAssertTrue(ids.contains("cute-buddy"))
    }

    func testProfilesHaveDefaultMovementModes() {
        XCTAssertEqual(StandardCompanionProfiles.rocky.movementMode, .static)
        XCTAssertEqual(StandardCompanionProfiles.orangeCat.movementMode, .static)
        XCTAssertEqual(StandardCompanionProfiles.cuteBuddy.movementMode, .static)
    }

    func testCatUsesCartoonVisualStyle() {
        XCTAssertEqual(StandardCompanionProfiles.orangeCat.visualStyle, .cartoonCat)
    }

    func testAnimationFallsBackToDefaultWhenNotAllowed() {
        let profile = StandardCompanionProfiles.orangeCat

        XCTAssertEqual(profile.animationOrDefault(.lick), .lick)
        XCTAssertEqual(profile.animationOrDefault(.rollInBox), .idle)
    }

    func testOldCatProfileIdsMapToOrangeCat() {
        XCTAssertEqual(StandardCompanionProfiles.profile(id: "desk-cat")?.id, "orange-cat")
        XCTAssertEqual(StandardCompanionProfiles.profile(id: "wander-cat")?.id, "orange-cat")
    }

    func testInvalidProfileReportsUsefulIssues() {
        let profile = CompanionProfile(
            id: "",
            name: "",
            kind: .custom,
            systemPrompt: "",
            defaultModel: nil,
            visualStyle: .cuteBuddy,
            movementMode: .static,
            defaultAnimation: .walk,
            allowedAnimations: [.idle],
            states: CompanionStateSet(normal: .idle, thinking: .idle, idle: [.idle]),
            idleBehaviors: [],
            accentColorHex: "green"
        )

        XCTAssertEqual(profile.validationIssues, [
            "id is required",
            "name is required",
            "systemPrompt is required",
            "defaultAnimation must be allowed",
            "idleBehaviors must not be empty",
            "accentColorHex must be #RRGGBB"
        ])
    }

    func testStateConfigCarriesIdleTimingAndAssetMapping() {
        let states = CompanionStateSet(
            normal: .idle,
            thinking: .think,
            idle: [.wave, .pulse],
            animationAssets: [
                "wave": CompanionVisualAsset(kind: .gif, path: "wave.gif")
            ],
            idleCooldownSeconds: 9,
            idleJitterSeconds: 4
        )
        let profile = CompanionProfile(
            id: "gif-buddy",
            name: "GIF Buddy",
            kind: .custom,
            systemPrompt: "Small helper.",
            visualStyle: .cuteBuddy,
            movementMode: .static,
            defaultAnimation: .idle,
            allowedAnimations: [.idle, .wave, .pulse, .think],
            states: states,
            idleBehaviors: [.watching],
            accentColorHex: "#AABBCC"
        )

        XCTAssertTrue(profile.isValid, profile.validationIssues.joined(separator: ", "))
        XCTAssertEqual(profile.asset(for: .wave)?.kind, .gif)
        XCTAssertEqual(profile.states.idleCooldownSeconds, 9)
        XCTAssertEqual(profile.states.idleJitterSeconds, 4)
    }

    func testInvalidStateAssetAndTimingReportsUsefulIssues() {
        let profile = CompanionProfile(
            id: "bad-assets",
            name: "Bad Assets",
            kind: .custom,
            systemPrompt: "Small helper.",
            visualStyle: .cuteBuddy,
            movementMode: .static,
            defaultAnimation: .idle,
            allowedAnimations: [.idle],
            states: CompanionStateSet(
                normal: .idle,
                thinking: .idle,
                idle: [.idle],
                animationAssets: [
                    "wave": CompanionVisualAsset(kind: .image, path: ""),
                    "missing": CompanionVisualAsset(kind: .gif, path: "x.gif")
                ],
                idleCooldownSeconds: 2,
                idleJitterSeconds: -1
            ),
            idleBehaviors: [.watching],
            accentColorHex: "#AABBCC"
        )

        XCTAssertTrue(profile.validationIssues.contains("states.idleCooldownSeconds must be at least 3"))
        XCTAssertTrue(profile.validationIssues.contains("states.idleJitterSeconds must not be negative"))
        XCTAssertTrue(profile.validationIssues.contains("states.animationAssets must only reference allowed animations"))
        XCTAssertTrue(profile.validationIssues.contains("states.animationAssets paths must not be empty"))
    }
}

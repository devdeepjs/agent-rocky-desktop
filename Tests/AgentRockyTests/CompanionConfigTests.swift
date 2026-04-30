import XCTest
@testable import AgentRocky

final class CompanionConfigTests: XCTestCase {
    func testStandardProfilesAreValid() {
        XCTAssertFalse(StandardCompanionProfiles.all.isEmpty)

        for profile in StandardCompanionProfiles.all {
            XCTAssertTrue(profile.isValid, "\(profile.id): \(profile.validationIssues.joined(separator: ", "))")
        }
    }

    func testStandardProfilesIncludeRockyAndCats() {
        let ids = Set(StandardCompanionProfiles.all.map(\.id))

        XCTAssertEqual(ids.count, 3)
        XCTAssertTrue(ids.contains("rocky"))
        XCTAssertTrue(ids.contains("orange-cat"))
        XCTAssertTrue(ids.contains("cute-buddy"))
    }

    func testProfilesHaveDefaultMovementModes() {
        XCTAssertEqual(StandardCompanionProfiles.rocky.movementMode, .static)
        XCTAssertEqual(StandardCompanionProfiles.orangeCat.movementMode, .static)
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
}

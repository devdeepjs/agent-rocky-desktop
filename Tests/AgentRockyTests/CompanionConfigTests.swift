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

        XCTAssertTrue(ids.contains("rocky"))
        XCTAssertTrue(ids.contains("desk-cat"))
        XCTAssertTrue(ids.contains("wander-cat"))
    }

    func testDynamicMovementCanBeConfiguredPerProfile() {
        XCTAssertEqual(StandardCompanionProfiles.rocky.movementMode, .static)
        XCTAssertEqual(StandardCompanionProfiles.wanderCat.movementMode, .dynamic)
    }

    func testAnimationFallsBackToDefaultWhenNotAllowed() {
        let profile = StandardCompanionProfiles.deskCat

        XCTAssertEqual(profile.animationOrDefault(.lick), .lick)
        XCTAssertEqual(profile.animationOrDefault(.rollInBox), .idle)
    }

    func testInvalidProfileReportsUsefulIssues() {
        let profile = CompanionProfile(
            id: "",
            name: "",
            kind: .custom,
            systemPrompt: "",
            defaultModel: nil,
            visualStyle: .custom,
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

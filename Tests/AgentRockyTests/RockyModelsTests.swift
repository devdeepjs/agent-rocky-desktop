import XCTest
@testable import AgentRocky

final class RockyModelsTests: XCTestCase {
    func testCleanedReplacesBlankText() {
        let response = RockyBrainResponse(text: "   ", mood: .curious, animation: .idle)

        XCTAssertEqual(response.cleaned.text, "Thinking empty. Try again question.")
        XCTAssertEqual(response.cleaned.mood, .curious)
        XCTAssertEqual(response.cleaned.animation, .idle)
    }

    func testCleanedKeepsModeratelyLongText() {
        let response = RockyBrainResponse(text: String(repeating: "a", count: 400), mood: .happy, animation: .wave)

        XCTAssertEqual(response.cleaned.text.count, 400)
        XCTAssertFalse(response.cleaned.text.hasSuffix("..."))
    }

    func testCleanedTruncatesExtremelyLongText() {
        let response = RockyBrainResponse(text: String(repeating: "a", count: RockyBrainResponse.maxTextCharacters + 50), mood: .happy, animation: .wave)

        XCTAssertEqual(response.cleaned.text.count, RockyBrainResponse.maxTextCharacters)
        XCTAssertTrue(response.cleaned.text.hasSuffix("..."))
    }

    func testBrainResponseDecodesExpectedContract() throws {
        let data = Data(#"{"text":"good good good","mood":"happy","animation":"bounce"}"#.utf8)

        let response = try JSONDecoder().decode(RockyBrainResponse.self, from: data)

        XCTAssertEqual(response.text, "good good good")
        XCTAssertEqual(response.mood, .happy)
        XCTAssertEqual(response.animation, .bounce)
    }

    func testValidatedResponseKeepsAllowedProfileAnimation() {
        let response = RockyBrainResponse(text: "purr purr", mood: .happy, animation: .purr)

        let validated = response.validated(for: StandardCompanionProfiles.orangeCat)

        XCTAssertEqual(validated.animation, .purr)
    }

    func testValidatedResponseFallsBackForDisallowedProfileAnimation() {
        let response = RockyBrainResponse(text: "box", mood: .happy, animation: .rollInBox)

        let validated = response.validated(for: StandardCompanionProfiles.orangeCat)

        XCTAssertEqual(validated.animation, .idle)
    }

    func testMessageHintUsesThumbsUpForLuck() {
        let hint = RockyBrainResponse.messageAnimationHint(
            for: "Going to office, wish me luck",
            profile: StandardCompanionProfiles.rocky
        )

        XCTAssertEqual(hint, .thumbsUp)
    }

    func testMessageHintUsesExcitedForGoodNews() {
        let hint = RockyBrainResponse.messageAnimationHint(
            for: "Good news mate, we shipped it",
            profile: StandardCompanionProfiles.rocky
        )

        XCTAssertEqual(hint, .excited)
    }

    func testMessageHintUsesWorkAnimationForTasks() {
        let hint = RockyBrainResponse.messageAnimationHint(
            for: "Can you implement this task",
            profile: StandardCompanionProfiles.rocky
        )

        XCTAssertEqual(hint, .rollInBox)
    }

    func testApplyingMessageHintMarksTaskAsThinking() {
        let response = RockyBrainResponse(text: "working", mood: .happy, animation: .idle)

        let hinted = response.applyingMessageAnimationHint(
            for: "Can you implement this task",
            profile: StandardCompanionProfiles.rocky
        )

        XCTAssertEqual(hinted.mood, .thinking)
        XCTAssertEqual(hinted.animation, .rollInBox)
    }

    func testMessageHintFallsBackToAllowedProfileAnimations() {
        let hint = RockyBrainResponse.messageAnimationHint(
            for: "Good news mate, we shipped it",
            profile: StandardCompanionProfiles.orangeCat
        )

        XCTAssertEqual(hint, .excited)
    }
}

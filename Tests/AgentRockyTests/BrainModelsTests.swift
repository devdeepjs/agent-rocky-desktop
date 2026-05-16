import XCTest
@testable import AgentRocky

final class BrainModelsTests: XCTestCase {
    func testCleanedReplacesBlankText() {
        let response = BrainResponse(text: "   ", mood: .curious, animation: .idle)

        XCTAssertEqual(response.cleaned.text, "Thinking empty. Try again question.")
        XCTAssertEqual(response.cleaned.mood, .curious)
        XCTAssertEqual(response.cleaned.animation, .idle)
    }

    func testCleanedKeepsLongText() {
        let response = BrainResponse(text: String(repeating: "a", count: 5_000), mood: .happy, animation: .wave)

        XCTAssertEqual(response.cleaned.text.count, 5_000)
        XCTAssertFalse(response.cleaned.text.hasSuffix("..."))
    }

    func testBrainResponseDecodesExpectedContract() throws {
        let data = Data(#"{"text":"good good good","mood":"happy","animation":"bounce"}"#.utf8)

        let response = try JSONDecoder().decode(BrainResponse.self, from: data)

        XCTAssertEqual(response.text, "good good good")
        XCTAssertEqual(response.mood, .happy)
        XCTAssertEqual(response.animation, .bounce)
    }

    func testValidatedResponseKeepsAllowedProfileAnimation() {
        let response = BrainResponse(text: "purr purr", mood: .happy, animation: .purr)

        let validated = response.validated(for: StandardCompanionProfiles.orangeCat)

        XCTAssertEqual(validated.animation, .purr)
    }

    func testValidatedResponseFallsBackForDisallowedProfileAnimation() {
        let response = BrainResponse(text: "box", mood: .happy, animation: .rollInBox)

        let validated = response.validated(for: StandardCompanionProfiles.orangeCat)

        XCTAssertEqual(validated.animation, .idle)
    }

    func testMessageHintUsesThumbsUpForLuck() {
        let hint = BrainResponse.messageAnimationHint(
            for: "Going to office, wish me luck",
            profile: StandardCompanionProfiles.rocky
        )

        XCTAssertEqual(hint, .thumbsUp)
    }

    func testMessageHintUsesExcitedForGoodNews() {
        let hint = BrainResponse.messageAnimationHint(
            for: "Good news mate, we shipped it",
            profile: StandardCompanionProfiles.rocky
        )

        XCTAssertEqual(hint, .excited)
    }

    func testMessageHintUsesWorkAnimationForTasks() {
        let hint = BrainResponse.messageAnimationHint(
            for: "Can you implement this task",
            profile: StandardCompanionProfiles.rocky
        )

        XCTAssertEqual(hint, .rollInBox)
    }

    func testApplyingMessageHintMarksTaskAsThinking() {
        let response = BrainResponse(text: "working", mood: .happy, animation: .idle)

        let hinted = response.applyingMessageAnimationHint(
            for: "Can you implement this task",
            profile: StandardCompanionProfiles.rocky
        )

        XCTAssertEqual(hinted.mood, .thinking)
        XCTAssertEqual(hinted.animation, .rollInBox)
    }

    func testMessageHintFallsBackToAllowedProfileAnimations() {
        let hint = BrainResponse.messageAnimationHint(
            for: "Good news mate, we shipped it",
            profile: StandardCompanionProfiles.orangeCat
        )

        XCTAssertEqual(hint, .excited)
    }

    func testOpenAIProviderHasDefaultModelChoice() {
        XCTAssertEqual(BrainProvider.openAI.defaultModel, "gpt-5.4-mini")
        XCTAssertTrue(BrainProvider.openAI.modelChoices.contains("gpt-5.5"))
        XCTAssertTrue(BrainProvider.openAI.modelChoices.contains("gpt-5.4-mini"))
    }

    func testDeepSeekUsesOfficialBaseURLAndCurrentChoices() {
        XCTAssertEqual(BrainProvider.deepSeek.defaultBaseURL, "https://api.deepseek.com")
        XCTAssertEqual(BrainProvider.deepSeek.defaultModel, "deepseek-v4-flash")
        XCTAssertTrue(BrainProvider.deepSeek.modelChoices.contains("deepseek-v4-pro"))
    }
}

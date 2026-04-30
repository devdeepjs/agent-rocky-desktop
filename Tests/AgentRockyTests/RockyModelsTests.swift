import XCTest
@testable import AgentRocky

final class RockyModelsTests: XCTestCase {
    func testCleanedReplacesBlankText() {
        let response = RockyBrainResponse(text: "   ", mood: .curious, animation: .idle)

        XCTAssertEqual(response.cleaned.text, "Thinking empty. Try again question.")
        XCTAssertEqual(response.cleaned.mood, .curious)
        XCTAssertEqual(response.cleaned.animation, .idle)
    }

    func testCleanedTruncatesLongText() {
        let response = RockyBrainResponse(text: String(repeating: "a", count: 400), mood: .happy, animation: .wave)

        XCTAssertEqual(response.cleaned.text.count, 320)
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
}

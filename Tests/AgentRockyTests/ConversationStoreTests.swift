import XCTest
@testable import AgentRocky

final class ConversationStoreTests: XCTestCase {
    private var rootURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-rocky-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: rootURL)
        rootURL = nil
        try super.tearDownWithError()
    }

    func testLoadStateCreatesInitialConversation() {
        let store = ConversationStore(rootURL: rootURL)

        let state = store.loadState()

        XCTAssertEqual(state.active.title, "New chat")
        XCTAssertEqual(state.active.profileID, "rocky")
        XCTAssertEqual(state.summaries.count, 1)
        XCTAssertEqual(state.summaries.first?.id, state.active.id)
    }

    func testNewConversationDoesNotDeletePreviousConversation() {
        let store = ConversationStore(rootURL: rootURL)
        let first = store.loadState().active

        let secondState = store.createConversation(profileID: "orange-cat", model: "default")

        XCTAssertNotEqual(first.id, secondState.active.id)
        XCTAssertEqual(secondState.active.profileID, "orange-cat")
        XCTAssertEqual(secondState.summaries.count, 2)
        XCTAssertNotNil(store.selectConversation(id: first.id))
    }

    func testSelectConversationRestoresSessionHistoryAndTerminalLines() {
        let store = ConversationStore(rootURL: rootURL)
        var first = store.loadState().active
        first.codexSessionID = "11111111-1111-1111-1111-111111111111"
        first.terminalLines = ["agent rocky v0.3", "> hi", "rocky: yes"]
        first.history = [ChatTurn(user: "hi", assistant: "yes")]
        store.saveConversation(first)
        _ = store.createConversation(profileID: "orange-cat")

        let selected = store.selectConversation(id: first.id)

        XCTAssertEqual(selected?.active.codexSessionID, "11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(selected?.active.terminalLines, ["agent rocky v0.3", "> hi", "rocky: yes"])
        XCTAssertEqual(selected?.active.history, [ChatTurn(user: "hi", assistant: "yes")])
    }

    func testDeleteConversationFallsBackToRemainingConversation() {
        let store = ConversationStore(rootURL: rootURL)
        let first = store.loadState().active
        let second = store.createConversation(profileID: "orange-cat").active

        let state = store.deleteConversation(id: second.id)

        XCTAssertEqual(state.active.id, first.id)
        XCTAssertEqual(state.summaries.count, 1)
    }

    func testPreferencesRoundTrip() {
        let store = ConversationStore(rootURL: rootURL)
        let preferences = AppPreferences(
            brainProvider: .openAI,
            model: "gpt-5.4-mini",
            baseURL: "https://api.openai.com/v1",
            agentPrompt: "You are a tiny useful app."
        )

        store.savePreferences(preferences)

        XCTAssertEqual(store.loadPreferences(), preferences)
    }

    func testLegacySettingsStillLoadDefaultPreferences() throws {
        let data = Data(#"{"activeConversationID":"missing"}"#.utf8)
        try data.write(to: rootURL.appendingPathComponent("settings.json"))
        let store = ConversationStore(rootURL: rootURL)

        XCTAssertEqual(store.loadPreferences(), .defaults)
    }

    func testLegacyMemoryJsonMigratesToConversation() throws {
        let legacy = LegacyMemorySnapshot(
            sessionID: "22222222-2222-2222-2222-222222222222",
            terminalLines: ["agent rocky v0.2", "> old", "rocky: chat"],
            history: [ChatTurn(user: "old question", assistant: "chat")]
        )
        let data = try JSONEncoder().encode(legacy)
        try data.write(to: rootURL.appendingPathComponent("memory.json"))

        let state = ConversationStore(rootURL: rootURL).loadState()

        XCTAssertEqual(state.active.title, "old question")
        XCTAssertEqual(state.active.codexSessionID, "22222222-2222-2222-2222-222222222222")
        XCTAssertEqual(state.active.terminalLines, ["agent rocky v0.2", "> old", "rocky: chat"])
        XCTAssertEqual(state.active.history, [ChatTurn(user: "old question", assistant: "chat")])
    }

    func testCustomProfilesLoadFromProfilesDirectory() throws {
        let profilesURL = rootURL.appendingPathComponent("profiles", isDirectory: true)
        try FileManager.default.createDirectory(at: profilesURL, withIntermediateDirectories: true)
        let profile = CompanionProfile(
            id: "tiny-cloud",
            name: "Tiny Cloud",
            kind: .custom,
            systemPrompt: "You are a tiny cloud companion.",
            defaultModel: nil,
            visualStyle: .cuteBuddy,
            movementMode: .static,
            defaultAnimation: .idle,
            allowedAnimations: [.idle, .wave, .think],
            states: CompanionStateSet(normal: .idle, thinking: .think, idle: [.idle, .wave]),
            idleBehaviors: [.watching],
            accentColorHex: "#99CCFF"
        )
        let data = try JSONEncoder().encode(profile)
        try data.write(to: profilesURL.appendingPathComponent("tiny-cloud.json"))

        let store = ConversationStore(rootURL: rootURL)

        XCTAssertEqual(store.loadCustomProfiles().map(\.id), ["tiny-cloud"])
    }
}

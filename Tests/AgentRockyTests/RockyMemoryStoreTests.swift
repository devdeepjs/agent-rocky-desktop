import XCTest
@testable import AgentRocky

final class RockyMemoryStoreTests: XCTestCase {
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
        let store = RockyMemoryStore(rootURL: rootURL)

        let state = store.loadState()

        XCTAssertEqual(state.active.title, "New chat")
        XCTAssertEqual(state.active.profileID, "rocky")
        XCTAssertEqual(state.summaries.count, 1)
        XCTAssertEqual(state.summaries.first?.id, state.active.id)
    }

    func testNewConversationDoesNotDeletePreviousConversation() {
        let store = RockyMemoryStore(rootURL: rootURL)
        let first = store.loadState().active

        let secondState = store.createConversation(profileID: "desk-cat", model: "default")

        XCTAssertNotEqual(first.id, secondState.active.id)
        XCTAssertEqual(secondState.active.profileID, "desk-cat")
        XCTAssertEqual(secondState.summaries.count, 2)
        XCTAssertNotNil(store.selectConversation(id: first.id))
    }

    func testSelectConversationRestoresSessionHistoryAndTerminalLines() {
        let store = RockyMemoryStore(rootURL: rootURL)
        var first = store.loadState().active
        first.codexSessionID = "11111111-1111-1111-1111-111111111111"
        first.terminalLines = ["agent rocky v0.3", "> hi", "rocky: yes"]
        first.history = [ChatTurn(user: "hi", rocky: "yes")]
        store.saveConversation(first)
        _ = store.createConversation(profileID: "desk-cat")

        let selected = store.selectConversation(id: first.id)

        XCTAssertEqual(selected?.active.codexSessionID, "11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(selected?.active.terminalLines, ["agent rocky v0.3", "> hi", "rocky: yes"])
        XCTAssertEqual(selected?.active.history, [ChatTurn(user: "hi", rocky: "yes")])
    }

    func testDeleteConversationFallsBackToRemainingConversation() {
        let store = RockyMemoryStore(rootURL: rootURL)
        let first = store.loadState().active
        let second = store.createConversation(profileID: "desk-cat").active

        let state = store.deleteConversation(id: second.id)

        XCTAssertEqual(state.active.id, first.id)
        XCTAssertEqual(state.summaries.count, 1)
    }

    func testLegacyMemoryJsonMigratesToConversation() throws {
        let legacy = RockyMemorySnapshot(
            sessionID: "22222222-2222-2222-2222-222222222222",
            terminalLines: ["agent rocky v0.2", "> old", "rocky: chat"],
            history: [ChatTurn(user: "old question", rocky: "chat")]
        )
        let data = try JSONEncoder().encode(legacy)
        try data.write(to: rootURL.appendingPathComponent("memory.json"))

        let state = RockyMemoryStore(rootURL: rootURL).loadState()

        XCTAssertEqual(state.active.title, "old question")
        XCTAssertEqual(state.active.codexSessionID, "22222222-2222-2222-2222-222222222222")
        XCTAssertEqual(state.active.terminalLines, ["agent rocky v0.2", "> old", "rocky: chat"])
        XCTAssertEqual(state.active.history, [ChatTurn(user: "old question", rocky: "chat")])
    }
}

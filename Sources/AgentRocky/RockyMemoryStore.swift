import Foundation

struct RockyMemorySnapshot: Codable, Equatable {
    var sessionID: String?
    var terminalLines: [String]
    var history: [ChatTurn]
}

struct RockyConversation: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var codexSessionID: String?
    var profileID: String
    var model: String
    var terminalLines: [String]
    var history: [ChatTurn]

    var summary: RockyConversationSummary {
        RockyConversationSummary(
            id: id,
            title: title,
            updatedAt: updatedAt,
            profileID: profileID
        )
    }

    static func fresh(profileID: String = "rocky", model: String = "", now: Date = Date()) -> RockyConversation {
        RockyConversation(
            id: UUID().uuidString.lowercased(),
            title: "New chat",
            createdAt: now,
            updatedAt: now,
            codexSessionID: nil,
            profileID: profileID,
            model: model,
            terminalLines: [
                "agent rocky v0.3",
                "new chat"
            ],
            history: []
        )
    }
}

struct RockyConversationSummary: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var title: String
    var updatedAt: Date
    var profileID: String
}

struct RockyConversationState: Equatable {
    var active: RockyConversation
    var summaries: [RockyConversationSummary]
}

private struct RockySettings: Codable {
    var activeConversationID: String?
}

final class RockyMemoryStore {
    private let rootURL: URL
    private let legacyFileURL: URL
    private let settingsURL: URL
    private let conversationsURL: URL
    private let profilesURL: URL

    init(rootURL: URL? = nil) {
        if let rootURL {
            self.rootURL = rootURL
        } else {
            let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
            self.rootURL = baseURL.appendingPathComponent("AgentRocky", isDirectory: true)
        }

        legacyFileURL = self.rootURL.appendingPathComponent("memory.json")
        settingsURL = self.rootURL.appendingPathComponent("settings.json")
        conversationsURL = self.rootURL.appendingPathComponent("conversations", isDirectory: true)
        profilesURL = self.rootURL.appendingPathComponent("profiles", isDirectory: true)

        createDirectories()
    }

    func loadState() -> RockyConversationState {
        migrateLegacyMemoryIfNeeded()

        if let active = loadActiveConversation() {
            return RockyConversationState(active: active, summaries: listSummaries())
        }

        let conversation = RockyConversation.fresh()
        saveConversation(conversation, makeActive: true)
        return RockyConversationState(active: conversation, summaries: listSummaries())
    }

    func createConversation(profileID: String = "rocky", model: String = "") -> RockyConversationState {
        var conversation = RockyConversation.fresh(profileID: profileID, model: model)
        conversation.title = "New chat"
        saveConversation(conversation, makeActive: true)
        return RockyConversationState(active: conversation, summaries: listSummaries())
    }

    func saveConversation(_ conversation: RockyConversation, makeActive: Bool = true) {
        createDirectories()

        guard let data = try? encoder.encode(conversation) else {
            return
        }

        try? data.write(to: conversationURL(id: conversation.id), options: [.atomic])

        if makeActive {
            saveSettings(RockySettings(activeConversationID: conversation.id))
        }
    }

    func selectConversation(id: String) -> RockyConversationState? {
        guard let conversation = loadConversation(id: id) else {
            return nil
        }

        saveSettings(RockySettings(activeConversationID: id))
        return RockyConversationState(active: conversation, summaries: listSummaries())
    }

    func deleteConversation(id: String) -> RockyConversationState {
        try? FileManager.default.removeItem(at: conversationURL(id: id))

        if let next = listSummaries().first,
           let conversation = loadConversation(id: next.id) {
            saveSettings(RockySettings(activeConversationID: conversation.id))
            return RockyConversationState(active: conversation, summaries: listSummaries())
        }

        return createConversation()
    }

    func listSummaries() -> [RockyConversationSummary] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: conversationsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        return urls
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> RockyConversationSummary? in
                guard let data = try? Data(contentsOf: url),
                      let conversation = try? decoder.decode(RockyConversation.self, from: data) else {
                    return nil
                }

                return conversation.summary
            }
            .sorted { left, right in
                left.updatedAt > right.updatedAt
            }
    }

    private func loadActiveConversation() -> RockyConversation? {
        if let activeID = loadSettings().activeConversationID,
           let conversation = loadConversation(id: activeID) {
            return conversation
        }

        guard let first = listSummaries().first else {
            return nil
        }

        return loadConversation(id: first.id)
    }

    private func loadConversation(id: String) -> RockyConversation? {
        guard let data = try? Data(contentsOf: conversationURL(id: id)) else {
            return nil
        }

        return try? decoder.decode(RockyConversation.self, from: data)
    }

    private func migrateLegacyMemoryIfNeeded() {
        guard listSummaries().isEmpty,
              let data = try? Data(contentsOf: legacyFileURL),
              let snapshot = try? decoder.decode(RockyMemorySnapshot.self, from: data) else {
            return
        }

        let now = Date()
        var conversation = RockyConversation(
            id: UUID().uuidString.lowercased(),
            title: Self.title(from: snapshot.history) ?? "Imported chat",
            createdAt: now,
            updatedAt: now,
            codexSessionID: snapshot.sessionID,
            profileID: "rocky",
            model: "",
            terminalLines: snapshot.terminalLines.isEmpty ? ["agent rocky v0.3", "imported chat"] : snapshot.terminalLines,
            history: snapshot.history
        )

        if conversation.title == "New chat" {
            conversation.title = "Imported chat"
        }

        saveConversation(conversation, makeActive: true)
    }

    private static func title(from history: [ChatTurn]) -> String? {
        guard let first = history.first?.user.trimmingCharacters(in: .whitespacesAndNewlines),
              !first.isEmpty else {
            return nil
        }

        if first.count <= 34 {
            return first
        }

        return String(first.prefix(31)) + "..."
    }

    private func loadSettings() -> RockySettings {
        guard let data = try? Data(contentsOf: settingsURL),
              let settings = try? decoder.decode(RockySettings.self, from: data) else {
            return RockySettings(activeConversationID: nil)
        }

        return settings
    }

    private func saveSettings(_ settings: RockySettings) {
        guard let data = try? encoder.encode(settings) else {
            return
        }

        try? data.write(to: settingsURL, options: [.atomic])
    }

    private func createDirectories() {
        try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: conversationsURL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: profilesURL, withIntermediateDirectories: true)
    }

    private func conversationURL(id: String) -> URL {
        conversationsURL.appendingPathComponent("\(id).json")
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

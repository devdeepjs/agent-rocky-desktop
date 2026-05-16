import Foundation

struct LegacyMemorySnapshot: Codable, Equatable {
    var sessionID: String?
    var terminalLines: [String]
    var history: [ChatTurn]
}

struct CompanionConversation: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var codexSessionID: String?
    var profileID: String
    var movementMode: CompanionMovementMode?
    var model: String
    var terminalLines: [String]
    var history: [ChatTurn]

    var summary: ConversationSummary {
        ConversationSummary(
            id: id,
            title: title,
            updatedAt: updatedAt,
            profileID: profileID
        )
    }

    static func fresh(profileID: String = "rocky", model: String = "", now: Date = Date()) -> CompanionConversation {
        CompanionConversation(
            id: UUID().uuidString.lowercased(),
            title: "New chat",
            createdAt: now,
            updatedAt: now,
            codexSessionID: nil,
            profileID: profileID,
            movementMode: nil,
            model: model,
            terminalLines: [
                "agent rocky v0.3",
                "new chat"
            ],
            history: []
        )
    }
}

struct ConversationSummary: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var title: String
    var updatedAt: Date
    var profileID: String
}

struct ConversationState: Equatable {
    var active: CompanionConversation
    var summaries: [ConversationSummary]
}

private struct StoredSettings: Codable {
    var activeConversationID: String?
    var brainProvider: BrainProvider?
    var model: String?
    var baseURL: String?
    var agentPrompt: String?
}

final class ConversationStore {
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

    func loadState() -> ConversationState {
        migrateLegacyMemoryIfNeeded()

        if let active = loadActiveConversation() {
            return ConversationState(active: active, summaries: listSummaries())
        }

        let conversation = CompanionConversation.fresh()
        saveConversation(conversation, makeActive: true)
        return ConversationState(active: conversation, summaries: listSummaries())
    }

    func createConversation(profileID: String = "rocky", model: String = "") -> ConversationState {
        var conversation = CompanionConversation.fresh(profileID: profileID, model: model)
        conversation.title = "New chat"
        saveConversation(conversation, makeActive: true)
        return ConversationState(active: conversation, summaries: listSummaries())
    }

    func saveConversation(_ conversation: CompanionConversation, makeActive: Bool = true) {
        createDirectories()

        guard let data = try? encoder.encode(conversation) else {
            return
        }

        try? data.write(to: conversationURL(id: conversation.id), options: [.atomic])

        if makeActive {
            var settings = loadSettings()
            settings.activeConversationID = conversation.id
            saveSettings(settings)
        }
    }

    func selectConversation(id: String) -> ConversationState? {
        guard let conversation = loadConversation(id: id) else {
            return nil
        }

        var settings = loadSettings()
        settings.activeConversationID = id
        saveSettings(settings)
        return ConversationState(active: conversation, summaries: listSummaries())
    }

    func deleteConversation(id: String) -> ConversationState {
        try? FileManager.default.removeItem(at: conversationURL(id: id))

        if let next = listSummaries().first,
           let conversation = loadConversation(id: next.id) {
            var settings = loadSettings()
            settings.activeConversationID = conversation.id
            saveSettings(settings)
            return ConversationState(active: conversation, summaries: listSummaries())
        }

        return createConversation()
    }

    func loadPreferences() -> AppPreferences {
        let settings = loadSettings()
        return AppPreferences(
            brainProvider: settings.brainProvider ?? .codexCLI,
            model: settings.model ?? "",
            baseURL: settings.baseURL ?? "",
            agentPrompt: settings.agentPrompt ?? ""
        )
    }

    func savePreferences(_ preferences: AppPreferences) {
        var settings = loadSettings()
        settings.brainProvider = preferences.brainProvider
        settings.model = preferences.model
        settings.baseURL = preferences.baseURL
        settings.agentPrompt = preferences.agentPrompt
        saveSettings(settings)
    }

    func listSummaries() -> [ConversationSummary] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: conversationsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        return urls
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> ConversationSummary? in
                guard let data = try? Data(contentsOf: url),
                      let conversation = try? decoder.decode(CompanionConversation.self, from: data) else {
                    return nil
                }

                return conversation.summary
            }
            .sorted { left, right in
                left.updatedAt > right.updatedAt
            }
    }

    func loadCustomProfiles() -> [CompanionProfile] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: profilesURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        return urls
            .filter { $0.pathExtension == "json" }
            .flatMap { url -> [CompanionProfile] in
                guard let data = try? Data(contentsOf: url) else {
                    return []
                }

                if let profiles = try? decoder.decode([CompanionProfile].self, from: data) {
                    return profiles.filter(\.isValid)
                }

                if let profile = try? decoder.decode(CompanionProfile.self, from: data),
                   profile.isValid {
                    return [profile]
                }

                return []
            }
    }

    private func loadActiveConversation() -> CompanionConversation? {
        if let activeID = loadSettings().activeConversationID,
           let conversation = loadConversation(id: activeID) {
            return conversation
        }

        guard let first = listSummaries().first else {
            return nil
        }

        return loadConversation(id: first.id)
    }

    private func loadConversation(id: String) -> CompanionConversation? {
        guard let data = try? Data(contentsOf: conversationURL(id: id)) else {
            return nil
        }

        return try? decoder.decode(CompanionConversation.self, from: data)
    }

    private func migrateLegacyMemoryIfNeeded() {
        guard listSummaries().isEmpty,
              let data = try? Data(contentsOf: legacyFileURL),
              let snapshot = try? decoder.decode(LegacyMemorySnapshot.self, from: data) else {
            return
        }

        let now = Date()
        var conversation = CompanionConversation(
            id: UUID().uuidString.lowercased(),
            title: Self.title(from: snapshot.history) ?? "Imported chat",
            createdAt: now,
            updatedAt: now,
            codexSessionID: snapshot.sessionID,
            profileID: "rocky",
            movementMode: nil,
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

    private func loadSettings() -> StoredSettings {
        guard let data = try? Data(contentsOf: settingsURL),
              let settings = try? decoder.decode(StoredSettings.self, from: data) else {
            return StoredSettings(activeConversationID: nil, brainProvider: nil, model: nil, baseURL: nil, agentPrompt: nil)
        }

        return settings
    }

    private func saveSettings(_ settings: StoredSettings) {
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

import Foundation

struct RockyMemorySnapshot: Codable {
    var sessionID: String?
    var terminalLines: [String]
    var history: [ChatTurn]
}

final class RockyMemoryStore {
    private let fileURL: URL

    init() {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let directory = baseURL.appendingPathComponent("AgentRocky", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("memory.json")
    }

    func load() -> RockyMemorySnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        return try? JSONDecoder().decode(RockyMemorySnapshot.self, from: data)
    }

    func save(_ snapshot: RockyMemorySnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else {
            return
        }

        try? data.write(to: fileURL, options: [.atomic])
    }

    func reset() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}

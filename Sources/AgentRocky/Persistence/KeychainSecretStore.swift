import Foundation
import Security

enum KeychainSecretStore {
    private static let service = "AgentRocky.ProviderSecrets"
    private static let legacyOpenAIService = "AgentRocky.OpenAI"
    private static let legacyOpenAIAccount = "api-key"

    static func readAPIKey(for provider: BrainProvider) -> String {
        if let key = read(service: service, account: provider.rawValue) {
            return key
        }

        if provider == .openAI,
           let key = read(service: legacyOpenAIService, account: legacyOpenAIAccount) {
            return key
        }

        return ""
    }

    static func saveAPIKey(_ key: String, for provider: BrainProvider) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            deleteAPIKey(for: provider)
            return
        }

        let data = Data(trimmed.utf8)
        let query = baseQuery(service: service, account: provider.rawValue)
        let update: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    static func deleteAPIKey(for provider: BrainProvider) {
        SecItemDelete(baseQuery(service: service, account: provider.rawValue) as CFDictionary)
    }

    private static func read(service: String, account: String) -> String? {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    private static func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

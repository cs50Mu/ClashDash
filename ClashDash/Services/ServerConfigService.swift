import Foundation
import Security

struct ServerConfigService {
    private static let serversKey = "mihomo.servers"
    private static let activeServerIdKey = "mihomo.activeServerId"
    private static let keychainService = "com.clashdash.mihomo"

    // MARK: - Servers

    func loadServers() -> [ServerConfig] {
        guard let data = UserDefaults.standard.data(forKey: Self.serversKey) else {
            return []
        }
        return (try? JSONDecoder().decode([ServerConfig].self, from: data)) ?? []
    }

    func saveServers(_ servers: [ServerConfig]) {
        guard let data = try? JSONEncoder().encode(servers) else { return }
        UserDefaults.standard.set(data, forKey: Self.serversKey)
    }

    var activeServerId: UUID? {
        get {
            guard let uuidString = UserDefaults.standard.string(forKey: Self.activeServerIdKey) else {
                return nil
            }
            return UUID(uuidString: uuidString)
        }
        set {
            if let id = newValue {
                UserDefaults.standard.set(id.uuidString, forKey: Self.activeServerIdKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.activeServerIdKey)
            }
        }
    }

    func loadActiveServer() -> ServerConfig? {
        guard let id = activeServerId else { return nil }
        return loadServers().first { $0.id == id }
    }

    // MARK: - Keychain

    func loadSecret(for serverId: UUID) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: serverId.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let secret = String(data: data, encoding: .utf8) else {
            return ""
        }
        return secret
    }

    func saveSecret(_ secret: String, for serverId: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: serverId.uuidString
        ]
        SecItemDelete(query as CFDictionary)

        guard let data = secret.data(using: .utf8) else { return }
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: serverId.uuidString,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    func deleteSecret(for serverId: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: serverId.uuidString
        ]
        SecItemDelete(query as CFDictionary)
    }
}

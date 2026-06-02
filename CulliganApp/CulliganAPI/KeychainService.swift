import Foundation
import Security

/// Keychain-based storage for authentication tokens and credentials.
/// Uses kSecClassGenericPassword items scoped to the app's bundle identifier.
enum KeychainService {
    private static let service = Bundle.main.bundleIdentifier ?? "com.culligan.app"

    // MARK: - Auth State (tokens)

    static func saveAuthState(_ state: AuthState) throws {
        let data = try JSONEncoder().encode(state)
        try save(data: data, account: "auth_state")
    }

    static func loadAuthState() -> AuthState? {
        guard let data = load(account: "auth_state") else { return nil }
        return try? JSONDecoder().decode(AuthState.self, from: data)
    }

    static func deleteAuthState() {
        delete(account: "auth_state")
    }

    // MARK: - Credentials (for background refresh re-auth)

    static func saveCredentials(email: String, password: String) throws {
        let creds = ["email": email, "password": password]
        let data = try JSONEncoder().encode(creds)
        try save(data: data, account: "credentials")
    }

    static func loadCredentials() -> (email: String, password: String)? {
        guard let data = load(account: "credentials"),
              let dict = try? JSONDecoder().decode([String: String].self, from: data),
              let email = dict["email"],
              let password = dict["password"] else {
            return nil
        }
        return (email, password)
    }

    static func deleteCredentials() {
        delete(account: "credentials")
    }

    static func deleteAll() {
        deleteAuthState()
        deleteCredentials()
    }

    // MARK: - Generic Keychain Operations

    private static func save(data: Data, account: String) throws {
        // Delete existing item first
        delete(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private static func load(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Keychain save failed with status: \(status)"
        }
    }
}

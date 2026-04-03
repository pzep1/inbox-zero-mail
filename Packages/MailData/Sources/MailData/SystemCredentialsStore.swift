import Foundation
import MailCore
import ProviderCore
import Security

public struct SystemCredentialsStore: CredentialsStore {
    private let service = "com.getinboxzero.InboxZeroMail.credentials"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() {}

    public func save(session: ProviderSession, for accountID: MailAccountID) throws {
        let data = try encoder.encode(session)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID.rawValue,
        ]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        var createQuery = baseQuery
        createQuery[kSecValueData as String] = data
        let addStatus = SecItemAdd(createQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw MailProviderError.transport("Failed to write provider credentials to the Keychain: \(addStatus)")
        }
    }

    public func load(accountID: MailAccountID) throws -> ProviderSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID.rawValue,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw MailProviderError.transport("Failed to load provider credentials from the Keychain: \(status)")
        }
        return try decoder.decode(ProviderSession.self, from: data)
    }

    public func delete(accountID: MailAccountID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID.rawValue,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw MailProviderError.transport("Failed to delete provider credentials from the Keychain: \(status)")
        }
    }
}

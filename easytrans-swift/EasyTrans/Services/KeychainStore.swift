import Foundation
import Security

/// 云端 Token 存储。
/// - Debug：使用 UserDefaults，避免 Xcode 未签名构建反复弹出「登录钥匙串」密码框
/// - Release：使用系统钥匙串，并设置 `kSecAttrAccessibleAfterFirstUnlock`
enum KeychainStore {
    private static let service = "com.easytrans.pro.credentials"
    private static let defaultsPrefix = "com.easytrans.pro.credentials."
    private static let migrationKey = "com.easytrans.pro.credentials.storage.v2"

    enum Account: String {
        case accessToken
        case refreshToken
        case accountEmail
    }

    /// 应用启动时调用一次，清理旧版钥匙串条目（无 accessibility 属性，易触发密码弹窗）。
    static func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        clearKeychainOnly()
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    static func save(_ value: String, account: Account) throws {
        if prefersUserDefaults {
            UserDefaults.standard.set(value, forKey: defaultsKey(account))
            return
        }

        let data = Data(value.utf8)
        deleteKeychainItem(account: account)

        let query = keychainQuery(account: account, includeAccessible: true)
        var addQuery = query
        addQuery[kSecValueData as String] = data

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }
    }

    static func load(account: Account) -> String? {
        if prefersUserDefaults {
            return UserDefaults.standard.string(forKey: defaultsKey(account))
        }

        var query = keychainQuery(account: account, includeAccessible: false)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    static func delete(account: Account) {
        if prefersUserDefaults {
            UserDefaults.standard.removeObject(forKey: defaultsKey(account))
        }
        deleteKeychainItem(account: account)
    }

    static func clearSession() {
        delete(account: .accessToken)
        delete(account: .refreshToken)
        delete(account: .accountEmail)
    }

    // MARK: - Private

    #if DEBUG
    private static let prefersUserDefaults = true
    #else
    private static let prefersUserDefaults = false
    #endif

    private static func defaultsKey(_ account: Account) -> String {
        defaultsPrefix + account.rawValue
    }

    private static func keychainQuery(account: Account, includeAccessible: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue
        ]
        if includeAccessible {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        }
        return query
    }

    private static func deleteKeychainItem(account: Account) {
        let query = keychainQuery(account: account, includeAccessible: false)
        SecItemDelete(query as CFDictionary)
    }

    private static func clearKeychainOnly() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: LocalizedError {
    case unhandled(OSStatus)

    var errorDescription: String? {
        switch self {
        case let .unhandled(status):
            return "钥匙串写入失败 (\(status))"
        }
    }
}

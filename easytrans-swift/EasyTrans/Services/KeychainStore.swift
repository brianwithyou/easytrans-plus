import Foundation
import Security

/// 云端 Token 存储。
/// - Debug / 本机未签名 Release：使用 UserDefaults，避免钥匙串权限问题
/// - 正式签名的 Release：使用系统钥匙串
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

    static func save(_ value: String, account: Account) {
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
            // 本机 ad-hoc 构建常见 -34018 (errSecMissingEntitlement)，降级到 UserDefaults。
            UserDefaults.standard.set(value, forKey: defaultsKey(account))
            return
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
        if status == errSecSuccess,
           let data = item as? Data,
           let value = String(data: data, encoding: .utf8) {
            return value
        }

        return UserDefaults.standard.string(forKey: defaultsKey(account))
    }

    static func delete(account: Account) {
        UserDefaults.standard.removeObject(forKey: defaultsKey(account))
        deleteKeychainItem(account: account)
    }

    static func clearSession() {
        delete(account: .accessToken)
        delete(account: .refreshToken)
        delete(account: .accountEmail)
    }

    // MARK: - Private

    private static let prefersUserDefaults: Bool = {
        #if DEBUG
        return true
        #else
        return !hasDevelopmentTeamSignature
        #endif
    }()

    /// 未配置 Development Team 的本地 Release 构建无法可靠使用钥匙串。
    private static var hasDevelopmentTeamSignature: Bool {
        guard let executableURL = Bundle.main.executableURL else { return false }

        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(executableURL as CFURL, [], &staticCode) == errSecSuccess,
              let staticCode else {
            return false
        }

        var signingInformation: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSDynamicInformation | kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(staticCode, flags, &signingInformation) == errSecSuccess,
              let info = signingInformation as? [String: Any] else {
            return false
        }

        if let teamID = info[kSecCodeInfoTeamIdentifier as String] as? String, !teamID.isEmpty {
            return true
        }
        return false
    }

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

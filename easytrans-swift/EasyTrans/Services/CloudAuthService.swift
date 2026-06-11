import Foundation

@MainActor
final class CloudAuthService: ObservableObject {
    static let shared = CloudAuthService()

    @Published private(set) var isLoggedIn = false

    private init() {
        isLoggedIn = hasStoredSession
    }

    var hasStoredSession: Bool {
        guard let token = KeychainStore.load(account: .accessToken) else { return false }
        return !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func restoreSession(into settings: AppSettings) async {
        guard hasStoredSession else {
            isLoggedIn = false
            settings.cloudAccount = nil
            return
        }

        isLoggedIn = true
        if let email = KeychainStore.load(account: .accountEmail) {
            settings.cloudAccount = CloudAccount(email: email, planName: "标准版", dailyQuota: nil, dailyUsed: nil)
        }

        let client = CloudAPIClient(baseURL: settings.cloudBaseURL)
        do {
            let profile = try await client.fetchProfile()
            let email = profile.email ?? KeychainStore.load(account: .accountEmail) ?? ""
            settings.cloudAccount = profile.toCloudAccount(fallbackEmail: email)
            if !email.isEmpty {
                try? KeychainStore.save(email, account: .accountEmail)
            }
            isLoggedIn = true
        } catch {
            // 保留本地登录态，等待用户手动刷新或下次翻译时自动 refresh。
        }
    }

    func login(email: String, password: String, settings: AppSettings) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            throw TranslationError.httpError(status: 400, message: "请输入邮箱和密码")
        }

        let client = CloudAPIClient(baseURL: settings.cloudBaseURL)
        let response = try await client.login(email: trimmedEmail, password: password)
        try persistSession(response: response, email: trimmedEmail)
        settings.cloudAccount = response.toCloudAccount(fallbackEmail: trimmedEmail)
        isLoggedIn = true
    }

    func register(email: String, password: String, settings: AppSettings) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            throw TranslationError.httpError(status: 400, message: "请输入邮箱和密码")
        }

        let client = CloudAPIClient(baseURL: settings.cloudBaseURL)
        let response = try await client.register(email: trimmedEmail, password: password)
        try persistSession(response: response, email: trimmedEmail)
        settings.cloudAccount = response.toCloudAccount(fallbackEmail: trimmedEmail)
        isLoggedIn = true
    }

    func activateLicense(_ licenseKey: String, settings: AppSettings) async throws {
        let trimmedKey = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw TranslationError.httpError(status: 400, message: "请输入 License Key")
        }

        let client = CloudAPIClient(baseURL: settings.cloudBaseURL)
        let response = try await client.activateLicense(trimmedKey)
        let email = response.user?.email ?? KeychainStore.load(account: .accountEmail) ?? "license-user"
        try persistSession(response: response, email: email)
        settings.cloudAccount = response.toCloudAccount(fallbackEmail: email)
        isLoggedIn = true
    }

    func refreshProfile(settings: AppSettings) async throws {
        let client = CloudAPIClient(baseURL: settings.cloudBaseURL)
        let profile = try await client.fetchProfile()
        let email = profile.email ?? KeychainStore.load(account: .accountEmail) ?? ""
        settings.cloudAccount = profile.toCloudAccount(fallbackEmail: email)
        isLoggedIn = true
    }

    @discardableResult
    func refreshSession(using client: CloudAPIClient) async throws -> Bool {
        guard let refreshToken = KeychainStore.load(account: .refreshToken),
              !refreshToken.isEmpty else {
            return false
        }

        let response = try await client.refreshToken(refreshToken)
        let email = response.user?.email ?? KeychainStore.load(account: .accountEmail) ?? ""
        try persistSession(response: response, email: email)
        isLoggedIn = true
        return true
    }

    func logout(settings: AppSettings) {
        KeychainStore.clearSession()
        settings.cloudAccount = nil
        isLoggedIn = false
    }

    private func persistSession(response: AuthResponse, email: String) throws {
        try KeychainStore.save(response.token, account: .accessToken)
        if let refreshToken = response.refreshToken, !refreshToken.isEmpty {
            try KeychainStore.save(refreshToken, account: .refreshToken)
        }
        try KeychainStore.save(email, account: .accountEmail)
    }
}

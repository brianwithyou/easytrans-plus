import Foundation

@MainActor
final class CloudAuthService: ObservableObject {
    static let shared = CloudAuthService()

    @Published private(set) var isLoggedIn = false
    @Published var authPrompt: AuthPrompt?

    enum AuthPrompt: String, Identifiable {
        case login
        case register

        var id: String { rawValue }

        var initialScreen: AuthPanelView.Screen {
            switch self {
            case .login: return .login
            case .register: return .register
            }
        }
    }

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
            settings.cloudAccount = CloudAccount(email: email, planName: "基础版", dailyQuota: nil, dailyUsed: nil)
        }

        let client = CloudAPIClient(baseURL: settings.cloudBaseURL)
        do {
            let profile = try await client.fetchProfile()
            let email = profile.email ?? KeychainStore.load(account: .accountEmail) ?? ""
            settings.cloudAccount = profile.toCloudAccount(fallbackEmail: email)
            if !email.isEmpty {
                KeychainStore.save(email, account: .accountEmail)
            }
            isLoggedIn = true
            DeviceReportService.shared.reportIfVersionChanged(settings: settings)
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
        persistSession(response: response, email: trimmedEmail)
        settings.cloudAccount = response.toCloudAccount(fallbackEmail: trimmedEmail)
        isLoggedIn = true
        DeviceReportService.shared.reportOnLogin(settings: settings)
    }

    func register(email: String, password: String, code: String, settings: AppSettings) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            throw TranslationError.httpError(status: 400, message: "请输入邮箱和密码")
        }
        guard trimmedCode.count == 6 else {
            throw TranslationError.httpError(status: 400, message: "请输入 6 位验证码")
        }

        let client = CloudAPIClient(baseURL: settings.cloudBaseURL)
        let response = try await client.register(email: trimmedEmail, password: password, code: trimmedCode)
        persistSession(response: response, email: trimmedEmail)
        settings.cloudAccount = response.toCloudAccount(fallbackEmail: trimmedEmail)
        isLoggedIn = true
        DeviceReportService.shared.reportOnLogin(settings: settings)
    }

    func sendRegisterCode(email: String, settings: AppSettings) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            throw TranslationError.httpError(status: 400, message: "请输入邮箱")
        }

        let client = CloudAPIClient(baseURL: settings.cloudBaseURL)
        _ = try await client.sendRegisterCode(email: trimmedEmail)
    }

    func activateLicense(_ licenseKey: String, settings: AppSettings) async throws {
        let trimmedKey = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw TranslationError.httpError(status: 400, message: "请输入 License Key")
        }

        let client = CloudAPIClient(baseURL: settings.cloudBaseURL)
        let response = try await client.activateLicense(trimmedKey)
        let email = response.user?.email ?? KeychainStore.load(account: .accountEmail) ?? "license-user"
        persistSession(response: response, email: email)
        settings.cloudAccount = response.toCloudAccount(fallbackEmail: email)
        isLoggedIn = true
        DeviceReportService.shared.reportOnLogin(settings: settings)
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
        persistSession(response: response, email: email)
        isLoggedIn = true
        return true
    }

    func logout(settings: AppSettings) {
        KeychainStore.clearSession()
        settings.cloudAccount = nil
        isLoggedIn = false
        authPrompt = nil
    }

    func presentLogin() {
        authPrompt = .login
    }

    func presentRegister() {
        authPrompt = .register
    }

    func dismissAuthPrompt() {
        authPrompt = nil
    }

    private func persistSession(response: AuthResponse, email: String) {
        KeychainStore.save(response.token, account: .accessToken)
        if let refreshToken = response.refreshToken, !refreshToken.isEmpty {
            KeychainStore.save(refreshToken, account: .refreshToken)
        }
        KeychainStore.save(email, account: .accountEmail)
    }
}

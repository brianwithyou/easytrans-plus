import Foundation
import Combine

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Keys {
        static let apiKey = "dashscope.apiKey"
        static let model = "dashscope.model"
        static let baseURL = "dashscope.baseURL"
        static let targetLanguage = "translation.targetLanguage"
        static let translationMode = "translation.mode"
        static let cloudBaseURL = "cloud.baseURL"
    }

    @Published var translationMode: TranslationMode {
        didSet {
            guard translationMode != oldValue else { return }
            UserDefaults.standard.set(translationMode.rawValue, forKey: Keys.translationMode)
        }
    }

    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: Keys.apiKey) }
    }

    @Published var model: String {
        didSet { UserDefaults.standard.set(model, forKey: Keys.model) }
    }

    @Published var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: Keys.baseURL) }
    }

    @Published var cloudBaseURL: String {
        didSet { UserDefaults.standard.set(cloudBaseURL, forKey: Keys.cloudBaseURL) }
    }

    @Published var cloudAccount: CloudAccount?

    @Published private(set) var sourceLanguage: Language = .english

    @Published var targetLanguage: Language {
        didSet {
            let normalized = Self.normalizedTargetLanguage(targetLanguage)
            if normalized != targetLanguage {
                targetLanguage = normalized
                return
            }
            UserDefaults.standard.set(targetLanguage.rawValue, forKey: Keys.targetLanguage)
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            do {
                try LaunchAtLoginService.shared.setEnabled(launchAtLogin)
            } catch {
                launchAtLogin = LaunchAtLoginService.shared.isEnabled
            }
        }
    }

    var isConfigured: Bool {
        switch translationMode {
        case .byok:
            return !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .cloud:
            return CloudAuthService.shared.hasStoredSession
        }
    }

    var configurationHint: String {
        translationMode.configurationHint
    }

    private init() {
        let defaults = UserDefaults.standard
        translationMode = TranslationMode(
            rawValue: defaults.string(forKey: Keys.translationMode) ?? ""
        ) ?? .byok
        apiKey = defaults.string(forKey: Keys.apiKey) ?? ""
        model = defaults.string(forKey: Keys.model) ?? "qwen-plus"
        baseURL = defaults.string(forKey: Keys.baseURL) ?? "https://dashscope.aliyuncs.com/compatible-mode/v1"
        cloudBaseURL = defaults.string(forKey: Keys.cloudBaseURL) ?? "http://127.0.0.1:9091"
        sourceLanguage = .english
        targetLanguage = Self.normalizedTargetLanguage(
            Language(rawValue: defaults.string(forKey: Keys.targetLanguage) ?? "") ?? .chinese
        )
        launchAtLogin = LaunchAtLoginService.shared.isEnabled

        Task {
            await CloudAuthService.shared.restoreSession(into: self)
        }
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLogin = LaunchAtLoginService.shared.isEnabled
    }

    func makeTranslationProvider() -> any TranslationProvider {
        switch translationMode {
        case .byok:
            return DirectDashScopeProvider(apiKey: apiKey, baseURL: baseURL, model: model)
        case .cloud:
            return CloudTranslationProvider(client: CloudAPIClient(baseURL: cloudBaseURL))
        }
    }

    private static func normalizedTargetLanguage(_ language: Language) -> Language {
        Language.selectableTargets.contains(language) ? language : .chinese
    }
}

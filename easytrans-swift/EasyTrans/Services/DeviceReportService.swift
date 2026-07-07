import Foundation
import os.log

@MainActor
final class DeviceReportService {
    static let shared = DeviceReportService()

    private enum Keys {
        static let lastReportedAppVersion = "com.easytrans.pro.deviceReport.lastAppVersion"
    }

    private let logger = Logger(subsystem: "com.easytrans.pro", category: "DeviceReport")

    private init() {}

    /// 登录、注册、License 激活成功后调用，始终上报一次。
    func reportOnLogin(settings: AppSettings) {
        Task {
            await report(settings: settings, force: true)
        }
    }

    /// App 启动恢复会话成功后调用，仅 App 版本变更时上报。
    func reportIfVersionChanged(settings: AppSettings) {
        Task {
            await report(settings: settings, force: false)
        }
    }

    private func report(settings: AppSettings, force: Bool) async {
        guard CloudAuthService.shared.hasStoredSession else { return }

        let appVersion = DeviceInfoCollector.appVersion
        if !force {
            let lastReported = UserDefaults.standard.string(forKey: Keys.lastReportedAppVersion)
            guard lastReported != appVersion else { return }
        }

        let client = CloudAPIClient(baseURL: settings.cloudBaseURL)
        let payload = DeviceInfoCollector.current()

        do {
            try await client.reportDevice(payload)
            UserDefaults.standard.set(appVersion, forKey: Keys.lastReportedAppVersion)
            logger.info(
                "Device report succeeded appVersion=\(appVersion, privacy: .public) force=\(force, privacy: .public)"
            )
        } catch {
            logger.warning("Device report failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginService {
    static let shared = LaunchAtLoginService()

    private init() {}

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

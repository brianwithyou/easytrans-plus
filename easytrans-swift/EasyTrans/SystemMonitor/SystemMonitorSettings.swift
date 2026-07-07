import Combine
import Foundation

extension Notification.Name {
    static let systemMonitorSettingsDidChange = Notification.Name("systemMonitorSettingsDidChange")
}

@MainActor
final class SystemMonitorSettings: ObservableObject {
    static let shared = SystemMonitorSettings()

    private enum Keys {
        static let isMonitoringEnabled = "systemMonitor.isMonitoringEnabled"
        static let showMenuBarStats = "systemMonitor.showMenuBarStats"
        static let cpuThreshold = "systemMonitor.cpuThreshold"
        static let memoryThreshold = "systemMonitor.memoryThreshold"
        static let pollIntervalSeconds = "systemMonitor.pollIntervalSeconds"
        static let alertCooldownMinutes = "systemMonitor.alertCooldownMinutes"
    }

    static let defaultCPUThreshold = 85.0
    static let defaultMemoryThreshold = 90.0
    static let defaultPollIntervalSeconds = 2
    static let defaultAlertCooldownMinutes = 10
    static let consecutiveSamplesRequired = 3

    @Published var isMonitoringEnabled: Bool {
        didSet {
            guard isMonitoringEnabled != oldValue else { return }
            UserDefaults.standard.set(isMonitoringEnabled, forKey: Keys.isMonitoringEnabled)
            postChange()
        }
    }

    @Published var showMenuBarStats: Bool {
        didSet {
            guard showMenuBarStats != oldValue else { return }
            UserDefaults.standard.set(showMenuBarStats, forKey: Keys.showMenuBarStats)
            postChange()
        }
    }

    @Published var cpuThreshold: Double {
        didSet {
            let clamped = Self.clampThreshold(cpuThreshold)
            if clamped != cpuThreshold {
                cpuThreshold = clamped
                return
            }
            UserDefaults.standard.set(cpuThreshold, forKey: Keys.cpuThreshold)
            postChange()
        }
    }

    @Published var memoryThreshold: Double {
        didSet {
            let clamped = Self.clampThreshold(memoryThreshold)
            if clamped != memoryThreshold {
                memoryThreshold = clamped
                return
            }
            UserDefaults.standard.set(memoryThreshold, forKey: Keys.memoryThreshold)
            postChange()
        }
    }

    @Published var pollIntervalSeconds: Int {
        didSet {
            let clamped = min(max(pollIntervalSeconds, 3), 30)
            if clamped != pollIntervalSeconds {
                pollIntervalSeconds = clamped
                return
            }
            UserDefaults.standard.set(pollIntervalSeconds, forKey: Keys.pollIntervalSeconds)
            postChange()
        }
    }

    @Published var alertCooldownMinutes: Int {
        didSet {
            let clamped = min(max(alertCooldownMinutes, 1), 60)
            if clamped != alertCooldownMinutes {
                alertCooldownMinutes = clamped
                return
            }
            UserDefaults.standard.set(alertCooldownMinutes, forKey: Keys.alertCooldownMinutes)
            postChange()
        }
    }

    var shouldPoll: Bool {
        isMonitoringEnabled || showMenuBarStats
    }

    private init() {
        let defaults = UserDefaults.standard
        isMonitoringEnabled = defaults.object(forKey: Keys.isMonitoringEnabled) as? Bool ?? false
        showMenuBarStats = defaults.object(forKey: Keys.showMenuBarStats) as? Bool ?? true
        cpuThreshold = Self.clampThreshold(defaults.object(forKey: Keys.cpuThreshold) as? Double ?? Self.defaultCPUThreshold)
        memoryThreshold = Self.clampThreshold(defaults.object(forKey: Keys.memoryThreshold) as? Double ?? Self.defaultMemoryThreshold)
        pollIntervalSeconds = defaults.object(forKey: Keys.pollIntervalSeconds) as? Int ?? Self.defaultPollIntervalSeconds
        alertCooldownMinutes = defaults.object(forKey: Keys.alertCooldownMinutes) as? Int ?? Self.defaultAlertCooldownMinutes
    }

    private static func clampThreshold(_ value: Double) -> Double {
        min(max(value, 50), 99)
    }

    private func postChange() {
        NotificationCenter.default.post(name: .systemMonitorSettingsDidChange, object: nil)
    }
}

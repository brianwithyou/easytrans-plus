import AppKit
import Darwin
import Foundation
import Metal

struct ClientDeviceReport: Encodable, Sendable {
    let deviceId: String
    let appVersion: String
    let osVersion: String
    let platform: String
    let architecture: String
    let screenSize: String
    let locale: String
    let timezone: String
    let gpuName: String?
    let memoryBytes: UInt64
    let cpuCores: Int
    let cpuBrand: String?
}

enum DeviceInfoCollector {
    private enum Keys {
        static let deviceId = "com.easytrans.pro.deviceId"
    }

    static var deviceId: String {
        if let existing = UserDefaults.standard.string(forKey: Keys.deviceId),
           !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return existing
        }

        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: Keys.deviceId)
        return generated
    }

    static var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        switch (version, build) {
        case let (.some(version), .some(build)) where !build.isEmpty:
            return "\(version) (\(build))"
        case let (.some(version), _):
            return version
        default:
            return "unknown"
        }
    }

    static func current() -> ClientDeviceReport {
        ClientDeviceReport(
            deviceId: deviceId,
            appVersion: appVersion,
            osVersion: osVersionString(),
            platform: "macOS",
            architecture: architecture(),
            screenSize: primaryScreenSize(),
            locale: Locale.preferredLanguages.first ?? Locale.current.identifier,
            timezone: TimeZone.current.identifier,
            gpuName: gpuName(),
            memoryBytes: ProcessInfo.processInfo.physicalMemory,
            cpuCores: ProcessInfo.processInfo.processorCount,
            cpuBrand: cpuBrand()
        )
    }

    private static func osVersionString() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    private static func architecture() -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    private static func primaryScreenSize() -> String {
        guard let screen = NSScreen.main else { return "unknown" }
        let scale = screen.backingScaleFactor
        let width = Int(screen.frame.width * scale)
        let height = Int(screen.frame.height * scale)
        return "\(width)x\(height)"
    }

    private static func gpuName() -> String? {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        let name = device.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    private static func cpuBrand() -> String? {
        sysctlString("machdep.cpu.brand_string")
            ?? sysctlString("hw.model")
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }

        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }

        let value = String(cString: buffer).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

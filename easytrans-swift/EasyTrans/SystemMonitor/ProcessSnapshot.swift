import AppKit
import Darwin
import Foundation

enum ProcessSortMetric: Sendable, CaseIterable, Identifiable {
    case cpu
    case memory

    var id: Self { self }

    var label: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return "内存"
        }
    }
}

extension Array where Element == ProcessSnapshot {
    func sorted(by metric: ProcessSortMetric, limit: Int = 15) -> [ProcessSnapshot] {
        sorted { lhs, rhs in
            switch metric {
            case .cpu:
                if abs(lhs.cpuPercent - rhs.cpuPercent) > 0.05 {
                    return lhs.cpuPercent > rhs.cpuPercent
                }
                return lhs.memoryBytes > rhs.memoryBytes
            case .memory:
                if lhs.memoryBytes != rhs.memoryBytes {
                    return lhs.memoryBytes > rhs.memoryBytes
                }
                return lhs.cpuPercent > rhs.cpuPercent
            }
        }
        .prefix(limit)
        .map { $0 }
    }
}

struct ProcessSnapshot: Identifiable, Hashable, Sendable {
    let pid: pid_t
    let name: String
    let bundleIdentifier: String?
    let executablePath: String?
    let memoryBytes: UInt64
    let cpuPercent: Double
    let cpuTimeNanoseconds: UInt64
    let threadCount: Int
    let userName: String
    let isProtected: Bool
    let pageTitle: String?
    let pageURL: String?

    var id: pid_t { pid }

    var hasPageContext: Bool {
        guard let pageTitle, !pageTitle.isEmpty else { return false }
        return true
    }

    func withPageContext(title: String?, url: String?) -> ProcessSnapshot {
        ProcessSnapshot(
            pid: pid,
            name: name,
            bundleIdentifier: bundleIdentifier,
            executablePath: executablePath,
            memoryBytes: memoryBytes,
            cpuPercent: cpuPercent,
            cpuTimeNanoseconds: cpuTimeNanoseconds,
            threadCount: threadCount,
            userName: userName,
            isProtected: isProtected,
            pageTitle: title,
            pageURL: url
        )
    }

    /// Activity Monitor style: one decimal, no percent sign.
    var activityMonitorCPUDisplay: String {
        String(format: "%.1f", cpuPercent)
    }

    var cpuDisplay: String {
        "\(activityMonitorCPUDisplay)%"
    }

    var memoryDisplay: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryBytes), countStyle: .memory)
    }

    var cpuTimeDisplay: String {
        Self.formatCPUTime(nanoseconds: cpuTimeNanoseconds)
    }

    var icon: NSImage? {
        if let bundleIdentifier,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        if let executablePath {
            return NSWorkspace.shared.icon(forFile: executablePath)
        }
        return NSWorkspace.shared.icon(forFile: "/System/Applications/Utilities/Activity Monitor.app")
    }

    static func formatCPUTime(nanoseconds: UInt64) -> String {
        let centiseconds = nanoseconds / 10_000_000
        let cs = centiseconds % 100
        let totalSeconds = centiseconds / 100
        let seconds = totalSeconds % 60
        let totalMinutes = totalSeconds / 60
        let minutes = totalMinutes % 60
        let hours = totalMinutes / 60
        let csText = String(format: "%02d", cs)

        if hours > 0 {
            return String(format: "%d:%02d:%02d.%@", hours, minutes, seconds, csText)
        }
        if totalMinutes > 0 {
            return String(format: "%d:%02d.%@", minutes, seconds, csText)
        }
        return String(format: "%d.%@", seconds, csText)
    }

    static func username(for uid: uid_t) -> String {
        if uid == 0 { return "root" }
        if let password = getpwuid(uid) {
            return String(cString: password.pointee.pw_name)
        }
        return String(uid)
    }
}

enum TerminateResult: Equatable, Sendable {
    case success
    case notRunning
    case protected
    case failed(String)
}

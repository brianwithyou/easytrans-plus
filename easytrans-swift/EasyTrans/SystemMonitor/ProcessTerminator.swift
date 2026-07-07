import AppKit
import Darwin
import Foundation

enum ProcessTerminator {
    static func terminate(pids: [pid_t]) async -> [pid_t: TerminateResult] {
        var results: [pid_t: TerminateResult] = [:]
        for pid in pids {
            results[pid] = await terminate(pid: pid)
        }
        return results
    }

    private static func terminate(pid: pid_t) async -> TerminateResult {
        if pid == ProcessInfo.processInfo.processIdentifier || pid <= 1 {
            return .protected
        }

        guard isProcessRunning(pid: pid) else {
            return .notRunning
        }

        if let app = NSRunningApplication(processIdentifier: pid) {
            if !app.terminate() {
                return sendSignal(SIGTERM, to: pid)
            }
            let stillRunning = await waitUntilProcessExits(pid: pid, timeout: 3)
            if stillRunning {
                return sendSignal(SIGTERM, to: pid)
            }
            return .success
        }

        return sendSignal(SIGTERM, to: pid)
    }

    private static func sendSignal(_ signal: Int32, to pid: pid_t) -> TerminateResult {
        let result = kill(pid, signal)
        if result == 0 {
            return .success
        }
        if errno == ESRCH {
            return .notRunning
        }
        if errno == EPERM {
            return .protected
        }
        return .failed(String(cString: strerror(errno)))
    }

    private static func isProcessRunning(pid: pid_t) -> Bool {
        kill(pid, 0) == 0
    }

    private static func waitUntilProcessExits(pid: pid_t, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !isProcessRunning(pid: pid) {
                return false
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return isProcessRunning(pid: pid)
    }
}

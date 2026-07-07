import AppKit
import Darwin
import Foundation

struct ChromeTabInfo: Sendable, Equatable {
    let id: String
    let title: String
    let url: String
}

final class ChromeTabEnrichmentService: @unchecked Sendable {
    static let shared = ChromeTabEnrichmentService()

    private let lock = NSLock()
    private var pidToTabID: [pid_t: String] = [:]
    private var lastTabFetchDate: Date?
    private var cachedTabs: [ChromeTabInfo] = []

    private let tabCacheInterval: TimeInterval = 2
    private let chromeAppName = "Google Chrome"

    private init() {}

    func enrichProcesses(_ processes: [ProcessSnapshot]) -> [ProcessSnapshot] {
        guard NSWorkspace.shared.runningApplications.contains(where: {
            $0.localizedName == chromeAppName || $0.bundleIdentifier == "com.google.Chrome"
        }) else {
            return processes
        }

        let tabs = fetchTabs()
        guard !tabs.isEmpty else { return processes }

        let renderers = processes.compactMap { process -> (pid: pid_t, memory: UInt64)? in
            guard isChromePageRenderer(process) else { return nil }
            return (process.pid, process.memoryBytes)
        }
        guard !renderers.isEmpty else { return processes }

        let mapping = matchTabsToRenderers(renderers: renderers, tabs: tabs)
        guard !mapping.isEmpty else { return processes }

        return processes.map { process in
            guard let tab = mapping[process.pid] else { return process }
            return process.withPageContext(title: tab.title, url: tab.url)
        }
    }

    func resetCache() {
        lock.lock()
        defer { lock.unlock() }
        pidToTabID.removeAll()
        cachedTabs.removeAll()
        lastTabFetchDate = nil
    }

    private func fetchTabs() -> [ChromeTabInfo] {
        lock.lock()
        if let lastTabFetchDate,
           Date().timeIntervalSince(lastTabFetchDate) < tabCacheInterval,
           !cachedTabs.isEmpty {
            let tabs = cachedTabs
            lock.unlock()
            return tabs
        }
        lock.unlock()

        let scriptSource = """
        tell application "\(chromeAppName)"
            if not running then return ""
            set output to ""
            repeat with w in windows
                repeat with t in tabs of w
                    set tabId to id of t as text
                    set tabTitle to title of t
                    set tabURL to URL of t
                    set output to output & tabId & "|||" & tabTitle & "|||" & tabURL & linefeed
                end repeat
            end repeat
            return output
        end tell
        """

        guard let script = NSAppleScript(source: scriptSource) else { return cachedTabsSnapshot() }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil else { return cachedTabsSnapshot() }

        let raw = result.stringValue ?? ""
        let tabs = parseTabs(from: raw)

        lock.lock()
        cachedTabs = tabs
        lastTabFetchDate = Date()
        lock.unlock()

        return tabs
    }

    private func cachedTabsSnapshot() -> [ChromeTabInfo] {
        lock.lock()
        defer { lock.unlock() }
        return cachedTabs
    }

    private func parseTabs(from raw: String) -> [ChromeTabInfo] {
        raw
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                let parts = String(line).components(separatedBy: "|||")
                guard parts.count == 3 else { return nil }

                let id = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let title = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let url = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !id.isEmpty, isPageURL(url) else { return nil }
                return ChromeTabInfo(id: id, title: sanitizedTitle(title, url: url), url: url)
            }
    }

    private func sanitizedTitle(_ title: String, url: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let host = URL(string: url)?.host, !host.isEmpty { return host }
        return url
    }

    private func isPageURL(_ url: String) -> Bool {
        guard let scheme = URL(string: url)?.scheme?.lowercased() else { return false }
        if scheme == "chrome-extension" || scheme == "chrome" { return false }
        return scheme == "http" || scheme == "https" || scheme == "file"
    }

    private func isChromePageRenderer(_ process: ProcessSnapshot) -> Bool {
        let loweredName = process.name.lowercased()
        let loweredPath = process.executablePath?.lowercased() ?? ""
        guard loweredName.contains("chrome helper (renderer)")
            || loweredPath.contains("google chrome helper (renderer)") else {
            return false
        }

        guard let arguments = processArguments(for: process.pid) else { return true }
        let joined = arguments.joined(separator: " ").lowercased()
        if joined.contains("--extension-process") { return false }
        if joined.contains("--type=renderer") == false, !loweredName.contains("renderer") {
            return false
        }
        return true
    }

    private func matchTabsToRenderers(
        renderers: [(pid: pid_t, memory: UInt64)],
        tabs: [ChromeTabInfo]
    ) -> [pid_t: ChromeTabInfo] {
        lock.lock()
        var stickyAssignments = pidToTabID
        lock.unlock()

        let tabByID = Dictionary(uniqueKeysWithValues: tabs.map { ($0.id, $0) })
        var result: [pid_t: ChromeTabInfo] = [:]

        for (pid, tabID) in stickyAssignments {
            if let tab = tabByID[tabID], renderers.contains(where: { $0.pid == pid }) {
                result[pid] = tab
            }
        }

        let unassignedRenderers = renderers
            .filter { result[$0.pid] == nil }
            .sorted { $0.memory > $1.memory }

        var usedTabIDs = Set(result.values.map(\.id))
        let availableTabs = tabs.filter { !usedTabIDs.contains($0.id) }

        let assignCount = min(unassignedRenderers.count, availableTabs.count)
        if assignCount > 0 {
            for index in 0..<assignCount {
                let pid = unassignedRenderers[index].pid
                let tab = availableTabs[index]
                result[pid] = tab
                stickyAssignments[pid] = tab.id
            }
        }

        let liveRendererPIDs = Set(renderers.map(\.pid))
        stickyAssignments = stickyAssignments.filter { liveRendererPIDs.contains($0.key) }

        lock.lock()
        pidToTabID = stickyAssignments
        lock.unlock()

        return result
    }

    private func processArguments(for pid: pid_t) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size: size_t = 0
        guard sysctl(&mib, u_int(mib.count), nil, &size, nil, 0) == 0, size > 0 else {
            return nil
        }

        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, u_int(mib.count), &buffer, &size, nil, 0) == 0 else {
            return nil
        }

        guard size >= MemoryLayout<Int32>.size else { return nil }
        let argc = buffer.withUnsafeBytes { pointer in
            pointer.load(as: Int32.self)
        }
        guard argc > 0 else { return nil }

        var arguments: [String] = []
        var cursor = MemoryLayout<Int32>.size * 2
        let end = Int(size)

        while cursor < end, arguments.count < Int(argc) {
            while cursor < end, buffer[cursor] == 0 { cursor += 1 }
            guard cursor < end else { break }

            var start = cursor
            while cursor < end, buffer[cursor] != 0 { cursor += 1 }
            guard start < cursor else { break }

            if let argument = String(bytes: buffer[start..<cursor], encoding: .utf8), !argument.isEmpty {
                arguments.append(argument)
            }
        }

        return arguments.isEmpty ? nil : arguments
    }
}

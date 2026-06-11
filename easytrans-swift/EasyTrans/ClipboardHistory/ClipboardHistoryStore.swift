import AppKit
import Combine
import os.log

/// 剪贴板历史内存存储 + 磁盘持久化。
/// 数据文件：`~/Library/Application Support/com.easytrans.pro/clipboard-history.json`
@MainActor
final class ClipboardHistoryStore: ObservableObject {
    static let shared = ClipboardHistoryStore()

    /// 最多保留的历史条数（内存与磁盘一致）。
    static let maxItems = 5000

    /// 持久化文件名。
    private static let persistenceFileName = "clipboard-history.json"

    @Published private(set) var items: [ClipboardHistoryItem] = []
    /// 剪贴板历史浮层内的搜索关键字（与浮层生命周期绑定，关闭时清空）。
    @Published var searchFilter = ""

    private let logger = Logger(subsystem: "com.easytrans.pro", category: "ClipboardHistoryStore")

    private var pollTimer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    /// 本模块写入剪贴板时置位，避免把「粘贴历史」再次记入历史。
    private var suppressNextChange = false
    /// 防抖落盘任务：连续复制时合并写入，避免 5000 条历史频繁全量序列化阻塞主线程。
    private var debouncedSaveTask: Task<Void, Never>?
    /// 两次落盘之间的最短间隔（秒）。
    private static let saveDebounceInterval: TimeInterval = 0.8

    private init() {
        loadFromDisk()
    }

    // MARK: - 生命周期

    func resetSearchFilter() {
        searchFilter = ""
    }

    func startMonitoring() {
        guard pollTimer == nil else { return }
        lastChangeCount = NSPasteboard.general.changeCount
        logger.info("Start monitoring pasteboard, loaded \(self.items.count) persisted item(s)")

        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPasteboard()
            }
        }
    }

    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
        logger.info("Stop monitoring pasteboard")
    }

    /// 应用退出前调用，取消防抖并立即落盘，确保内存中的最新数据写入磁盘。
    func flushToDisk() {
        debouncedSaveTask?.cancel()
        debouncedSaveTask = nil
        logger.info("Flushing clipboard history to disk (\(self.items.count) item(s))")
        saveToDisk()
    }

    /// 由本模块写入剪贴板时调用，避免把粘贴动作再次记为历史。
    func preparePasteboardUpdate() {
        suppressNextChange = true
        logger.debug("Suppress next pasteboard change (paste-from-history)")
    }

    // MARK: - 剪贴板轮询

    private func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if suppressNextChange {
            suppressNextChange = false
            logger.debug("Skipped pasteboard change (suppressed after history paste)")
            return
        }

        guard let text = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return
        }

        addItem(text)
    }

    private func addItem(_ text: String) {
        // 与上一条内容相同则跳过，避免连续重复复制撑满历史。
        if items.first?.text == text {
            logger.debug("Skipped duplicate clipboard text at head of history")
            return
        }

        items.insert(ClipboardHistoryItem(text: text), at: 0)
        if items.count > Self.maxItems {
            let removed = items.count - Self.maxItems
            items.removeLast(removed)
            logger.info("Trimmed \(removed) oldest clipboard history item(s), cap=\(Self.maxItems)")
        }

        logger.info("Recorded clipboard history item, total=\(self.items.count)")
        scheduleDebouncedSave()
    }

    /// 延迟合并写入磁盘；`flushToDisk()` 会取消待执行的防抖任务并立即保存。
    private func scheduleDebouncedSave() {
        debouncedSaveTask?.cancel()
        debouncedSaveTask = Task { @MainActor [weak self] in
            let interval = Self.saveDebounceInterval
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.logger.debug("Debounced save triggered after \(interval, privacy: .public)s idle")
            self.saveToDisk()
            self.debouncedSaveTask = nil
        }
    }

    // MARK: - 磁盘持久化

    /// Application Support 目录下的 JSON 文件路径。
    private static var persistenceFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "com.easytrans.pro"
        let directory = appSupport.appendingPathComponent(bundleID, isDirectory: true)

        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                // 目录创建失败时仍返回目标路径，后续 save/load 会打 log。
                Logger(subsystem: "com.easytrans.pro", category: "ClipboardHistoryStore")
                    .error("Failed to create Application Support directory: \(error.localizedDescription, privacy: .public)")
            }
        }

        return directory.appendingPathComponent(persistenceFileName)
    }

    /// 启动时从 JSON 文件恢复历史；文件不存在或损坏时从空列表开始。
    private func loadFromDisk() {
        let fileURL = Self.persistenceFileURL

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            logger.info("No persistence file at \(fileURL.path, privacy: .public), starting empty")
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            var decoded = try decoder.decode([ClipboardHistoryItem].self, from: data)

            if decoded.count > Self.maxItems {
                decoded = Array(decoded.prefix(Self.maxItems))
                logger.info("Truncated loaded history from file to \(Self.maxItems) item(s)")
            }

            items = decoded
            logger.info("Loaded \(decoded.count) clipboard history item(s) from \(fileURL.path, privacy: .public)")
        } catch {
            logger.error("Failed to load clipboard history: \(error.localizedDescription, privacy: .public)")
            items = []
        }
    }

    /// 将当前 `items` 序列化为 JSON 并原子写入磁盘。
    private func saveToDisk() {
        let fileURL = Self.persistenceFileURL

        do {
            let encoder = JSONEncoder()
            // 5000 条体量较大，使用紧凑 JSON（无 prettyPrint）以加快读写、减小文件体积。
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items)

            // 先写临时文件再替换，降低写入中断导致文件损坏的概率。
            let tempURL = fileURL.appendingPathExtension("tmp")
            try data.write(to: tempURL, options: .atomic)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: fileURL)

            logger.debug("Saved \(self.items.count) clipboard history item(s) to \(fileURL.path, privacy: .public)")
        } catch {
            logger.error("Failed to save clipboard history: \(error.localizedDescription, privacy: .public)")
        }
    }
}

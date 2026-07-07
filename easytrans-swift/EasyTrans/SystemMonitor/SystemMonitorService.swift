import AppKit
import Combine
import os.log
import SwiftUI
import UserNotifications

@MainActor
final class SystemMonitorService: NSObject, ObservableObject {
    static let shared = SystemMonitorService()

    @Published private(set) var systemCPUPercent: Double = 0
    @Published private(set) var systemMemoryPercent: Double = 0
    @Published private(set) var topProcesses: [ProcessSnapshot] = []
    @Published private(set) var panelSortMetric: ProcessSortMetric = .cpu
    @Published var selectedPIDs: Set<pid_t> = []
    @Published private(set) var isTerminating = false
    @Published private(set) var panelStatusMessage: String?

    private let logger = Logger(subsystem: "com.easytrans.pro", category: "SystemMonitor")
    private let settings = SystemMonitorSettings.shared
    private let collector = SystemMetricsCollector.shared
    private let samplingQueue = DispatchQueue(label: "com.easytrans.pro.systemmonitor.sampling", qos: .utility)

    private var pollTimer: Timer?
    private var consecutiveOverThreshold = 0
    private var lastAlertDate: Date?
    private var snoozedUntil: Date?
    private var isSampling = false

    private var panel: ResourceAlertPanel?
    private var hostingController: NSHostingController<ResourceAlertPanelView>?
    private var processPool: [ProcessSnapshot] = []
    private var outsideClickMonitor: Any?
    private var escapeKeyMonitor: Any?

    private override init() {
        super.init()
    }

    func start() {
        requestNotificationPermission()
        observeSettingsChanges()
        refreshPolling()
        logger.info("System monitor started")
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        closePanel()
    }

    func showPanelFromMenu() {
        sampleMetrics()
        setPanelSortMetric(.cpu)
        presentPanel(isAlert: false)
    }

    func setPanelSortMetric(_ metric: ProcessSortMetric) {
        guard panelSortMetric != metric else { return }
        applyPanelSortMetric(metric)
    }

    func setProcessSelected(_ pid: pid_t, isSelected: Bool, isProtected: Bool) {
        guard !isProtected else { return }
        if isSelected {
            selectedPIDs.insert(pid)
        } else {
            selectedPIDs.remove(pid)
        }
    }

    func closePanelFromUI() {
        closePanel()
    }

    func snoozeAlertFromUI() {
        snoozeAlert()
    }

    func terminateSelectedProcesses() async {
        let pids = Array(selectedPIDs)
        guard !pids.isEmpty else { return }

        let names = topProcesses
            .filter { pids.contains($0.pid) }
            .map(\.name)
            .joined(separator: "、")

        let alert = NSAlert()
        alert.messageText = "确认结束选中的进程？"
        alert.informativeText = names.isEmpty ? "此操作可能导致未保存的数据丢失。" : "将结束：\(names)\n\n此操作可能导致未保存的数据丢失。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "结束进程")
        alert.addButton(withTitle: "取消")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        isTerminating = true
        panelStatusMessage = nil

        let results = await ProcessTerminator.terminate(pids: pids)
        isTerminating = false

        var messages: [String] = []
        var succeeded = 0
        for pid in pids {
            switch results[pid] {
            case .success, .notRunning:
                succeeded += 1
                selectedPIDs.remove(pid)
            case .protected:
                messages.append("PID \(pid) 受系统保护，无法结束")
            case .failed(let reason):
                messages.append("PID \(pid) 结束失败：\(reason)")
            case .none:
                break
            }
        }

        if succeeded > 0 {
            messages.insert("已成功结束 \(succeeded) 个进程。", at: 0)
        }
        panelStatusMessage = messages.joined(separator: "\n")
        sampleMetrics()
    }

    private func observeSettingsChanges() {
        NotificationCenter.default.addObserver(
            forName: .systemMonitorSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPolling()
            }
        }
    }

    private func refreshPolling() {
        pollTimer?.invalidate()
        pollTimer = nil

        guard settings.shouldPoll else {
            systemCPUPercent = 0
            systemMemoryPercent = 0
            topProcesses = []
            return
        }

        sampleMetrics()

        let interval = TimeInterval(settings.pollIntervalSeconds)
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sampleMetrics()
            }
        }
        if let pollTimer {
            RunLoop.main.add(pollTimer, forMode: .common)
        }
    }

    private func sampleMetrics() {
        guard !isSampling else { return }
        isSampling = true

        let sortMetric = panelSortMetric
        samplingQueue.async { [weak self] in
            guard let self else { return }

            let cpu = self.collector.sampleSystemCPU()
            let memory = self.collector.sampleSystemMemory()
            var pool = self.collector.sampleProcessPool()
            self.collector.commitProcessCPUBaselines()

            if sortMetric == .memory {
                pool = ChromeTabEnrichmentService.shared.enrichProcesses(pool)
            }

            Task { @MainActor in
                self.isSampling = false
                self.applySampleResults(cpu: cpu, memory: memory, pool: pool)
            }
        }
    }

    private func applySampleResults(cpu: Double, memory: (usedBytes: UInt64, totalBytes: UInt64, percent: Double), pool: [ProcessSnapshot]) {
        processPool = pool
        systemCPUPercent = cpu
        systemMemoryPercent = memory.percent
        topProcesses = sortedProcessesForPanel()
        evaluateAlertIfNeeded(cpu: cpu, memoryPercent: memory.percent)
    }

    private func sortedProcessesForPanel(limit: Int = 20) -> [ProcessSnapshot] {
        processPool.sorted(by: panelSortMetric, limit: limit)
    }

    private func evaluateAlertIfNeeded(cpu: Double, memoryPercent: Double) {
        guard settings.isMonitoringEnabled else {
            consecutiveOverThreshold = 0
            return
        }

        if let snoozedUntil, Date() < snoozedUntil {
            return
        }

        let overThreshold = cpu >= settings.cpuThreshold || memoryPercent >= settings.memoryThreshold
        if overThreshold {
            consecutiveOverThreshold += 1
        } else {
            consecutiveOverThreshold = 0
            return
        }

        guard consecutiveOverThreshold >= SystemMonitorSettings.consecutiveSamplesRequired else {
            return
        }

        let cooldown = TimeInterval(settings.alertCooldownMinutes * 60)
        if let lastAlertDate, Date().timeIntervalSince(lastAlertDate) < cooldown {
            return
        }

        consecutiveOverThreshold = 0
        lastAlertDate = Date()
        triggerAlert(cpu: cpu, memoryPercent: memoryPercent)
    }

    private func triggerAlert(cpu: Double, memoryPercent: Double) {
        let body: String
        if cpu >= settings.cpuThreshold && memoryPercent >= settings.memoryThreshold {
            body = String(format: "CPU %.0f%%、内存 %.0f%% 已超过阈值，请查看高占用进程。", cpu, memoryPercent)
        } else if cpu >= settings.cpuThreshold {
            body = String(format: "CPU 已达到 %.0f%%，请查看高占用进程。", cpu)
        } else {
            body = String(format: "内存已达到 %.0f%%，请查看高占用进程。", memoryPercent)
        }

        showNotification(title: "系统资源占用较高", body: body)
        let sortMetric: ProcessSortMetric = cpu >= settings.cpuThreshold ? .cpu : .memory
        applyPanelSortMetric(sortMetric)
        presentPanel(isAlert: true)
        logger.info("Triggered resource alert CPU=\(cpu, privacy: .public) MEM=\(memoryPercent, privacy: .public) sort=\(sortMetric == .cpu ? "cpu" : "memory", privacy: .public)")
    }

    private func applyPanelSortMetric(_ metric: ProcessSortMetric) {
        panelSortMetric = metric
        if metric == .memory {
            enrichAndRefreshPanelProcesses()
        } else {
            topProcesses = sortedProcessesForPanel()
        }
    }

    private func enrichAndRefreshPanelProcesses() {
        let pool = processPool
        samplingQueue.async { [weak self] in
            guard let self else { return }
            let enrichedPool = ChromeTabEnrichmentService.shared.enrichProcesses(pool)
            Task { @MainActor in
                self.processPool = enrichedPool
                self.topProcesses = self.sortedProcessesForPanel()
            }
        }
    }

    private func defaultSelectedPIDs(from processes: [ProcessSnapshot]) -> Set<pid_t> {
        Set(
            processes
                .filter { process in
                    guard !process.isProtected else { return false }
                    switch panelSortMetric {
                    case .cpu:
                        return process.cpuPercent >= 5 || process.memoryBytes >= 512 * 1024 * 1024
                    case .memory:
                        return process.memoryBytes >= 256 * 1024 * 1024 || process.cpuPercent >= 5
                    }
                }
                .prefix(5)
                .map(\.pid)
        )
    }

    private func presentPanel(isAlert: Bool) {
        if isAlert || selectedPIDs.isEmpty {
            selectedPIDs = defaultSelectedPIDs(from: topProcesses)
        }
        panelStatusMessage = nil

        if panel == nil {
            let panel = ResourceAlertPanel(
                contentRect: NSRect(x: 0, y: 0, width: 980, height: 480),
                styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.title = "系统资源"
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.titlebarAppearsTransparent = true
            panel.titleVisibility = .hidden
            panel.isMovableByWindowBackground = true
            self.panel = panel
        }

        if hostingController == nil {
            let controller = NSHostingController(rootView: ResourceAlertPanelView(service: self))
            hostingController = controller
            panel?.contentView = controller.view
        }

        positionPanelNearMouse()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        installOutsideClickMonitor()
        installEscapeKeyMonitor()
    }

    private func snoozeAlert() {
        snoozedUntil = Date().addingTimeInterval(TimeInterval(settings.alertCooldownMinutes * 60))
        closePanel()
    }

    private func closePanel() {
        removeOutsideClickMonitor()
        removeEscapeKeyMonitor()
        panel?.orderOut(nil)
        panelStatusMessage = nil
    }

    private func positionPanelNearMouse() {
        guard let panel, let screen = NSScreen.main else { return }
        let mouse = NSEvent.mouseLocation
        let panelSize = panel.frame.size
        var origin = NSPoint(
            x: mouse.x - panelSize.width / 2,
            y: mouse.y - panelSize.height - 16
        )

        let visible = screen.visibleFrame
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - panelSize.width - 8)
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - panelSize.height - 8)
        panel.setFrameOrigin(origin)
    }

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.closePanelIfClickOutside()
            }
        }
    }

    private func removeOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    private func closePanelIfClickOutside() {
        guard let panel, panel.isVisible else { return }
        let mouse = NSEvent.mouseLocation
        if !panel.frame.contains(mouse) {
            closePanel()
        }
    }

    private func installEscapeKeyMonitor() {
        removeEscapeKeyMonitor()
        escapeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  let panel = self.panel,
                  panel.isVisible,
                  panel.isKeyWindow,
                  event.keyCode == 53 else {
                return event
            }
            self.closePanel()
            return nil
        }
    }

    private func removeEscapeKeyMonitor() {
        if let escapeKeyMonitor {
            NSEvent.removeMonitor(escapeKeyMonitor)
            self.escapeKeyMonitor = nil
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }
}

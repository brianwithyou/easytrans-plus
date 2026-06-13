import AppKit
import ApplicationServices
import Carbon.HIToolbox
import os.log
import UserNotifications

/// 快捷键注册状态，供菜单栏显示
struct HotkeyRegistrationStatus: Sendable {
    var carbonOK = false
    var eventTapOK = false
    var globalMonitorOK = false
    var localMonitorOK = false

    var isReady: Bool {
        carbonOK || eventTapOK || globalMonitorOK || localMonitorOK
    }

    var summary: String {
        [
            carbonOK ? "Carbon✓" : "Carbon✗",
            eventTapOK ? "Tap✓" : "Tap✗",
            globalMonitorOK ? "Global✓" : "Global✗",
            localMonitorOK ? "Local✓" : "Local✗"
        ].joined(separator: " ")
    }
}

// MARK: - C 回调（必须是文件级函数，不能放在类静态属性里）

private func easyTransCarbonHotkeyHandler(
    _: EventHandlerCallRef?,
    event: EventRef?,
    _: UnsafeMutableRawPointer?
) -> OSStatus {
    var hotKeyID = EventHotKeyID()
    let error = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard error == noErr, hotKeyID.id == 1 else {
        return OSStatus(eventNotHandledErr)
    }

    Task { @MainActor in
        QuickTranslateService.shared.onHotkeyPressed()
    }
    return noErr
}

private func easyTransEventTapCallback(
    _: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    _: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = QuickTranslateService.activeEventTapRef {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return nil
    }

    guard type == .keyDown, QuickTranslateService.matchesCGEvent(event) else {
        return Unmanaged.passUnretained(event)
    }

    Task { @MainActor in
        QuickTranslateService.shared.onHotkeyPressed()
    }
    return Unmanaged.passUnretained(event)
}

final class QuickTranslateService: NSObject {
    static let shared = QuickTranslateService()

    private let logger = Logger(subsystem: "com.easytrans.pro", category: "QuickTranslate")

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var eventTap: CFMachPort?
    fileprivate static var activeEventTapRef: CFMachPort?
    private var translateTask: Task<Void, Never>?
    private var lastTriggerTime: TimeInterval = 0
    private var didReportStartup = false
    private(set) var lastOtherAppPID: pid_t?

    private(set) var registrationStatus = HotkeyRegistrationStatus()

    private override init() {
        super.init()
    }

    @MainActor
    func start() {
        NSApp.setActivationPolicy(.regular)
        requestNotificationPermission()
        observeOtherApplications()
        registerAllHotkeyListeners()
        logger.info("Started — \(self.registrationStatus.summary, privacy: .public)")
        reportStartupIfNeeded()
    }

    @MainActor
    func stop() {
        translateTask?.cancel()
        unregisterAllHotkeyListeners()
    }

    @MainActor
    func refreshListeners() {
        registerAllHotkeyListeners()
        logger.info("Refreshed — \(self.registrationStatus.summary, privacy: .public)")
    }

    @MainActor
    func triggerFromMenu() {
        rememberFrontmostOtherApp()
        onHotkeyPressed()
    }

    @MainActor
    func rememberFrontmostOtherApp() {
        if let app = NSWorkspace.shared.frontmostApplication,
           app.bundleIdentifier != Bundle.main.bundleIdentifier {
            lastOtherAppPID = app.processIdentifier
        }
    }

    // MARK: - Hotkey Registration

    @MainActor
    private func registerAllHotkeyListeners() {
        registrationStatus = HotkeyRegistrationStatus()
        registerCarbonHotkey()
        registerEventMonitors()
        installEventTap()
    }

    @MainActor
    private func unregisterAllHotkeyListeners() {
        unregisterCarbonHotkey()
        unregisterEventMonitors()
        removeEventTap()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    @MainActor
    private func observeOtherApplications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
            Task { @MainActor in
                self?.lastOtherAppPID = app.processIdentifier
            }
        }
    }

    @MainActor
    private func registerCarbonHotkey() {
        unregisterCarbonHotkey()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            easyTransCarbonHotkeyHandler,
            1,
            &eventType,
            nil,
            &eventHandler
        )

        guard status == noErr else {
            logger.error("InstallEventHandler failed: \(status)")
            return
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x4554_5154), id: 1)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_D),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        registrationStatus.carbonOK = registerStatus == noErr && hotKeyRef != nil

        if registerStatus != noErr {
            logger.error("RegisterEventHotKey failed: \(registerStatus)")
        }
    }

    private func unregisterCarbonHotkey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    @MainActor
    private func registerEventMonitors() {
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard QuickTranslateService.matchesHotkey(event) else { return event }
                Task { @MainActor in
                    QuickTranslateService.shared.onHotkeyPressed()
                }
                return nil
            }
        }
        self.registrationStatus.localMonitorOK = localMonitor != nil

        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }

        if AccessibilityHelper.isTrusted {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
                guard QuickTranslateService.matchesHotkey(event) else { return }
                Task { @MainActor in
                    QuickTranslateService.shared.onHotkeyPressed()
                }
            }
        }
        self.registrationStatus.globalMonitorOK = globalMonitor != nil
    }

    private func unregisterEventMonitors() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    @MainActor
    private func installEventTap() {
        removeEventTap()
        guard AccessibilityHelper.isTrusted else { return }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: easyTransEventTapCallback,
            userInfo: nil
        ) else {
            logger.error("CGEventTap create failed")
            return
        }

        eventTap = tap
        Self.activeEventTapRef = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.registrationStatus.eventTapOK = true
        logger.info("CGEventTap installed")
    }

    private func removeEventTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
            Self.activeEventTapRef = nil
        }
    }

    fileprivate static func matchesHotkey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return flags.contains(.command)
            && flags.contains(.shift)
            && !flags.contains(.option)
            && !flags.contains(.control)
            && event.keyCode == UInt16(kVK_ANSI_D)
    }

    fileprivate static func matchesCGEvent(_ event: CGEvent) -> Bool {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        return keyCode == Int64(kVK_ANSI_D)
            && flags.contains(.maskCommand)
            && flags.contains(.maskShift)
            && !flags.contains(.maskAlternate)
            && !flags.contains(.maskControl)
    }

    @MainActor
    private func reportStartupIfNeeded() {
        guard !didReportStartup else { return }
        didReportStartup = true

        if registrationStatus.isReady {
            showNotification(
                title: "EasyTrans Plus 快捷键已就绪",
                body: "\(registrationStatus.summary)\n选中文字后按 ⌘⇧D 翻译"
            )
        } else {
            showNotification(
                title: "EasyTrans Plus 快捷键未就绪",
                body: "请授权辅助功能后点击设置中的「刷新状态」，或使用菜单栏图标翻译"
            )
        }
    }

    // MARK: - Translation Flow

    @MainActor
    func onHotkeyPressed() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastTriggerTime > 0.4 else { return }
        lastTriggerTime = now
        guard translateTask == nil else { return }

        let capturedPID = captureTargetAppPID()

        let settings = AppSettings.shared
        guard settings.isConfigured else {
            let hint = "请先在设置中登录云端服务"
            showNotification(title: "EasyTrans Plus", body: hint)
            return
        }

        logger.info("Hotkey triggered — target PID: \(capturedPID ?? -1, privacy: .public)")

        translateTask = Task { @MainActor in
            defer { self.translateTask = nil }

            guard let selectedText = await captureSelectedText(preferredPID: capturedPID) else {
                if TranslationSession.shared.errorMessage == nil {
                    TranslationSession.shared.showMainWindow()
                }
                return
            }

            _ = await performTranslation(text: selectedText, copyToPasteboard: true, showInWindow: true)
        }
    }

    /// 在 EasyTrans 抢焦点之前，尽量锁定用户当时正在使用的应用。
    @MainActor
    private func captureTargetAppPID() -> pid_t? {
        if let app = NSWorkspace.shared.frontmostApplication,
           app.bundleIdentifier != Bundle.main.bundleIdentifier {
            lastOtherAppPID = app.processIdentifier
            return app.processIdentifier
        }
        return lastOtherAppPID
    }

    @MainActor
    func performTranslation(
        text: String,
        copyToPasteboard: Bool,
        showInWindow: Bool = false
    ) async -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if showInWindow {
            TranslationSession.shared.beginQuickTranslate(with: trimmed)
        }

        let settings = AppSettings.shared
        let preferredTarget = settings.targetLanguage
        let languages = TextClassifier.resolveTranslationLanguages(
            text: trimmed,
            preferredTarget: preferredTarget
        )
        let style = TextClassifier.resolveTranslationStyle(
            text: trimmed,
            source: languages.source,
            target: languages.target,
            preferredTarget: preferredTarget
        )
        do {
            let service = TranslationService()
            let result = try await service.translate(
                text: trimmed,
                sourceLanguage: languages.source,
                targetLanguage: languages.target,
                style: style
            ) { chunk in
                Task { @MainActor in
                    if showInWindow {
                        TranslationSession.shared.appendTranslation(chunk)
                    }
                }
            }

            guard !Task.isCancelled else { return nil }

            if showInWindow {
                TranslationSession.shared.finishQuickTranslate()
            }

            if copyToPasteboard {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(TranslationFormatting.plainTextForCopy(result), forType: .string)
            }

            return result
        } catch is CancellationError {
            if showInWindow {
                TranslationSession.shared.finishQuickTranslate()
            }
            return nil
        } catch {
            if showInWindow {
                TranslationSession.shared.failQuickTranslate(error.localizedDescription)
            }
            return nil
        }
    }

    // MARK: - Selection Capture

    @MainActor
    private func captureSelectedText(preferredPID: pid_t?) async -> String? {
        guard AccessibilityHelper.isTrusted else {
            TranslationSession.shared.failQuickTranslate("需要辅助功能权限，请在设置中授权")
            return nil
        }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        let targetPID = preferredPID ?? lastOtherAppPID
        let frontmostIsSelf = NSWorkspace.shared.frontmostApplication?.processIdentifier == ownPID

        // 1. EasyTrans 主窗口内选中（仅当前台是本应用时优先）
        if frontmostIsSelf {
            if let text = selectedTextInEasyTransEditor() {
                return text
            }
        }

        // 2. 从快捷键触发时锁定的外部应用读取
        if let pid = targetPID, pid != ownPID {
            if let text = AccessibilityHelper.selectedText(processID: pid) {
                return text
            }
            if let text = await copySelectionViaSimulatedShortcut(targetPID: pid) {
                return text
            }
        }

        // 3. 当前前台其他应用
        if let text = AccessibilityHelper.selectedTextFromFrontmostOtherApp() {
            return text
        }

        // 4. 模拟 ⌘C 兜底
        if let text = await copySelectionViaSimulatedShortcut(targetPID: targetPID) {
            return text
        }

        // 5. 最后尝试 EasyTrans 编辑器（菜单栏触发等场景）
        if !frontmostIsSelf, let text = selectedTextInEasyTransEditor() {
            return text
        }

        return nil
    }

    @MainActor
    private func selectedTextInEasyTransEditor() -> String? {
        guard let window = NSApp.keyWindow,
              let responder = window.firstResponder as? NSTextView else {
            return nil
        }
        let range = responder.selectedRange()
        guard range.length > 0 else { return nil }
        let text = (responder.string as NSString).substring(with: range)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    @MainActor
    private func copySelectionViaSimulatedShortcut(targetPID: pid_t?) async -> String? {
        guard let pid = targetPID,
              pid != ProcessInfo.processInfo.processIdentifier,
              let app = NSRunningApplication(processIdentifier: pid) else {
            return nil
        }

        app.activate(options: [.activateIgnoringOtherApps])
        try? await Task.sleep(nanoseconds: 120_000_000)

        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount
        postCopyShortcut(to: pid)

        for delay in [50_000_000, 80_000_000, 120_000_000, 150_000_000] as [UInt64] {
            try? await Task.sleep(nanoseconds: delay)
            guard pasteboard.changeCount != changeCount,
                  let copied = pasteboard.string(forType: .string)?
                    .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
                  !copied.isEmpty else {
                continue
            }
            return copied
        }

        return nil
    }

    private func postCopyShortcut(to pid: pid_t) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.postToPid(pid)
        keyUp?.postToPid(pid)
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

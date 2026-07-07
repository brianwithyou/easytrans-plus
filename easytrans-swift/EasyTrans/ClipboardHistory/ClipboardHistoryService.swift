import AppKit
import ApplicationServices
import Carbon.HIToolbox
import os.log
import SwiftUI

// MARK: - C callbacks

private func clipboardHistoryCarbonHotkeyHandler(
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
    guard error == noErr, hotKeyID.id == 2 else {
        return OSStatus(eventNotHandledErr)
    }

    let capturedPID = ClipboardHistoryService.captureFrontmostOtherAppPID()
    Task { @MainActor in
        ClipboardHistoryService.shared.onHotkeyPressed(preferredTargetPID: capturedPID)
    }
    return noErr
}

private func clipboardHistoryEventTapCallback(
    _: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    _: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = ClipboardHistoryService.activeEventTapRef {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return nil
    }

    guard type == .keyDown, ClipboardHistoryService.matchesCGEvent(event) else {
        return Unmanaged.passUnretained(event)
    }

    let capturedPID = ClipboardHistoryService.captureFrontmostOtherAppPID()
    Task { @MainActor in
        ClipboardHistoryService.shared.onHotkeyPressed(preferredTargetPID: capturedPID)
    }
    return nil
}

final class ClipboardHistoryService: NSObject {
    static let shared = ClipboardHistoryService()

    private let logger = Logger(subsystem: "com.easytrans.pro", category: "ClipboardHistory")

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var eventTap: CFMachPort?
    fileprivate static var activeEventTapRef: CFMachPort?

    private var lastTriggerTime: TimeInterval = 0
    private var panel: NSPanel?
    private var panelRootView: ClipboardHistoryPanelRootView?
    private var hostingController: NSHostingController<ClipboardHistoryView>?
    private var targetAppPID: pid_t?
    /// PID captured when the panel opens; used for paste so focus changes while browsing history do not break targeting.
    private var lockedPasteTargetPID: pid_t?
    /// EasyTrans 内打开历史时，记录原文输入框与插入点，避免浏览浮层后丢失光标位置。
    private weak var lockedEasyTransTextView: NSTextView?
    private weak var lockedEasyTransWindow: NSWindow?
    private var lockedEasyTransInsertionRange: NSRange?
    /// Suppresses auto-close on resignKey / other-app activation while paste is in flight.
    private var isPasting = false
    private var outsideClickMonitor: Any?
    private var panelEscapeKeyMonitor: Any?
    private weak var panelSearchField: NSSearchField?
    private var shouldAutoFocusSearch = false

    private override init() {
        super.init()
    }

    @MainActor
    func start() {
        observeOtherApplications()
        observeShortcutChanges()
        registerHotkeyListeners()
        ClipboardHistoryStore.shared.startMonitoring()
        logger.info("Clipboard history started")
    }

    @MainActor
    func stop() {
        // 服务停止时同步持久化，与 applicationWillTerminate 形成双保险。
        ClipboardHistoryStore.shared.flushToDisk()
        ClipboardHistoryStore.shared.stopMonitoring()
        unregisterHotkeyListeners()
        closePanel()
        logger.info("Clipboard history stopped")
    }

    @MainActor
    func refreshListeners() {
        unregisterHotkeyListeners()
        registerHotkeyListeners()
    }

    @MainActor
    func showFromMenu() {
        captureTargetAppPID(preferred: nil)
        lockPasteTarget()
        // 从菜单打开时 EasyTrans 会抢前台；若目标不是本应用，尽量把焦点还给目标应用以保留插入点。
        let ownPID = ProcessInfo.processInfo.processIdentifier
        if let pid = lockedPasteTargetPID,
           pid != ownPID,
           let app = NSRunningApplication(processIdentifier: pid) {
            app.activate(options: [.activateIgnoringOtherApps])
        }
        presentPanel()
    }

    // MARK: - Hotkey

    @MainActor
    func onHotkeyPressed(preferredTargetPID: pid_t? = nil) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastTriggerTime > 0.35 else { return }
        lastTriggerTime = now

        if panel?.isVisible == true {
            closePanel()
            return
        }

        captureTargetAppPID(preferred: preferredTargetPID)
        lockPasteTarget()
        presentPanel()
    }

    /// Synchronous capture for C/event-tap callbacks — must run before async MainActor dispatch.
    fileprivate static func captureFrontmostOtherAppPID() -> pid_t? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return nil
        }
        return app.processIdentifier
    }

    @MainActor
    private func registerHotkeyListeners() {
        registerCarbonHotkey()
        registerEventMonitors()
        installEventTap()
    }

    @MainActor
    private func unregisterHotkeyListeners() {
        unregisterCarbonHotkey()
        unregisterEventMonitors()
        removeEventTap()
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
            clipboardHistoryCarbonHotkeyHandler,
            1,
            &eventType,
            nil,
            &eventHandler
        )

        guard status == noErr else {
            logger.error("InstallEventHandler failed: \(status)")
            return
        }

        let shortcut = KeyboardShortcutPersistence.clipboardHistoryShortcut()
        let hotKeyID = EventHotKeyID(signature: OSType(0x4554_4348), id: 2)
        let registerStatus = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            shortcut.carbonModifierFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

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
        unregisterEventMonitors()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard ClipboardHistoryService.matchesHotkey(event) else { return event }
            let capturedPID = ClipboardHistoryService.captureFrontmostOtherAppPID()
            Task { @MainActor in
                ClipboardHistoryService.shared.onHotkeyPressed(preferredTargetPID: capturedPID)
            }
            return nil
        }

        if AccessibilityHelper.isTrusted {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
                guard ClipboardHistoryService.matchesHotkey(event) else { return }
                let capturedPID = ClipboardHistoryService.captureFrontmostOtherAppPID()
                Task { @MainActor in
                    ClipboardHistoryService.shared.onHotkeyPressed(preferredTargetPID: capturedPID)
                }
            }
        }
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
            callback: clipboardHistoryEventTapCallback,
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
    }

    private func removeEventTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
            Self.activeEventTapRef = nil
        }
    }

    fileprivate static func matchesHotkey(_ event: NSEvent) -> Bool {
        KeyboardShortcutPersistence.clipboardHistoryShortcut().matches(event)
    }

    fileprivate static func matchesCGEvent(_ event: CGEvent) -> Bool {
        KeyboardShortcutPersistence.clipboardHistoryShortcut().matches(event)
    }

    // MARK: - Target app tracking

    @MainActor
    private func observeShortcutChanges() {
        NotificationCenter.default.addObserver(
            forName: .keyboardShortcutsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshListeners()
            }
        }
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
                self?.targetAppPID = app.processIdentifier
                // 用户切换到其他应用时收起浮层（非激活面板未必收到 resignKey）。
                self?.closePanelOnFocusLoss(reason: "other app activated", appName: app.localizedName)
            }
        }
    }

    @MainActor
    private func rememberFrontmostOtherApp() {
        if let pid = Self.captureFrontmostOtherAppPID() {
            targetAppPID = pid
        }
    }

    /// Lock the app the user was in when opening history (before EasyTrans becomes frontmost).
    @MainActor
    private func captureTargetAppPID(preferred: pid_t?) {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        if let preferred, preferred != ownPID, NSRunningApplication(processIdentifier: preferred) != nil {
            clearEasyTransFocusLock()
            targetAppPID = preferred
            logger.info("Captured target app PID from hotkey callback: \(preferred, privacy: .public)")
            return
        }

        if NSWorkspace.shared.frontmostApplication?.processIdentifier == ownPID {
            targetAppPID = ownPID
            captureEasyTransFocus()
            logger.info("Captured EasyTrans as paste target (PID \(ownPID, privacy: .public))")
            return
        }

        clearEasyTransFocusLock()
        rememberFrontmostOtherApp()
        if let pid = targetAppPID {
            logger.info("Captured target app PID from frontmost: \(pid, privacy: .public)")
        } else {
            logger.warning("No frontmost other app; using last tracked PID: \(self.targetAppPID ?? -1, privacy: .public)")
        }
    }

    @MainActor
    private func captureEasyTransFocus() {
        lockedEasyTransTextView = nil
        lockedEasyTransWindow = nil
        lockedEasyTransInsertionRange = nil

        guard let window = NSApp.keyWindow ?? NSApp.mainWindow,
              let textView = window.firstResponder as? NSTextView,
              textView.isEditable else {
            logger.warning("EasyTrans is frontmost but no editable text view is focused")
            return
        }

        lockedEasyTransTextView = textView
        lockedEasyTransWindow = window
        lockedEasyTransInsertionRange = textView.selectedRange()
        logger.info(
            "Captured EasyTrans insertion point at \(self.lockedEasyTransInsertionRange?.location ?? -1, privacy: .public)"
        )
    }

    @MainActor
    private func clearEasyTransFocusLock() {
        lockedEasyTransTextView = nil
        lockedEasyTransWindow = nil
        lockedEasyTransInsertionRange = nil
    }

    // MARK: - Panel

    @MainActor
    private func presentPanel() {
        if panel == nil {
            let rootView = ClipboardHistoryPanelRootView(frame: NSRect(x: 0, y: 0, width: 420, height: 400))
            let controller = NSHostingController(rootView: makePanelView())
            hostingController = controller
            rootView.installHostingView(controller.view)
            rootView.onPrepareForInput = { [weak self] in
                self?.preparePanelForKeyboardInput()
            }
            rootView.searchField.onEscape = { [weak self] in
                self?.closePanel()
            }
            panelRootView = rootView
            panelSearchField = rootView.searchField

            let panel = ClipboardHistoryPanel(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 400),
                styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.title = "剪贴板历史"
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.hidesOnDeactivate = false
            panel.becomesKeyOnlyIfNeeded = false
            panel.isReleasedWhenClosed = false
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.contentView = rootView
            panel.initialFirstResponder = rootView.searchField
            rootView.autoresizingMask = [.width, .height]
            applyRoundedPanelAppearance(to: panel, cornerRadius: 12)
            panel.delegate = PanelDelegate.shared
            PanelDelegate.shared.onClose = { [weak self] in
                self?.closePanel()
            }
            PanelDelegate.shared.onBecomeKey = { [weak self] in
                guard let self, self.shouldAutoFocusSearch else { return }
                self.focusSearchFieldIfNeeded()
            }
            self.panel = panel
        }

        let hasItems = !ClipboardHistoryStore.shared.items.isEmpty
        panelRootView?.setSearchVisible(hasItems)
        panelRootView?.syncSearchFieldFromStore()

        positionPanelNearMouse()
        panel?.orderFrontRegardless()
        installOutsideClickMonitor()
        installPanelEscapeKeyMonitor()
        if hasItems {
            shouldAutoFocusSearch = true
            preparePanelForKeyboardInput()
            autoFocusPanelSearchFieldIfNeeded()
        }
        let count = ClipboardHistoryStore.shared.items.count
        logger.info(
            "Presented clipboard history panel with \(count) persisted item(s), locked paste PID: \(self.lockedPasteTargetPID ?? -1, privacy: .public)"
        )
    }

    @MainActor
    private func makePanelView() -> ClipboardHistoryView {
        ClipboardHistoryView(
            store: ClipboardHistoryStore.shared,
            onPaste: { [weak self] item in
                self?.paste(item)
            },
            onCopy: { [weak self] item in
                self?.copy(item)
            },
            onDismiss: { [weak self] in
                self?.closePanel()
            }
        )
    }

    @MainActor
    private func autoFocusPanelSearchFieldIfNeeded() {
        guard shouldAutoFocusSearch else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let panel = self.panel,
                  panel.isVisible,
                  self.shouldAutoFocusSearch,
                  let field = self.resolvePanelSearchField() else { return }
            self.shouldAutoFocusSearch = false
            self.preparePanelForKeyboardInput()
            self.commitSearchFieldFocus(field)
            self.scheduleSearchFocusRetries(field)
        }
    }

    @MainActor
    private func resolvePanelSearchField() -> NSSearchField? {
        panelSearchField ?? panelRootView?.searchField
    }

    @MainActor
    private func isSearchFieldFocused(_ field: NSSearchField) -> Bool {
        guard let responder = panel?.firstResponder else { return false }
        if responder === field { return true }
        if let editor = field.currentEditor(), responder === editor { return true }
        return false
    }

    /// 让应用与浮层具备接收键盘输入的条件（粘贴目标 PID 在调用前已锁定）。
    @MainActor
    private func preparePanelForKeyboardInput() {
        guard let panel, panel.isVisible else { return }

        preventMainWindowsFromStealingKeyFocus()

        if panel.styleMask.contains(.nonactivatingPanel) {
            panel.styleMask.remove(.nonactivatingPanel)
        }

        NSApp.activate(ignoringOtherApps: true)
        preventMainWindowsFromStealingKeyFocus()
        panel.makeKeyAndOrderFront(nil)
    }

    @MainActor
    private func commitSearchFieldFocus(_ field: NSSearchField) {
        guard let panel, panel.isVisible else { return }

        field.stringValue = ClipboardHistoryStore.shared.searchFilter
        if !panel.makeFirstResponder(field) {
            _ = field.becomeFirstResponder()
        }
        DispatchQueue.main.async { [weak self] in
            self?.placeInsertionCaret(in: field)
        }
    }

    @MainActor
    private func focusSearchFieldIfNeeded() {
        guard shouldAutoFocusSearch,
              !ClipboardHistoryStore.shared.items.isEmpty,
              let field = resolvePanelSearchField() else { return }
        shouldAutoFocusSearch = false
        commitSearchFieldFocus(field)
        scheduleSearchFocusRetries(field)
    }

    @MainActor
    private func placeInsertionCaret(in field: NSSearchField) {
        if let searchField = field as? ClipboardHistorySearchField {
            searchField.placeInsertionCaretAtEnd()
            return
        }
        let length = (field.stringValue as NSString).length
        field.currentEditor()?.selectedRange = NSRange(location: length, length: 0)
    }

    @MainActor
    private func scheduleSearchFocusRetries(_ field: NSSearchField) {
        for delay in [0.05, 0.15, 0.3] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, let panel = self.panel, panel.isVisible else { return }
                if self.isSearchFieldFocused(field) { return }
                self.preparePanelForKeyboardInput()
                self.commitSearchFieldFocus(field)
            }
        }
    }

    /// 保持翻译主窗口可见，仅让其输入框放弃 first responder，避免抢走剪贴板搜索框焦点。
    @MainActor
    private func preventMainWindowsFromStealingKeyFocus() {
        guard let panel else { return }
        for window in NSApp.windows where window !== panel && window.canBecomeMain && window.isVisible {
            if let responder = window.firstResponder as? NSTextView {
                _ = window.makeFirstResponder(nil)
            }
        }
    }

    @MainActor
    private func installPanelEscapeKeyMonitor() {
        removePanelEscapeKeyMonitor()
        panelEscapeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  let panel = self.panel,
                  panel.isVisible,
                  panel.isKeyWindow,
                  Int(event.keyCode) == kVK_Escape else { return event }
            self.closePanel()
            return nil
        }
    }

    @MainActor
    private func removePanelEscapeKeyMonitor() {
        if let panelEscapeKeyMonitor {
            NSEvent.removeMonitor(panelEscapeKeyMonitor)
            self.panelEscapeKeyMonitor = nil
        }
    }

    @MainActor
    private func restorePanelInputEnvironment() {
        PanelDelegate.shared.onBecomeKey = nil
        removePanelEscapeKeyMonitor()
        if let panel, !panel.styleMask.contains(.nonactivatingPanel) {
            panel.styleMask.insert(.nonactivatingPanel)
        }
        DockVisibility.updateAfterMainWindowChange()
    }

    @MainActor
    private func applyRoundedPanelAppearance(to panel: NSPanel, cornerRadius: CGFloat) {
        guard let contentView = panel.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = cornerRadius
        contentView.layer?.masksToBounds = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        panel.invalidateShadow()
    }

    @MainActor
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

    @MainActor
    private func closePanel() {
        removeOutsideClickMonitor()
        restorePanelInputEnvironment()
        panel?.orderOut(nil)
        resetPanelSearchState()
    }

    /// 收起面板时清空搜索，避免下次打开仍停留在过滤状态。
    @MainActor
    private func resetPanelSearchState() {
        panelSearchField = nil
        shouldAutoFocusSearch = false
        ClipboardHistoryStore.shared.resetSearchFilter()
        guard let hostingController else { return }
        hostingController.rootView = makePanelView()
    }

    /// 点击面板外区域时收起；不抢焦点时无法用 resignKey 检测外点。
    @MainActor
    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.closePanelIfClickOutside()
            }
        }
    }

    @MainActor
    private func removeOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    @MainActor
    private func closePanelIfClickOutside() {
        guard panel?.isVisible == true, !isPasting else { return }
        guard let panel else { return }
        let click = NSEvent.mouseLocation
        if !panel.frame.contains(click) {
            closePanelOnFocusLoss(reason: "click outside panel")
        }
    }

    /// 面板失焦时自动收起；热键切换、粘贴等路径仍走 `closePanel()`。
    @MainActor
    private func closePanelOnFocusLoss(reason: String, appName: String? = nil) {
        guard panel?.isVisible == true else { return }
        guard !isPasting else {
            logger.debug("Ignoring focus loss during paste (\(reason, privacy: .public))")
            return
        }
        if let appName {
            logger.debug("Closing clipboard history panel on focus loss (\(reason, privacy: .public), app: \(appName, privacy: .public))")
        } else {
            logger.debug("Closing clipboard history panel on focus loss (\(reason, privacy: .public))")
        }
        closePanel()
    }

    // MARK: - Copy & Paste

    @MainActor
    private func copy(_ item: ClipboardHistoryItem) {
        guard !item.text.isEmpty else {
            logger.debug("Copy ignored — empty clipboard history item")
            return
        }

        ClipboardHistoryStore.shared.preparePasteboardUpdate()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        logger.info("Copied clipboard history item to pasteboard (\(item.text.count, privacy: .public) chars)")
    }

    @MainActor
    private func paste(_ item: ClipboardHistoryItem) {
        guard !isPasting else {
            logger.debug("Paste ignored — another paste is in flight")
            return
        }

        ClipboardHistoryStore.shared.promoteToFront(item)

        guard AccessibilityHelper.isTrusted else {
            logger.error("Paste requires accessibility permission")
            presentPasteFailureAlert("需要「辅助功能」权限才能粘贴到原应用。请在系统设置中授权 EasyTrans Plus。")
            return
        }

        guard let pid = lockedPasteTargetPID,
              let app = NSRunningApplication(processIdentifier: pid) else {
            logger.error(
                "Paste failed: no locked target application (locked PID: \(self.lockedPasteTargetPID ?? -1, privacy: .public))"
            )
            let shortcut = KeyboardShortcutPersistence.clipboardHistoryShortcut().displayString
            presentPasteFailureAlert("无法确定要粘贴的目标应用。请先在输入框中定位光标，再按 \(shortcut) 打开历史并双击条目。")
            return
        }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        isPasting = true
        logger.info("Paste started — target PID \(pid, privacy: .public), \(item.text.count, privacy: .public) chars")

        removeOutsideClickMonitor()

        if pid == ownPID {
            pasteIntoEasyTransEditor(item.text)
            restoreEasyTransWindowFocus()
            schedulePanelHideAfterPaste(reason: "EasyTrans self-paste")
            return
        }

        ClipboardHistoryStore.shared.preparePasteboardUpdate()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        logger.info("Wrote clipboard history item to pasteboard")

        let targetIsFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
        if !targetIsFrontmost {
            app.activate(options: [.activateIgnoringOtherApps])
            logger.info("Activated target app PID \(pid, privacy: .public)")
        } else {
            logger.info("Target app PID \(pid, privacy: .public) already frontmost — skipping activate")
        }

        panel?.orderOut(nil)
        logger.info("Panel hidden for paste")

        Task { @MainActor in
            defer {
                self.isPasting = false
                self.clearEasyTransFocusLock()
            }
            let delay: UInt64 = targetIsFrontmost ? 60_000_000 : 180_000_000
            try? await Task.sleep(nanoseconds: delay)
            self.postPasteShortcut(to: pid)
            logger.info("Paste flow completed for PID \(pid, privacy: .public)")
        }
    }

    /// 双击粘贴时若立刻隐藏浮层，第二次点击会穿透到下层窗口（可能误触关闭按钮）。
    @MainActor
    private func schedulePanelHideAfterPaste(reason: String) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            self.panel?.orderOut(nil)
            self.isPasting = false
            self.clearEasyTransFocusLock()
            self.logger.info("Panel hidden after paste (\(reason, privacy: .public))")
        }
    }

    @MainActor
    private func pasteIntoEasyTransEditor(_ text: String) {
        guard let textView = lockedEasyTransTextView ?? focusedEditableTextViewInEasyTrans() else {
            isPasting = false
            logger.error("Paste into EasyTrans failed: no editable text view")
            let shortcut = KeyboardShortcutPersistence.clipboardHistoryShortcut().displayString
            presentPasteFailureAlert("请先在原文输入框中点击定位光标，再按 \(shortcut) 打开历史并双击条目。")
            return
        }

        let range = lockedEasyTransInsertionRange ?? textView.selectedRange()
        textView.setSelectedRange(range)
        textView.insertText(text, replacementRange: range)
        logger.info("Inserted clipboard history text into EasyTrans editor at \(range.location, privacy: .public)")
    }

    @MainActor
    private func restoreEasyTransWindowFocus() {
        NSApp.activate(ignoringOtherApps: true)

        let window = lockedEasyTransWindow ?? lockedEasyTransTextView?.window
        if let window {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }

        if let textView = lockedEasyTransTextView {
            window?.makeFirstResponder(textView)
        }
    }

    @MainActor
    private func focusedEditableTextViewInEasyTrans() -> NSTextView? {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow,
              let textView = window.firstResponder as? NSTextView,
              textView.isEditable else {
            return nil
        }
        return textView
    }

    @MainActor
    private func presentPasteFailureAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "无法粘贴"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        if !AccessibilityHelper.isTrusted {
            alert.addButton(withTitle: "打开辅助功能设置")
        }
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            AccessibilityHelper.openSystemSettings()
        }
    }

    @MainActor
    private func lockPasteTarget() {
        if let pid = targetAppPID,
           NSRunningApplication(processIdentifier: pid) != nil {
            lockedPasteTargetPID = pid
        } else {
            lockedPasteTargetPID = nil
        }
        logger.info("Locked paste target PID: \(self.lockedPasteTargetPID ?? -1, privacy: .public)")
    }

    private func postPasteShortcut(to pid: pid_t) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.postToPid(pid)
        keyUp?.postToPid(pid)
        logger.info("Posted simulated ⌘V to PID \(pid, privacy: .public)")
    }
}

private final class PanelDelegate: NSObject, NSWindowDelegate {
    static let shared = PanelDelegate()
    var onClose: (() -> Void)?
    var onBecomeKey: (() -> Void)?

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        onBecomeKey?()
    }
}

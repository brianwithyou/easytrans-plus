import AppKit
import Carbon.HIToolbox
import os.log
import SwiftUI

// MARK: - C callbacks

private func stickyNoteCarbonHotkeyHandler(
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
    guard error == noErr, hotKeyID.id == 3 else {
        return OSStatus(eventNotHandledErr)
    }

    Task { @MainActor in
        StickyNoteService.shared.createNoteAtCursor()
    }
    return noErr
}

private func stickyNoteEventTapCallback(
    _: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    _: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = StickyNoteService.activeEventTapRef {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return nil
    }

    guard type == .keyDown, StickyNoteService.matchesCGEvent(event) else {
        return Unmanaged.passUnretained(event)
    }

    Task { @MainActor in
        StickyNoteService.shared.createNoteAtCursor()
    }
    return nil
}

final class StickyNotePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class StickyNoteService: NSObject {
    static let shared = StickyNoteService()

    private let logger = Logger(subsystem: "com.easytrans.pro", category: "StickyNote")
    private static let shortcut = KeyboardShortcut.stickyNoteDefault

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var eventTap: CFMachPort?
    fileprivate static var activeEventTapRef: CFMachPort?

    private var lastTriggerTime: TimeInterval = 0
    private var notes: [UUID: StickyNoteInstance] = [:]

    private override init() {
        super.init()
    }

    @MainActor
    func start() {
        registerHotkeyListeners()
        logger.info("Sticky note service started")
    }

    @MainActor
    func stop() {
        unregisterHotkeyListeners()
        closeAllNotes()
        logger.info("Sticky note service stopped")
    }

    @MainActor
    func refreshListeners() {
        unregisterHotkeyListeners()
        registerHotkeyListeners()
    }

    @MainActor
    func createNoteFromMenu() {
        createNoteAtCursor()
    }

    @MainActor
    func createNoteAtCursor() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastTriggerTime > 0.35 else { return }
        lastTriggerTime = now

        let note = StickyNoteInstance()
        notes[note.id] = note
        note.onClose = { [weak self, weak note] in
            Task { @MainActor in
                guard let self, let note else { return }
                self.removeNote(note)
            }
        }
        note.presentNearMouse()
    }

    @MainActor
    private func removeNote(_ note: StickyNoteInstance) {
        note.close()
        notes.removeValue(forKey: note.id)
    }

    @MainActor
    private func closeAllNotes() {
        for note in notes.values {
            note.close()
        }
        notes.removeAll()
    }

    // MARK: - Hotkey

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
            stickyNoteCarbonHotkeyHandler,
            1,
            &eventType,
            nil,
            &eventHandler
        )

        guard status == noErr else {
            logger.error("InstallEventHandler failed: \(status)")
            return
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x4554_534E), id: 3)
        let registerStatus = RegisterEventHotKey(
            UInt32(Self.shortcut.keyCode),
            Self.shortcut.carbonModifierFlags,
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
            guard StickyNoteService.matchesHotkey(event) else { return event }
            Task { @MainActor in
                StickyNoteService.shared.createNoteAtCursor()
            }
            return nil
        }

        if AccessibilityHelper.isTrusted {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
                guard StickyNoteService.matchesHotkey(event) else { return }
                Task { @MainActor in
                    StickyNoteService.shared.createNoteAtCursor()
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
            callback: stickyNoteEventTapCallback,
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

    @MainActor
    private func removeEventTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
            Self.activeEventTapRef = nil
        }
    }

    fileprivate static func matchesHotkey(_ event: NSEvent) -> Bool {
        shortcut.matches(event)
    }

    fileprivate static func matchesCGEvent(_ event: CGEvent) -> Bool {
        shortcut.matches(event)
    }
}

@MainActor
private final class StickyNoteState: ObservableObject {
    @Published var text = ""
    @Published var isPinned = false
}

@MainActor
private final class StickyNoteInstance: NSObject, NSWindowDelegate {
    let id = UUID()
    var onClose: (() -> Void)?

    private let state = StickyNoteState()
    private var panel: StickyNotePanel?
    private var hostingController: NSHostingController<StickyNoteRootView>?
    private var escapeKeyMonitor: Any?

    func presentNearMouse() {
        if panel == nil {
            buildPanel()
        }

        positionPanelNearMouse()
        panel?.makeKeyAndOrderFront(nil)
        installEscapeKeyMonitor()
    }

    func close() {
        removeEscapeKeyMonitor()
        panel?.orderOut(nil)
        panel = nil
        hostingController = nil
    }

    private func buildPanel() {
        let rootView = StickyNoteRootView(
            state: state,
            onClose: { [weak self] in self?.onClose?() },
            onPinToggle: { [weak self] in self?.togglePin() }
        )

        let controller = NSHostingController(rootView: rootView)
        hostingController = controller

        let panel = StickyNotePanel(
            contentRect: NSRect(x: 0, y: 0, width: 268, height: 220),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "便签"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.contentView = controller.view
        panel.delegate = self
        applyPanelAppearance(to: panel)
        updateMovableState(on: panel)
        self.panel = panel
    }

    private func togglePin() {
        state.isPinned.toggle()
        guard let panel else { return }
        updateMovableState(on: panel)
    }

    private func updateMovableState(on panel: NSPanel) {
        panel.isMovableByWindowBackground = !state.isPinned
    }

    private func positionPanelNearMouse() {
        guard let panel else { return }
        let screen = screenForMouse() ?? NSScreen.main
        guard let screen else { return }

        let mouse = NSEvent.mouseLocation
        let panelSize = panel.frame.size
        var origin = NSPoint(
            x: mouse.x + 12,
            y: mouse.y - panelSize.height - 12
        )

        let visible = screen.visibleFrame
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - panelSize.width - 8)
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - panelSize.height - 8)
        panel.setFrameOrigin(origin)
    }

    private func screenForMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
    }

    private func applyPanelAppearance(to panel: NSPanel) {
        guard let contentView = panel.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 14
        contentView.layer?.masksToBounds = true
    }

    private func installEscapeKeyMonitor() {
        removeEscapeKeyMonitor()
        escapeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  let panel = self.panel,
                  panel.isVisible,
                  panel.isKeyWindow,
                  Int(event.keyCode) == kVK_Escape else { return event }
            self.onClose?()
            return nil
        }
    }

    private func removeEscapeKeyMonitor() {
        if let escapeKeyMonitor {
            NSEvent.removeMonitor(escapeKeyMonitor)
            self.escapeKeyMonitor = nil
        }
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}

private struct StickyNoteRootView: View {
    @ObservedObject var state: StickyNoteState
    var onClose: () -> Void
    var onPinToggle: () -> Void

    var body: some View {
        StickyNoteView(
            text: $state.text,
            isPinned: $state.isPinned,
            onClose: onClose,
            onPinToggle: onPinToggle
        )
    }
}

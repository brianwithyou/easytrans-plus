import AppKit
import SwiftUI

@MainActor
final class TranslationSession: ObservableObject {
    static let shared = TranslationSession()

    @Published var sourceText = ""
    @Published var translatedText = ""
    @Published var isTranslating = false
    @Published var errorMessage: String?

    /// 由 ContentView 注册，用于主窗口被关闭时通过 SwiftUI 重新打开。
    private var openWindowHandler: (() -> Void)?

    private init() {}

    func registerOpenWindowHandler(_ handler: @escaping () -> Void) {
        openWindowHandler = handler
    }

    func beginQuickTranslate(with source: String) {
        sourceText = source
        translatedText = ""
        isTranslating = true
        errorMessage = nil
        showMainWindow()
    }

    func appendTranslation(_ chunk: String) {
        translatedText += chunk
    }

    func finishQuickTranslate() {
        isTranslating = false
        showMainWindow()
    }

    func failQuickTranslate(_ message: String) {
        isTranslating = false
        errorMessage = message
        showMainWindow()
    }

    func showMainWindow() {
        DockVisibility.showInDockIfNeeded()
        NSApp.unhide(nil)

        var target = resolveMainWindow()
        if target == nil || !isPresentableMainWindow(target) {
            openWindowHandler?()
            target = resolveMainWindow()
        }

        if let target, isPresentableMainWindow(target) {
            activateAndPresent(target)
        }

        // 抓取选中文字时可能短暂激活了其他应用；openWindow 也可能异步创建窗口，下一轮再试。
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.activateAndPresent(self.resolveMainWindow())
        }
    }

    private func resolveMainWindow() -> NSWindow? {
        let candidateWindows = NSApp.windows.filter { window in
            window.contentView != nil && !(window is NSPanel) && window.canBecomeMain
        }
        return candidateWindows.first { $0.isVisible && !$0.isMiniaturized }
            ?? candidateWindows.first { !$0.isMiniaturized }
            ?? candidateWindows.first
    }

    private func isPresentableMainWindow(_ window: NSWindow?) -> Bool {
        guard let window else { return false }
        return window.canBecomeMain
    }

    private func activateAndPresent(_ window: NSWindow?) {
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)

        guard let window, isPresentableMainWindow(window) else { return }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.orderFrontRegardless()
        if window.canBecomeKey {
            window.makeKeyAndOrderFront(nil)
        }
        if window.canBecomeMain {
            window.makeMain()
        }
    }
}

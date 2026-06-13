import AppKit
import SwiftUI

extension Notification.Name {
    /// ContentView 已完成加载并注册 openWindow，可安全隐藏启动时的主窗口。
    static let mainWindowContentDidLoad = Notification.Name("com.easytrans.pro.mainWindowContentDidLoad")
}

@MainActor
final class TranslationSession: ObservableObject {
    static let shared = TranslationSession()

    @Published var sourceText = ""
    @Published var translatedText = ""
    @Published var isTranslating = false
    @Published var errorMessage: String?

    /// 由 ContentView 注册，用于主窗口被关闭时通过 SwiftUI 重新打开。
    private var openWindowHandler: (() -> Void)?
    private var pendingWindowOpen = false

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
        bringMainWindowToFront()
    }

    func failQuickTranslate(_ message: String) {
        isTranslating = false
        errorMessage = message
        showMainWindow()
    }

    func showMainWindow() {
        DockVisibility.prepareForWindowPresentation()
        NSApp.unhide(nil)
        presentMainWindow(allowCreate: true)
    }

    private func bringMainWindowToFront() {
        DockVisibility.prepareForWindowPresentation()
        presentMainWindow(allowCreate: false)
    }

    /// 优先复用已有主窗口；仅在确实没有窗口时才创建，并清理重复窗口。
    private func presentMainWindow(allowCreate: Bool) {
        if let keeper = pickMainWindow() {
            activateAndPresent(keeper)
            closeExtraMainWindows(keeping: keeper)
            return
        }

        guard allowCreate else { return }
        guard !pendingWindowOpen else { return }

        pendingWindowOpen = true
        DispatchQueue.main.async { [weak self] in
            self?.finishPresentingMainWindow()
        }
    }

    private func finishPresentingMainWindow() {
        defer { pendingWindowOpen = false }

        // SwiftUI 可能在启动时已创建但被隐藏的默认窗口，先等一轮再判断是否需要 openWindow。
        if let keeper = pickMainWindow() {
            activateAndPresent(keeper)
            closeExtraMainWindows(keeping: keeper)
            return
        }

        openWindowHandler?()
        if pickMainWindow() == nil {
            openMainWindowViaURL()
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.pickMainWindow() == nil {
                self.openWindowHandler?()
                if self.pickMainWindow() == nil {
                    self.openMainWindowViaURL()
                }
            }
            guard let keeper = self.pickMainWindow() else { return }
            self.activateAndPresent(keeper)
            self.closeExtraMainWindows(keeping: keeper)
        }
    }

    private func openMainWindowViaURL() {
        guard let url = URL(string: "easytrans://main") else { return }
        NSWorkspace.shared.open(url)
    }

    private func allMainWindows() -> [NSWindow] {
        NSApp.windows.filter { window in
            !(window is NSPanel) && window.canBecomeMain
        }
    }

    private func pickMainWindow() -> NSWindow? {
        let windows = allMainWindows()
        return windows.first { $0.isKeyWindow }
            ?? windows.first { $0.isMainWindow }
            ?? windows.first { $0.isVisible && !$0.isMiniaturized }
            ?? windows.first { !$0.isMiniaturized }
            ?? windows.first
    }

    private func closeExtraMainWindows(keeping keeper: NSWindow) {
        for window in allMainWindows() where window !== keeper {
            window.close()
        }
    }

    private func activateAndPresent(_ window: NSWindow?) {
        DockVisibility.prepareForWindowPresentation()
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])

        guard let window else { return }
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

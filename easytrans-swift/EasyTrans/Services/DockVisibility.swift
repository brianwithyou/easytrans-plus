import AppKit

enum DockVisibility {
    /// 菜单栏常驻应用：不显示 Dock 图标，也不出现在 ⌘Tab 中。
    static func hideFromDock() {
        NSApp.setActivationPolicy(.accessory)
    }

    /// 打开主窗口时临时切换为普通应用，以便窗口正常获得焦点。
    static func showInDockIfNeeded() {
        NSApp.setActivationPolicy(.regular)
    }

    /// 主窗口全部关闭后恢复为菜单栏应用。
    static func updateAfterMainWindowChange() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let hasVisibleMainWindow = NSApp.windows.contains { window in
                window.canBecomeMain && window.isVisible && !window.isMiniaturized
            }
            if !hasVisibleMainWindow {
                hideFromDock()
            }
        }
    }

    /// 启动时隐藏 SwiftUI 自动创建的主窗口。
    static func suppressInitialMainWindows() {
        for window in NSApp.windows where window.canBecomeMain {
            window.orderOut(nil)
        }
    }
}

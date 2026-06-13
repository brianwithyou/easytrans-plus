import AppKit

enum DockVisibility {
    /// 菜单栏常驻应用：不显示 Dock 图标，也不出现在 ⌘Tab 中。
    static func hideFromDock() {
        NSApp.setActivationPolicy(.accessory)
    }

    /// `.accessory` 下窗口难以获焦；展示主窗口前切回 `.regular`（LSUIElement 仍隐藏 Dock）。
    static func prepareForWindowPresentation() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 主窗口全部关闭后确保保持菜单栏模式。
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
}

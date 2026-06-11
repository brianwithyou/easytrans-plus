import SwiftUI

struct MenuBarContent: View {
    var body: some View {
        let status = QuickTranslateService.shared.registrationStatus

        Button("翻译选中文字  ⌘⇧D") {
            QuickTranslateService.shared.triggerFromMenu()
        }

        Button("剪贴板历史  ⌘⇧V") {
            ClipboardHistoryService.shared.showFromMenu()
        }

        Button("打开主窗口") {
            TranslationSession.shared.showMainWindow()
        }

        Divider()

        Text("快捷键状态：\(status.summary)")
            .font(.caption)
            .foregroundStyle(status.isReady ? .primary : .secondary)

        if !AccessibilityHelper.isTrusted {
            Button("打开辅助功能设置…") {
                AccessibilityHelper.openSystemSettings()
            }
        }

        Button("刷新快捷键") {
            QuickTranslateService.shared.refreshListeners()
            ClipboardHistoryService.shared.refreshListeners()
        }

        Divider()

        Button("退出 EasyTrans Pro") {
            NSApp.terminate(nil)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DockVisibility.hideFromDock()

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow, window.canBecomeMain else { return }
            DockVisibility.updateAfterMainWindowChange()
        }

        DispatchQueue.main.async {
            DockVisibility.suppressInitialMainWindows()
            QuickTranslateService.shared.start()
            ClipboardHistoryService.shared.start()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        QuickTranslateService.shared.refreshListeners()
        ClipboardHistoryService.shared.refreshListeners()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 退出前将剪贴板历史落盘，避免最后一次变更未写入。
        ClipboardHistoryStore.shared.flushToDisk()
        QuickTranslateService.shared.stop()
        ClipboardHistoryService.shared.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct EasyTransApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(settings)
                .onAppear {
                    QuickTranslateService.shared.start()
                    ClipboardHistoryService.shared.start()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 640)

        MenuBarExtra("EasyTrans Pro", systemImage: "character.bubble") {
            MenuBarContent()
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(settings)
        }
        .commands {
            CommandMenu("翻译") {
                Button("翻译选中文字") {
                    QuickTranslateService.shared.triggerFromMenu()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
            CommandMenu("剪贴板") {
                Button("查看剪贴板历史") {
                    ClipboardHistoryService.shared.showFromMenu()
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
            }
        }
    }
}

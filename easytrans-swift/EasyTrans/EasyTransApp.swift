import SwiftUI

struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var cloudAuth = CloudAuthService.shared
    @ObservedObject private var shortcutSettings = KeyboardShortcutSettings.shared

    var body: some View {
        let status = QuickTranslateService.shared.registrationStatus

        Button("翻译选中文字") {
            QuickTranslateService.shared.triggerFromMenu()
        }
        .keyboardShortcut(shortcutSettings.translateShortcut)

        Button("剪贴板历史") {
            ClipboardHistoryService.shared.showFromMenu()
        }
        .keyboardShortcut(shortcutSettings.clipboardHistoryShortcut)

        Button("打开主窗口") {
            openMainWindow()
        }

        Button("设置…") {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
        .keyboardShortcut(.openSettings)

        if !cloudAuth.isLoggedIn {
            Button("登录…") {
                openMainWindow()
                cloudAuth.presentLogin()
            }

            Button("注册…") {
                openMainWindow()
                cloudAuth.presentRegister()
            }

            Divider()
        }

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

        Button("退出 EasyTrans Plus") {
            NSApp.terminate(nil)
        }
        .onAppear {
            TranslationSession.shared.registerOpenWindowHandler {
                openWindow(id: "main")
            }
        }
    }

    private func openMainWindow() {
        TranslationSession.shared.registerOpenWindowHandler {
            openWindow(id: "main")
        }
        TranslationSession.shared.showMainWindow()
    }
}

private struct AuthSheetView: View {
    @ObservedObject private var cloudAuth = CloudAuthService.shared
    let prompt: CloudAuthService.AuthPrompt

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(prompt == .login ? "登录" : "注册")
                .font(.headline)

            AuthPanelView(initialScreen: prompt.initialScreen) {
                cloudAuth.dismissAuthPrompt()
            }
        }
        .padding(24)
        .frame(width: 360)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
    }
}

private struct AuthPromptOverlay: View {
    @ObservedObject private var cloudAuth = CloudAuthService.shared
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        if let prompt = cloudAuth.authPrompt {
            ZStack {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        cloudAuth.dismissAuthPrompt()
                    }

                AuthSheetView(prompt: prompt)
                    .environmentObject(settings)
            }
            .transition(.opacity)
            .onExitCommand {
                cloudAuth.dismissAuthPrompt()
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        KeychainStore.migrateIfNeeded()
        DockVisibility.hideFromDock()

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow, window.canBecomeMain else { return }
            DockVisibility.updateAfterMainWindowChange()
        }

        NotificationCenter.default.addObserver(
            forName: .mainWindowContentDidLoad,
            object: nil,
            queue: .main
        ) { _ in
            TranslationSession.shared.showMainWindow()
        }

        DispatchQueue.main.async {
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
                .overlay {
                    AuthPromptOverlay()
                        .environmentObject(settings)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 640)
        .handlesExternalEvents(matching: Set(arrayLiteral: "*", "easytrans"))

        MenuBarExtra("EasyTrans Plus", systemImage: "character.bubble") {
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

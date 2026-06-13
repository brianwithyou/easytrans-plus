import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var cloudAuth = CloudAuthService.shared
    @State private var accessibilityTrusted = AccessibilityHelper.isTrusted

    @State private var loginEmail = ""
    @State private var loginPassword = ""
    @State private var registerCode = ""
    @State private var sendCodeCountdown = 0
    @State private var authMessage: String?
    @State private var authIsError = false
    @State private var isAuthBusy = false

    var body: some View {
        ScrollView {
            Form {
                cloudSection

                Section("通用") {
                    Toggle("登录时自动启动", isOn: $settings.launchAtLogin)

                    Text("EasyTrans Plus 常驻菜单栏，不会在 Dock 中显示图标。可在「系统设置 → 通用 → 登录项」中管理开机启动。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                accessibilitySection
            }
            .formStyle(.grouped)
            .padding(20)
        }
        .frame(width: 540, height: 680)
        .onAppear {
            refreshAccessibilityStatus()
            settings.refreshLaunchAtLoginStatus()
            if loginEmail.isEmpty {
                loginEmail = settings.cloudAccount?.email ?? KeychainStore.load(account: .accountEmail) ?? ""
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshAccessibilityStatus()
        }
    }

    @ViewBuilder
    private var cloudSection: some View {
        Section("云端服务") {
            if cloudAuth.isLoggedIn, let account = settings.cloudAccount {
                VStack(alignment: .leading, spacing: 6) {
                    LabeledContent("账号") {
                        Text(account.email)
                    }
                    LabeledContent("套餐") {
                        Text(account.planName)
                    }
                    if let quotaSummary = account.quotaSummary {
                        LabeledContent("用量") {
                            Text(quotaSummary)
                        }
                    }
                }

                HStack {
                    Button("刷新账号信息") {
                        Task { await refreshProfile() }
                    }
                    Button("退出登录", role: .destructive) {
                        cloudAuth.logout(settings: settings)
                        authMessage = nil
                    }
                }
            } else {
                TextField("邮箱", text: $loginEmail)
                    .textFieldStyle(.roundedBorder)

                SecureField("密码", text: $loginPassword)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    TextField("验证码", text: $registerCode)
                        .textFieldStyle(.roundedBorder)

                    Button(sendCodeButtonTitle) {
                        Task { await sendRegisterCode() }
                    }
                    .disabled(isAuthBusy || sendCodeCountdown > 0 || loginEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Text("注册前请先获取邮箱验证码。本地开发环境验证码固定为 123456。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("登录") {
                        Task { await login() }
                    }
                    .disabled(isAuthBusy)

                    Button("注册") {
                        Task { await register() }
                    }
                    .disabled(isAuthBusy)
                }
            }

            if let authMessage {
                Text(authMessage)
                    .font(.caption)
                    .foregroundStyle(authIsError ? Color.orange : Color.secondary)
            }
        }
    }

    @ViewBuilder
    private var accessibilitySection: some View {
        Section("快捷翻译") {
            LabeledContent("全局快捷键") {
                Text("⌘⇧D")
                    .monospaced()
            }

            LabeledContent("辅助功能权限") {
                HStack(spacing: 6) {
                    Circle()
                        .fill(accessibilityTrusted ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(accessibilityTrusted ? "已授权" : "未授权")
                        .foregroundStyle(accessibilityTrusted ? Color.primary : Color.orange)
                }
            }

            Text("在其他应用中选中文字并翻译，需要辅助功能权限。EasyTrans Plus 窗口内选中文字翻译不需要此权限。")
                .font(.caption)
                .foregroundStyle(.secondary)

            if AccessibilityHelper.isStableProjectBuild {
                Text("当前从项目固定路径 build/Debug 运行。对该路径授权一次后，日常 ⌘R 重新编译通常无需重复授权。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if AccessibilityHelper.isRunningFromDerivedData {
                Text("当前从 Xcode DerivedData 运行。每次重新编译后路径可能变化，辅助功能授权容易失效。请改用 Xcode ⌘R 构建（已配置输出到项目 build/Debug 目录）。")
                    .font(.caption)
                    .foregroundStyle(Color.orange)
            }

            if !accessibilityTrusted {
                Text("授权后请完全退出 EasyTrans Plus（⌘Q）再重新打开，系统才会生效。若列表里已有 EasyTrans Plus 但仍显示未授权，请删除旧条目，用「在 Finder 中显示应用」拖入新的 EasyTrans Plus.app。")
                    .font(.caption)
                    .foregroundStyle(Color.orange)

                Text("添加权限时找不到 Library 文件夹？macOS 默认隐藏它。请用下方「在 Finder 中显示应用」，把弹出的 EasyTrans Plus 直接拖进辅助功能列表。")
                    .font(.caption)
                    .foregroundStyle(Color.orange)
            }

            Text(AccessibilityHelper.bundlePath)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack {
                Button("在 Finder 中显示应用") {
                    AccessibilityHelper.revealInFinder()
                }
                Button("请求授权") {
                    _ = AccessibilityHelper.requestPermission()
                    refreshAccessibilityStatus()
                }
                Button("打开系统设置") {
                    AccessibilityHelper.openSystemSettings()
                }
                Button("刷新状态") {
                    refreshAccessibilityStatus()
                }
            }
        }
    }

    private var sendCodeButtonTitle: String {
        sendCodeCountdown > 0 ? "\(sendCodeCountdown)s" : "获取验证码"
    }

    private func refreshAccessibilityStatus() {
        accessibilityTrusted = AccessibilityHelper.isTrusted
        QuickTranslateService.shared.refreshListeners()
    }

    private func login() async {
        await performAuth {
            try await cloudAuth.login(email: loginEmail, password: loginPassword, settings: settings)
        }
    }

    private func register() async {
        await performAuth(clearsPassword: true) {
            try await cloudAuth.register(
                email: loginEmail,
                password: loginPassword,
                code: registerCode,
                settings: settings
            )
        }
    }

    private func sendRegisterCode() async {
        isAuthBusy = true
        authMessage = nil
        defer { isAuthBusy = false }

        do {
            try await cloudAuth.sendRegisterCode(email: loginEmail, settings: settings)
            authIsError = false
            authMessage = "验证码已发送，请查收邮件"
            registerCode = ""
            startSendCodeCountdown()
        } catch {
            authIsError = true
            authMessage = error.localizedDescription
        }
    }

    private func startSendCodeCountdown() {
        sendCodeCountdown = 60
        Task {
            while sendCodeCountdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                sendCodeCountdown -= 1
            }
        }
    }

    private func refreshProfile() async {
        await performAuth {
            try await cloudAuth.refreshProfile(settings: settings)
        }
    }

    private func performAuth(clearsPassword: Bool = false, _ action: () async throws -> Void) async {
        isAuthBusy = true
        authMessage = nil
        defer { isAuthBusy = false }

        do {
            try await action()
            authIsError = false
            authMessage = "操作成功"
            if clearsPassword {
                loginPassword = ""
                registerCode = ""
            }
        } catch {
            authIsError = true
            authMessage = error.localizedDescription
        }
    }
}

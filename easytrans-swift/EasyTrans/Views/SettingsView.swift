import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var cloudAuth = CloudAuthService.shared
    @State private var accessibilityTrusted = AccessibilityHelper.isTrusted

    @State private var loginEmail = ""
    @State private var loginPassword = ""
    @State private var licenseKey = ""
    @State private var authMessage: String?
    @State private var authIsError = false
    @State private var isAuthBusy = false

    private let modelOptions = ["qwen-turbo", "qwen-plus", "qwen-max", "qwen-long"]

    var body: some View {
        ScrollView {
            Form {
                Section("翻译通道") {
                    Picker("翻译方式", selection: $settings.translationMode) {
                        ForEach(TranslationMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(translationModeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if settings.translationMode == .byok {
                    byokSection
                } else {
                    cloudSection
                }

                Section("通用") {
                    Toggle("登录时自动启动", isOn: $settings.launchAtLogin)

                    Text("EasyTrans Pro 常驻菜单栏，不会在 Dock 中显示图标。可在「系统设置 → 通用 → 登录项」中管理开机启动。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                accessibilitySection
            }
            .formStyle(.grouped)
            .padding(20)
        }
        .frame(width: 540, height: 620)
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

    private var translationModeDescription: String {
        switch settings.translationMode {
        case .byok:
            return "使用你自己的 DashScope API Key，翻译请求直连阿里云，不经由商业服务器。"
        case .cloud:
            return "登录云端账号后，由 EasyTrans Pro 服务端代理翻译并管理套餐与配额。"
        }
    }

    @ViewBuilder
    private var byokSection: some View {
        Section("DashScope 配置") {
            SecureField("API Key", text: $settings.apiKey)
                .textFieldStyle(.roundedBorder)

            Picker("模型", selection: $settings.model) {
                ForEach(modelOptions, id: \.self) { model in
                    Text(model).tag(model)
                }
            }

            TextField("API Base URL", text: $settings.baseURL)
                .textFieldStyle(.roundedBorder)

            Link("获取 API Key", destination: URL(string: "https://dashscope.console.aliyun.com/apiKey")!)
            Text("API Key 保存在本机，不会上传到商业服务器。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var cloudSection: some View {
        Section("云端服务") {
            TextField("API 地址", text: $settings.cloudBaseURL)
                .textFieldStyle(.roundedBorder)

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
                    Button("登录") {
                        Task { await login() }
                    }
                    .disabled(isAuthBusy)

                    Button("注册") {
                        Task { await register() }
                    }
                    .disabled(isAuthBusy)
                }

                Divider()

                TextField("License Key", text: $licenseKey)
                    .textFieldStyle(.roundedBorder)

                Button("激活 License") {
                    Task { await activateLicense() }
                }
                .disabled(isAuthBusy || licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

            Text("在其他应用中选中文字并翻译，需要辅助功能权限。EasyTrans Pro 窗口内选中文字翻译不需要此权限。")
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
                Text("授权后请完全退出 EasyTrans Pro（⌘Q）再重新打开，系统才会生效。若列表里已有 EasyTrans Pro 但仍显示未授权，请删除旧条目，用「在 Finder 中显示应用」拖入新的 EasyTrans Pro.app。")
                    .font(.caption)
                    .foregroundStyle(Color.orange)

                Text("添加权限时找不到 Library 文件夹？macOS 默认隐藏它。请用下方「在 Finder 中显示应用」，把弹出的 EasyTrans Pro 直接拖进辅助功能列表。")
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
        await performAuth {
            try await cloudAuth.register(email: loginEmail, password: loginPassword, settings: settings)
        }
    }

    private func activateLicense() async {
        await performAuth {
            try await cloudAuth.activateLicense(licenseKey, settings: settings)
        }
    }

    private func refreshProfile() async {
        await performAuth {
            try await cloudAuth.refreshProfile(settings: settings)
        }
    }

    private func performAuth(_ action: () async throws -> Void) async {
        isAuthBusy = true
        authMessage = nil
        defer { isAuthBusy = false }

        do {
            try await action()
            authIsError = false
            authMessage = "操作成功"
            loginPassword = ""
        } catch {
            authIsError = true
            authMessage = error.localizedDescription
        }
    }
}

import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var cloudAuth = CloudAuthService.shared
    @ObservedObject private var shortcutSettings = KeyboardShortcutSettings.shared
    @State private var accessibilityTrusted = AccessibilityHelper.isTrusted
    @State private var authMessage: String?
    @State private var isAuthBusy = false
    @State private var billingConfig: BillingConfigResponse?
    @State private var billingMessage: String?
    @State private var isBillingBusy = false

    var body: some View {
        ScrollView {
            Form {
                accountSection

                Section("通用") {
                    Toggle("登录时自动启动", isOn: $settings.launchAtLogin)
                }

                shortcutSection
                accessibilitySection
            }
            .formStyle(.grouped)
            .padding(20)
        }
        .frame(width: 540, height: 560)
        .onAppear {
            refreshAccessibilityStatus()
            settings.refreshLaunchAtLoginStatus()
            Task { await loadBillingConfig() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshAccessibilityStatus()
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        Section {
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
                    if let planExpirySummary = account.planExpirySummary {
                        LabeledContent("有效期") {
                            Text(planExpirySummary)
                                .foregroundStyle(account.paidPlanActive == true ? Color.primary : Color.orange)
                        }
                    }
                }

                if billingConfig?.isPaidMode == true, let products = billingConfig?.products, !products.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(account.requiresPurchase == true ? "购买基础版" : "续费基础版")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ForEach(products) { product in
                            Button(account.requiresPurchase == true ? "购买 \(product.displayLabel)" : "续费 \(product.displayLabel)") {
                                Task { await openCheckout(variantId: product.variantId) }
                            }
                            .disabled(isBillingBusy)
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
                AuthPanelView()
            }

            if let authMessage {
                Text(authMessage)
                    .font(.caption)
                    .foregroundStyle(Color.orange)
            }
            if let billingMessage {
                Text(billingMessage)
                    .font(.caption)
                    .foregroundStyle(Color.orange)
            }
        }
    }

    @ViewBuilder
    private var shortcutSection: some View {
        Section("快捷键") {
            LabeledContent("翻译选中文字") {
                ShortcutRecorderView(
                    shortcut: $shortcutSettings.translateShortcut,
                    defaultShortcut: .translateDefault
                ) { candidate in
                    candidate.validationError(conflictingWith: shortcutSettings.clipboardHistoryShortcut)
                }
            }

            LabeledContent("剪贴板历史") {
                ShortcutRecorderView(
                    shortcut: $shortcutSettings.clipboardHistoryShortcut,
                    defaultShortcut: .clipboardHistoryDefault
                ) { candidate in
                    candidate.validationError(conflictingWith: shortcutSettings.translateShortcut)
                }
            }
        }
    }

    @ViewBuilder
    private var accessibilitySection: some View {
        Section("快捷翻译") {
            LabeledContent("辅助功能权限") {
                HStack(spacing: 6) {
                    Circle()
                        .fill(accessibilityTrusted ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(accessibilityTrusted ? "已授权" : "未授权")
                        .foregroundStyle(accessibilityTrusted ? Color.primary : Color.orange)
                }
            }

            if !accessibilityTrusted {
                HStack {
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

            #if DEBUG
            if AccessibilityHelper.isStableProjectBuild {
                Text("Debug：当前从项目 build/Debug 运行。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if AccessibilityHelper.isRunningFromDerivedData {
                Text("Debug：当前从 DerivedData 运行，授权可能不稳定。")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            Button("在 Finder 中显示应用") {
                AccessibilityHelper.revealInFinder()
            }
            #endif
        }
    }

    private func refreshAccessibilityStatus() {
        accessibilityTrusted = AccessibilityHelper.isTrusted
        QuickTranslateService.shared.refreshListeners()
    }

    private func refreshProfile() async {
        isAuthBusy = true
        authMessage = nil
        defer { isAuthBusy = false }

        do {
            try await cloudAuth.refreshProfile(settings: settings)
            await loadBillingConfig()
        } catch {
            authMessage = error.localizedDescription
        }
    }

    private func loadBillingConfig() async {
        let client = CloudAPIClient(baseURL: settings.cloudBaseURL)
        do {
            billingConfig = try await client.fetchBillingConfig()
        } catch {
            billingConfig = BillingConfigResponse(enabled: false, mode: nil, products: nil)
        }
    }

    private func openCheckout(variantId: String) async {
        isBillingBusy = true
        billingMessage = nil
        defer { isBillingBusy = false }

        let client = CloudAPIClient(baseURL: settings.cloudBaseURL)
        do {
            let checkout = try await client.fetchCheckoutURL(variantId: variantId)
            let checkoutUrl = checkout.checkoutUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !checkoutUrl.isEmpty else {
                billingMessage = "无效的付款链接"
                return
            }
            guard openExternalURL(checkoutUrl) else {
                billingMessage = "无法打开付款链接"
                return
            }
            billingMessage = "已在浏览器打开付款页面，完成后请点击「刷新账号信息」。"
        } catch {
            billingMessage = error.localizedDescription
        }
    }

    /// Opens a fully-formed HTTP(S) URL without re-encoding query parameters.
    /// `URL(string:)` would turn `%40` into `%2540` and break Lemon Squeezy checkout links.
    private func openExternalURL(_ urlString: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [urlString]
        do {
            try process.run()
            return true
        } catch {
            return false
        }
    }
}

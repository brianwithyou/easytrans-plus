import SwiftUI

struct AuthPanelView: View {
    enum Screen {
        case gateway
        case login
        case register
    }

    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var cloudAuth = CloudAuthService.shared

    let initialScreen: Screen
    var onAuthenticated: (() -> Void)?

    @State private var authScreen: Screen
    @State private var loginEmail = ""
    @State private var loginPassword = ""
    @State private var registerCode = ""
    @State private var sendCodeCountdown = 0
    @State private var authMessage: String?
    @State private var isAuthBusy = false

    init(initialScreen: Screen = .gateway, onAuthenticated: (() -> Void)? = nil) {
        self.initialScreen = initialScreen
        self.onAuthenticated = onAuthenticated
        _authScreen = State(initialValue: initialScreen)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch authScreen {
            case .gateway:
                HStack(spacing: 12) {
                    Button("登录") {
                        authMessage = nil
                        authScreen = .login
                    }
                    .keyboardShortcut(.defaultAction)

                    Button("注册") {
                        authMessage = nil
                        authScreen = .register
                    }
                }

            case .login:
                TextField("邮箱", text: $loginEmail)
                    .textFieldStyle(.roundedBorder)

                SecureField("密码", text: $loginPassword)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("登录") {
                        Task { await login() }
                    }
                    .disabled(isAuthBusy)
                    .keyboardShortcut(.defaultAction)

                    if initialScreen == .gateway {
                        Button("返回") {
                            authMessage = nil
                            authScreen = .gateway
                        }
                        .disabled(isAuthBusy)
                    }
                }

            case .register:
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

                HStack {
                    Button("注册") {
                        Task { await register() }
                    }
                    .disabled(isAuthBusy)
                    .keyboardShortcut(.defaultAction)

                    if initialScreen == .gateway {
                        Button("返回") {
                            authMessage = nil
                            authScreen = .gateway
                        }
                        .disabled(isAuthBusy)
                    }
                }
            }

            if let authMessage {
                Text(authMessage)
                    .font(.caption)
                    .foregroundStyle(Color.orange)
            }
        }
        .onAppear {
            if loginEmail.isEmpty {
                loginEmail = KeychainStore.load(account: .accountEmail) ?? ""
            }
        }
    }

    private var sendCodeButtonTitle: String {
        sendCodeCountdown > 0 ? "\(sendCodeCountdown)s" : "获取验证码"
    }

    private func login() async {
        await performAuth(clearsPassword: true) {
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
            registerCode = ""
            startSendCodeCountdown()
        } catch {
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

    private func performAuth(clearsPassword: Bool = false, _ action: () async throws -> Void) async {
        isAuthBusy = true
        authMessage = nil
        defer { isAuthBusy = false }

        do {
            try await action()
            if clearsPassword {
                loginPassword = ""
                registerCode = ""
            }
            onAuthenticated?()
        } catch {
            authMessage = error.localizedDescription
        }
    }
}

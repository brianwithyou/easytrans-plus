import Foundation

struct CloudAPIClient: Sendable {
    let baseURL: String

    private var normalizedBaseURL: String {
        baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    func sendRegisterCode(email: String) async throws {
        let _: SendCodeResponse = try await postJSON(
            path: "/api/v1/auth/email/send-code",
            body: ["email": email, "scene": "register"],
            authorized: false
        )
    }

    func register(email: String, password: String, code: String) async throws -> AuthResponse {
        try await postJSON(
            path: "/api/v1/auth/register",
            body: ["email": email, "password": password, "code": code],
            authorized: false
        )
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        try await postJSON(
            path: "/api/v1/auth/login",
            body: ["email": email, "password": password],
            authorized: false
        )
    }

    func activateLicense(_ licenseKey: String) async throws -> AuthResponse {
        try await postJSON(
            path: "/api/v1/license/activate",
            body: ["licenseKey": licenseKey],
            authorized: true
        )
    }

    func refreshToken(_ refreshToken: String) async throws -> AuthResponse {
        try await postJSON(
            path: "/api/v1/auth/refresh",
            body: ["refreshToken": refreshToken],
            authorized: false
        )
    }

    func fetchProfile() async throws -> MeResponse {
        try await getJSON(path: "/api/v1/me", authorized: true)
    }

    func fetchBillingConfig() async throws -> BillingConfigResponse {
        try await getJSON(path: "/api/v1/billing/config", authorized: false)
    }

    func fetchCheckoutURL(variantId: String) async throws -> BillingCheckoutResponse {
        let encoded = variantId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? variantId
        return try await getJSON(path: "/api/v1/billing/checkout?variantId=\(encoded)", authorized: true)
    }

    func streamTranslate(
        request: TranslationRequest,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        let trimmed = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        guard let accessToken = KeychainStore.load(account: .accessToken),
              !accessToken.isEmpty else {
            throw TranslationError.notAuthenticated
        }

        return try await streamTranslate(
            request: request,
            accessToken: accessToken,
            onDelta: onDelta,
            allowRetry: true
        )
    }

    private func streamTranslate(
        request: TranslationRequest,
        accessToken: String,
        onDelta: @escaping @Sendable (String) -> Void,
        allowRetry: Bool
    ) async throws -> String {
        guard let url = URL(string: normalizedBaseURL + "/api/v1/translate/stream") else {
            throw TranslationError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 120
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "text": request.text.trimmingCharacters(in: .whitespacesAndNewlines),
            "sourceLanguage": request.sourceLanguage.rawValue,
            "targetLanguage": request.targetLanguage.rawValue,
            "style": request.style.apiValue,
            "clientRequestId": request.clientRequestId
        ]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response): (URLSession.AsyncBytes, URLResponse)
        do {
            (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
        } catch {
            throw TranslationError.network(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.emptyResponse
        }

        if httpResponse.statusCode == 401, allowRetry {
            let refreshed = try await CloudAuthService.shared.refreshSession(using: self)
            guard refreshed else { throw TranslationError.notAuthenticated }
            guard let newToken = KeychainStore.load(account: .accessToken) else {
                throw TranslationError.notAuthenticated
            }
            return try await streamTranslate(
                request: request,
                accessToken: newToken,
                onDelta: onDelta,
                allowRetry: false
            )
        }

        if httpResponse.statusCode == 402 {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let message = Self.extractErrorMessage(from: errorData) ?? "请先购买套餐后使用云端翻译"
            throw TranslationError.httpError(status: 402, message: message)
        }

        if httpResponse.statusCode == 429 {
            throw TranslationError.quotaExceeded
        }

        if httpResponse.statusCode >= 400 {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let message = String(data: errorData, encoding: .utf8) ?? "未知错误"
            throw TranslationError.httpError(status: httpResponse.statusCode, message: message)
        }

        return try await SSEStreamParser.consume(lines: bytes.lines, onDelta: onDelta)
    }

    private func postJSON<Response: Decodable>(
        path: String,
        body: [String: Any],
        authorized: Bool
    ) async throws -> Response {
        try await sendJSON(method: "POST", path: path, body: body, authorized: authorized)
    }

    private func getJSON<Response: Decodable>(
        path: String,
        authorized: Bool
    ) async throws -> Response {
        try await sendJSON(method: "GET", path: path, body: nil, authorized: authorized)
    }

    private func sendJSON<Response: Decodable>(
        method: String,
        path: String,
        body: [String: Any]?,
        authorized: Bool
    ) async throws -> Response {
        guard let url = URL(string: normalizedBaseURL + path) else {
            throw TranslationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authorized {
            guard let token = KeychainStore.load(account: .accessToken), !token.isEmpty else {
                throw TranslationError.notAuthenticated
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw TranslationError.network(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.emptyResponse
        }

        if httpResponse.statusCode >= 400 {
            let message = Self.extractErrorMessage(from: data) ?? String(data: data, encoding: .utf8) ?? "未知错误"
            throw TranslationError.httpError(status: httpResponse.statusCode, message: message)
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw TranslationError.httpError(status: httpResponse.statusCode, message: "响应解析失败")
        }
    }

    private static func extractErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let message = json["message"] as? String, !message.isEmpty {
            return message
        }
        return nil
    }
}

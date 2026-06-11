import Foundation

struct DashScopeClient {
    let apiKey: String
    let baseURL: String
    let model: String

    func streamChat(
        messages: [[String: String]],
        temperature: Double = 0.3,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw TranslationError.notConfigured(.byok)
        }

        let endpoint = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: endpoint + "/chat/completions") else {
            throw TranslationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": temperature,
            "stream": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.emptyResponse
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
}

import Foundation

protocol TranslationProvider: Sendable {
    func translate(
        request: TranslationRequest,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> String
}

struct DirectDashScopeProvider: TranslationProvider {
    let apiKey: String
    let baseURL: String
    let model: String

    func translate(
        request: TranslationRequest,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        let trimmed = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let client = DashScopeClient(apiKey: apiKey, baseURL: baseURL, model: model)
        let systemPrompt = TranslationPromptBuilder.systemPrompt(
            source: request.sourceLanguage,
            target: request.targetLanguage,
            style: request.style
        )
        let userPrompt = TranslationPromptBuilder.userPrompt(text: trimmed)

        return try await client.streamChat(
            messages: [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            onDelta: onDelta
        )
    }
}

struct CloudTranslationProvider: TranslationProvider {
    let client: CloudAPIClient

    func translate(
        request: TranslationRequest,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        try await client.streamTranslate(request: request, onDelta: onDelta)
    }
}

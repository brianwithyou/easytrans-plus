import Foundation

enum TranslationStyle: Sendable {
    case standard
    /// 英文单词/短语输入：输出原文 IPA 与中文译文
    case withPhonetics
    /// 中文输入译英：多义项时每行「英文 词性 /IPA/」
    case withEnglishResultPhonetics
}

enum TranslationFormatting {
    /// 复制到剪贴板时去掉 Markdown 加粗标记。
    static func plainTextForCopy(_ text: String) -> String {
        text.replacingOccurrences(of: "**", with: "")
    }
}

struct TranslationService {
    @MainActor
    func translate(
        text: String,
        sourceLanguage: Language,
        targetLanguage: Language,
        style: TranslationStyle = .standard,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        let settings = AppSettings.shared
        guard settings.isConfigured else {
            throw TranslationError.notConfigured(settings.translationMode)
        }

        let request = TranslationRequest(
            text: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            style: style
        )
        let provider = settings.makeTranslationProvider()
        return try await provider.translate(request: request, onDelta: onDelta)
    }
}

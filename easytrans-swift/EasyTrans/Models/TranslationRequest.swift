import Foundation

struct TranslationRequest: Sendable {
    let text: String
    let sourceLanguage: Language
    let targetLanguage: Language
    let style: TranslationStyle
    let clientRequestId: String

    init(
        text: String,
        sourceLanguage: Language,
        targetLanguage: Language,
        style: TranslationStyle,
        clientRequestId: String = UUID().uuidString
    ) {
        self.text = text
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.style = style
        self.clientRequestId = clientRequestId
    }
}

extension TranslationStyle {
    var apiValue: String {
        switch self {
        case .standard: return "standard"
        case .withPhonetics: return "withPhonetics"
        case .withEnglishResultPhonetics: return "withEnglishResultPhonetics"
        }
    }
}

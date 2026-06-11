import Foundation
import NaturalLanguage

enum TextScope: Sendable {
    case wordOrPhrase
    case sentenceOrParagraph
}

enum TextClassifier {
    private static let sentenceEnders: Set<Character> = [".", "!", "?", "。", "！", "？", "…", "；", ";"]

    static func classify(_ text: String) -> TextScope {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .sentenceOrParagraph }

        if trimmed.contains(where: \.isNewline) {
            return .sentenceOrParagraph
        }

        if let last = trimmed.last, sentenceEnders.contains(last) {
            return .sentenceOrParagraph
        }

        let words = trimmed.split { $0.isWhitespace || $0.isPunctuation }.filter { !$0.isEmpty }
        if words.count > 5 {
            return .sentenceOrParagraph
        }

        let cjkCount = trimmed.filter(isCJK).count
        if cjkCount > 12 || trimmed.count > 36 {
            return .sentenceOrParagraph
        }

        return .wordOrPhrase
    }

    /// 自动检测输入语言，与所选目标语言及英语互译：目标语 → 英语，英语 → 目标语，其他语言 → 目标语。
    static func resolveTranslationLanguages(
        text: String,
        preferredTarget: Language
    ) -> (source: Language, target: Language) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if isLanguage(trimmed, preferredTarget) {
            return (preferredTarget, .english)
        }
        if isEnglish(trimmed) {
            return (.english, preferredTarget)
        }
        return (.auto, preferredTarget)
    }

    /// 英文单词/短语 → 目标语：加粗原文+音标一行，词性+译文一行；目标语 → 英文：多义项时每行「英文 词性 /音标/」。
    static func resolveTranslationStyle(
        text: String,
        source: Language,
        target: Language,
        preferredTarget: Language
    ) -> TranslationStyle {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let scope = classify(trimmed)

        if scope == .wordOrPhrase, target == preferredTarget, isEnglish(trimmed) {
            return .withPhonetics
        }

        if target == .english, isLanguage(trimmed, preferredTarget), scope == .wordOrPhrase {
            return .withEnglishResultPhonetics
        }

        return .standard
    }

    static func isLanguage(_ text: String, _ language: Language) -> Bool {
        switch language {
        case .auto, .english:
            return false
        case .chinese:
            return isChinese(text)
        default:
            guard let expected = language.nlLanguage else { return false }
            if dominantLanguage(of: text) == expected {
                return true
            }
            return primarilyMatchesLanguage(text, language)
        }
    }

    static func isEnglish(_ text: String) -> Bool {
        dominantLanguage(of: text) == .english
    }

    static func isChinese(_ text: String) -> Bool {
        guard let language = dominantLanguage(of: text) else {
            return primarilyChinese(text)
        }
        return language == .simplifiedChinese || language == .traditionalChinese
    }

    private static func dominantLanguage(of text: String) -> NLLanguage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        return recognizer.dominantLanguage
    }

    private static func primarilyChinese(_ text: String) -> Bool {
        primarilyMatchesLanguage(text, .chinese)
    }

    private static func primarilyMatchesLanguage(_ text: String, _ language: Language) -> Bool {
        var scriptCount = 0
        var latin = 0
        for character in text {
            if matchesScript(character, language) {
                scriptCount += 1
            } else if character.isLetter, character.isASCII {
                latin += 1
            }
        }
        return scriptCount > latin && scriptCount > 0
    }

    private static func matchesScript(_ character: Character, _ language: Language) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        let value = scalar.value
        switch language {
        case .chinese:
            return (0x4E00...0x9FFF).contains(value)
                || (0x3400...0x4DBF).contains(value)
        case .japanese:
            return (0x3040...0x30FF).contains(value)
        case .korean:
            return (0xAC00...0xD7AF).contains(value)
        case .arabic:
            return (0x0600...0x06FF).contains(value)
                || (0x0750...0x077F).contains(value)
        default:
            return false
        }
    }

    private static func isCJK(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        let value = scalar.value
        return (0x4E00...0x9FFF).contains(value)
            || (0x3400...0x4DBF).contains(value)
            || (0x3040...0x30FF).contains(value)
            || (0xAC00...0xD7AF).contains(value)
    }
}

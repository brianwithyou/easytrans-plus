import Foundation

enum TranslationPromptBuilder {
    static func systemPrompt(source: Language, target: Language, style: TranslationStyle) -> String {
        let outputInstruction: String
        switch style {
        case .standard:
            outputInstruction = "只输出翻译结果，不要解释，不要添加引号或额外说明。"
        case .withPhonetics:
            outputInstruction = """
            输入是英语单词或短语。必须严格按以下两行格式输出，不要添加任何其他内容：
            **[原文英文单词或短语]** /[IPA 国际音标]/
            [词性缩写] [\(target.promptName)译文]

            第一行：原文英文用 Markdown 加粗（**包围），后接空格与斜杠包裹的 IPA；不要写「音标」二字。
            第二行：词性英文缩写（如 n. v. adj. adv. prep. conj. interj. 等），空一格后写译文。
            示例：
            **apple** /ˈæp.əl/
            n. 苹果
            """
        case .withEnglishResultPhonetics:
            outputInstruction = """
            输入是\(source.promptName)单词或短语。请翻译成英语；若有多个常见译法，请全部列出。
            每个英语单词或短语一行，格式：[英文译法] [词性缩写] /[IPA 国际音标]/
            词性使用英文缩写（如 n. v. adj. adv. prep. conj. interj. 等），写在音标斜杠之前。
            若某个译法是完整句子而非单词或短语，则该条只输出句子译文，不要音标和词性。
            不要添加编号、解释或其他多余内容；多条译法之间换行分隔。
            示例：
            bank n. /bæŋk/
            shore n. /ʃɔːr/
            """
        }

        if source == .auto {
            if style != .standard {
                return """
                你是一位专业翻译。请自动识别输入文本的语言，翻译为\(target.promptName)。
                \(outputInstruction)
                """
            }
            return """
            你是一位专业翻译。请自动识别输入文本的语言，并将其翻译成\(target.promptName)。
            \(outputInstruction)
            如果原文已经是\(target.promptName)，请润色并返回更自然的表达。
            """
        }

        if style != .standard {
            return """
            你是一位专业翻译。请将\(source.promptName)翻译成\(target.promptName)。
            \(outputInstruction)
            """
        }

        return """
        你是一位专业翻译。请将\(source.promptName)翻译成\(target.promptName)。
        \(outputInstruction)
        保持原文的语气、风格和格式（如换行、列表）。
        """
    }

    static func userPrompt(text: String) -> String {
        "请翻译以下文本：\n\n\(text)"
    }
}

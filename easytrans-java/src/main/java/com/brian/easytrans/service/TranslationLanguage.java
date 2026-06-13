package com.brian.easytrans.service;

public enum TranslationLanguage {
    auto("auto", "目标语言"),
    zh("zh", "中文"),
    en("en", "英语"),
    ja("ja", "日语"),
    ko("ko", "韩语"),
    fr("fr", "法语"),
    de("de", "德语"),
    es("es", "西班牙语"),
    ru("ru", "俄语"),
    ar("ar", "阿拉伯语"),
    vi("vi", "越南语");

    private final String code;
    private final String promptName;

    TranslationLanguage(String code, String promptName) {
        this.code = code;
        this.promptName = promptName;
    }

    public String getCode() {
        return code;
    }

    public String getPromptName() {
        return promptName;
    }

    public static TranslationLanguage fromCode(String code) {
        if (code == null || code.isBlank()) {
            return auto;
        }
        for (TranslationLanguage language : values()) {
            if (language.code.equalsIgnoreCase(code)) {
                return language;
            }
        }
        return auto;
    }
}

package com.brian.easytrans.service;

public enum TranslationStyle {
    standard,
    withPhonetics,
    withEnglishResultPhonetics;

    public static TranslationStyle fromApiValue(String value) {
        if (value == null || value.isBlank()) {
            return standard;
        }
        try {
            return TranslationStyle.valueOf(value);
        } catch (IllegalArgumentException ex) {
            return standard;
        }
    }
}

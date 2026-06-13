package com.brian.easytrans.service;

public enum TranslationEventStatus {
    SUCCESS("success"),
    FAILED("failed"),
    QUOTA_EXCEEDED("quota_exceeded");

    private final String value;

    TranslationEventStatus(String value) {
        this.value = value;
    }

    public String getValue() {
        return value;
    }
}

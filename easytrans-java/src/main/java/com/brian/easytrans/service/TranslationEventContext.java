package com.brian.easytrans.service;

public final class TranslationEventContext {

    private final String userId;
    private final String requestId;
    private final String clientRequestId;
    private final String sourceLang;
    private final String targetLang;
    private final String style;
    private final int inputChars;
    private final long startTimeMs;

    public TranslationEventContext(
            String userId,
            String requestId,
            String clientRequestId,
            String sourceLang,
            String targetLang,
            String style,
            int inputChars,
            long startTimeMs) {
        this.userId = userId;
        this.requestId = requestId;
        this.clientRequestId = clientRequestId;
        this.sourceLang = sourceLang;
        this.targetLang = targetLang;
        this.style = style;
        this.inputChars = inputChars;
        this.startTimeMs = startTimeMs;
    }

    public String getUserId() {
        return userId;
    }

    public String getRequestId() {
        return requestId;
    }

    public String getClientRequestId() {
        return clientRequestId;
    }

    public String getSourceLang() {
        return sourceLang;
    }

    public String getTargetLang() {
        return targetLang;
    }

    public String getStyle() {
        return style;
    }

    public int getInputChars() {
        return inputChars;
    }

    public long durationMs() {
        return Math.max(0L, System.currentTimeMillis() - startTimeMs);
    }
}

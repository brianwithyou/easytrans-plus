package com.brian.easytrans.integration.llm;

public enum LlmProvider {
    DASHSCOPE("dashscope", "https://dashscope.aliyuncs.com/compatible-mode/v1", "qwen-plus"),
    MIMO("mimo", "https://api.xiaomimimo.com/v1", "mimo-v2-flash"),
    DEEPSEEK("deepseek", "https://api.deepseek.com", "deepseek-v4-flash");

    private final String configValue;
    private final String defaultBaseUrl;
    private final String defaultModel;

    LlmProvider(String configValue, String defaultBaseUrl, String defaultModel) {
        this.configValue = configValue;
        this.defaultBaseUrl = defaultBaseUrl;
        this.defaultModel = defaultModel;
    }

    public String getConfigValue() {
        return configValue;
    }

    public String getDefaultBaseUrl() {
        return defaultBaseUrl;
    }

    public String getDefaultModel() {
        return defaultModel;
    }

    public static LlmProvider fromConfig(String value) {
        if (value == null || value.isBlank()) {
            return DASHSCOPE;
        }
        String normalized = value.trim().toLowerCase();
        for (LlmProvider provider : values()) {
            if (provider.configValue.equals(normalized) || provider.name().equalsIgnoreCase(normalized)) {
                return provider;
            }
        }
        throw new IllegalArgumentException("不支持的 LLM 提供商: " + value + "，可选: dashscope, mimo, deepseek");
    }
}

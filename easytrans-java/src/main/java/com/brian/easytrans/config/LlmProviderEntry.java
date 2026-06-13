package com.brian.easytrans.config;

import com.brian.easytrans.integration.llm.LlmProvider;
import org.springframework.util.StringUtils;

public class LlmProviderEntry {

    private String provider = LlmProvider.DASHSCOPE.getConfigValue();
    private String apiKey;
    private String baseUrl;
    private String model;
    private boolean enabled = true;

    public LlmProvider resolveProvider() {
        return LlmProvider.fromConfig(provider);
    }

    public String getProvider() {
        return provider;
    }

    public void setProvider(String provider) {
        this.provider = provider;
    }

    public String getApiKey() {
        return apiKey;
    }

    public void setApiKey(String apiKey) {
        this.apiKey = apiKey;
    }

    public String getBaseUrl() {
        return baseUrl;
    }

    public void setBaseUrl(String baseUrl) {
        this.baseUrl = baseUrl;
    }

    public String getModel() {
        return model;
    }

    public void setModel(String model) {
        this.model = model;
    }

    public boolean isEnabled() {
        return enabled;
    }

    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    public boolean isConfigured() {
        return enabled && StringUtils.hasText(apiKey);
    }

    public String resolveBaseUrl() {
        return StringUtils.hasText(baseUrl) ? baseUrl : resolveProvider().getDefaultBaseUrl();
    }

    public String resolveModel() {
        return StringUtils.hasText(model) ? model : resolveProvider().getDefaultModel();
    }
}

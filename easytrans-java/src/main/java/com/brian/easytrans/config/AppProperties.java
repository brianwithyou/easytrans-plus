package com.brian.easytrans.config;

import com.brian.easytrans.integration.llm.LlmProvider;
import java.util.ArrayList;
import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.util.StringUtils;

@ConfigurationProperties(prefix = "app")
public class AppProperties {

    private final Jwt jwt = new Jwt();
    private final Cors cors = new Cors();
    private final Llm llm = new Llm();
    private final Email email = new Email();

    public Jwt getJwt() {
        return jwt;
    }

    public Cors getCors() {
        return cors;
    }

    public Llm getLlm() {
        return llm;
    }

    public Email getEmail() {
        return email;
    }

    public static class Jwt {
        private String secret;
        private int expireHours = 24;
        private int refreshExpireHours = 720;

        public String getSecret() {
            return secret;
        }

        public void setSecret(String secret) {
            this.secret = secret;
        }

        public int getExpireHours() {
            return expireHours;
        }

        public void setExpireHours(int expireHours) {
            this.expireHours = expireHours;
        }

        public int getRefreshExpireHours() {
            return refreshExpireHours;
        }

        public void setRefreshExpireHours(int refreshExpireHours) {
            this.refreshExpireHours = refreshExpireHours;
        }
    }

    public static class Cors {
        private String allowedOrigins = "*";

        public String getAllowedOrigins() {
            return allowedOrigins;
        }

        public void setAllowedOrigins(String allowedOrigins) {
            this.allowedOrigins = allowedOrigins;
        }
    }

    public static class Llm {
        private List<LlmProviderEntry> providers = new ArrayList<>();
        private String provider = LlmProvider.DASHSCOPE.getConfigValue();
        private String apiKey;
        private String baseUrl;
        private String model;

        public List<LlmProviderEntry> getProviders() {
            return providers;
        }

        public void setProviders(List<LlmProviderEntry> providers) {
            this.providers = providers == null ? new ArrayList<>() : providers;
        }

        public LlmProvider getProvider() {
            return LlmProvider.fromConfig(provider);
        }

        public String getProviderConfig() {
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

        public List<LlmProviderEntry> resolveConfiguredProviders() {
            if (!providers.isEmpty()) {
                return providers.stream().filter(LlmProviderEntry::isConfigured).toList();
            }
            if (StringUtils.hasText(apiKey)) {
                LlmProviderEntry legacy = new LlmProviderEntry();
                legacy.setProvider(provider);
                legacy.setApiKey(apiKey);
                legacy.setBaseUrl(baseUrl);
                legacy.setModel(model);
                return List.of(legacy);
            }
            return List.of();
        }
    }

    public static class Email {
        private boolean devMode = true;
        private String devCode = "123456";
        private int expireMinutes = 10;
        private int resendIntervalSeconds = 60;
        private int dailyLimit = 10;
        private final Resend resend = new Resend();

        public boolean isDevMode() {
            return devMode;
        }

        public void setDevMode(boolean devMode) {
            this.devMode = devMode;
        }

        public String getDevCode() {
            return devCode;
        }

        public void setDevCode(String devCode) {
            this.devCode = devCode;
        }

        public int getExpireMinutes() {
            return expireMinutes;
        }

        public void setExpireMinutes(int expireMinutes) {
            this.expireMinutes = expireMinutes;
        }

        public int getResendIntervalSeconds() {
            return resendIntervalSeconds;
        }

        public void setResendIntervalSeconds(int resendIntervalSeconds) {
            this.resendIntervalSeconds = resendIntervalSeconds;
        }

        public int getDailyLimit() {
            return dailyLimit;
        }

        public void setDailyLimit(int dailyLimit) {
            this.dailyLimit = dailyLimit;
        }

        public Resend getResend() {
            return resend;
        }
    }

    public static class Resend {
        private String apiKey;
        private String from = "EasyTrans <onboarding@resend.dev>";

        public String getApiKey() {
            return apiKey;
        }

        public void setApiKey(String apiKey) {
            this.apiKey = apiKey;
        }

        public String getFrom() {
            return from;
        }

        public void setFrom(String from) {
            this.from = from;
        }
    }
}

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

    public Jwt getJwt() {
        return jwt;
    }

    public Cors getCors() {
        return cors;
    }

    public Llm getLlm() {
        return llm;
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
}

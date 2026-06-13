package com.brian.easytrans.config;

import com.brian.easytrans.integration.llm.LlmProvider;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.util.StringUtils;

@ConfigurationProperties(prefix = "app")
public class AppProperties {

    private final Jwt jwt = new Jwt();
    private final Cors cors = new Cors();
    private final Llm llm = new Llm();
    private final Email email = new Email();
    private final Billing billing = new Billing();

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

    public Billing getBilling() {
        return billing;
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

    public static class Billing {
        private boolean enabled = false;
        private String runtimeConfigPath;
        private final FreePlan freePlan = new FreePlan();
        private final UnpaidPlan unpaidPlan = new UnpaidPlan();
        private final LemonSqueezy lemonSqueezy = new LemonSqueezy();
        private List<BillingProduct> products = new ArrayList<>();

        public boolean isEnabled() {
            return enabled;
        }

        public void setEnabled(boolean enabled) {
            this.enabled = enabled;
        }

        public String getRuntimeConfigPath() {
            return runtimeConfigPath;
        }

        public void setRuntimeConfigPath(String runtimeConfigPath) {
            this.runtimeConfigPath = runtimeConfigPath;
        }

        public FreePlan getFreePlan() {
            return freePlan;
        }

        public UnpaidPlan getUnpaidPlan() {
            return unpaidPlan;
        }

        public LemonSqueezy getLemonSqueezy() {
            return lemonSqueezy;
        }

        public List<BillingProduct> getProducts() {
            return products;
        }

        public void setProducts(List<BillingProduct> products) {
            this.products = products == null ? new ArrayList<>() : products;
        }

        public Optional<BillingProduct> findProductByVariantId(String variantId) {
            if (!StringUtils.hasText(variantId)) {
                return Optional.empty();
            }
            return products.stream()
                    .filter(product -> variantId.equals(product.getVariantId()))
                    .findFirst();
        }
    }

    public static class FreePlan {
        private String name = "基础版";
        private int dailyQuota = 50000;

        public String getName() {
            return name;
        }

        public void setName(String name) {
            this.name = name;
        }

        public int getDailyQuota() {
            return dailyQuota;
        }

        public void setDailyQuota(int dailyQuota) {
            this.dailyQuota = dailyQuota;
        }
    }

    public static class UnpaidPlan {
        private String name = "未开通";

        public String getName() {
            return name;
        }

        public void setName(String name) {
            this.name = name;
        }
    }

    public static class LemonSqueezy {
        private String webhookSecret;
        private boolean allowTestMode = true;

        public String getWebhookSecret() {
            return webhookSecret;
        }

        public void setWebhookSecret(String webhookSecret) {
            this.webhookSecret = webhookSecret;
        }

        public boolean isAllowTestMode() {
            return allowTestMode;
        }

        public void setAllowTestMode(boolean allowTestMode) {
            this.allowTestMode = allowTestMode;
        }
    }

    public static class BillingProduct {
        private String variantId;
        private String planName;
        private int dailyQuota;
        private int durationDays = 30;
        private String label;
        private String checkoutUrl;

        public String getVariantId() {
            return variantId;
        }

        public void setVariantId(String variantId) {
            this.variantId = variantId;
        }

        public String getPlanName() {
            return planName;
        }

        public void setPlanName(String planName) {
            this.planName = planName;
        }

        public int getDailyQuota() {
            return dailyQuota;
        }

        public void setDailyQuota(int dailyQuota) {
            this.dailyQuota = dailyQuota;
        }

        public int getDurationDays() {
            return durationDays;
        }

        public void setDurationDays(int durationDays) {
            this.durationDays = durationDays;
        }

        public String getLabel() {
            return label;
        }

        public void setLabel(String label) {
            this.label = label;
        }

        public String getCheckoutUrl() {
            return checkoutUrl;
        }

        public void setCheckoutUrl(String checkoutUrl) {
            this.checkoutUrl = checkoutUrl;
        }
    }
}

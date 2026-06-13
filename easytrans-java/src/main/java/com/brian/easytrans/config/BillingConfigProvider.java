package com.brian.easytrans.config;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

@Component
public class BillingConfigProvider {

    private static final Logger log = LoggerFactory.getLogger(BillingConfigProvider.class);

    private final AppProperties appProperties;
    private final String runtimeConfigPath;

    private volatile AppProperties.Billing cachedBilling;
    private volatile long cachedMtime = Long.MIN_VALUE;

    public BillingConfigProvider(AppProperties appProperties) {
        this.appProperties = appProperties;
        this.runtimeConfigPath = appProperties.getBilling().getRuntimeConfigPath();
    }

    public AppProperties.Billing getBilling() {
        reloadIfNeeded();
        return cachedBilling;
    }

    public boolean isEnabled() {
        return getBilling().isEnabled();
    }

    private void reloadIfNeeded() {
        if (!StringUtils.hasText(runtimeConfigPath)) {
            if (cachedBilling == null) {
                cachedBilling = copyBilling(appProperties.getBilling());
            }
            return;
        }

        Path path = Path.of(runtimeConfigPath.trim());
        try {
            if (!Files.exists(path)) {
                if (cachedBilling == null) {
                    cachedBilling = copyBilling(appProperties.getBilling());
                }
                return;
            }

            long mtime = Files.getLastModifiedTime(path).toMillis();
            if (cachedBilling != null && mtime == cachedMtime) {
                return;
            }

            Map<String, String> overrides = DotEnvFileReader.read(path);
            cachedBilling = mergeBilling(appProperties.getBilling(), overrides);
            cachedMtime = mtime;
            log.info(
                    "billing config reloaded path={} enabled={} products={}",
                    runtimeConfigPath,
                    cachedBilling.isEnabled(),
                    cachedBilling.getProducts().size());
        } catch (IOException ex) {
            log.warn("billing config reload failed path={}", runtimeConfigPath, ex);
            if (cachedBilling == null) {
                cachedBilling = copyBilling(appProperties.getBilling());
            }
        }
    }

    private AppProperties.Billing mergeBilling(AppProperties.Billing base, Map<String, String> overrides) {
        AppProperties.Billing billing = copyBilling(base);
        if (overrides.containsKey("BILLING_ENABLED")) {
            billing.setEnabled(parseBoolean(overrides.get("BILLING_ENABLED"), billing.isEnabled()));
        }
        if (overrides.containsKey("BILLING_FREE_PLAN_NAME")) {
            billing.getFreePlan().setName(overrides.get("BILLING_FREE_PLAN_NAME"));
        }
        if (overrides.containsKey("BILLING_FREE_PLAN_DAILY_QUOTA")) {
            billing.getFreePlan().setDailyQuota(parseInt(overrides.get("BILLING_FREE_PLAN_DAILY_QUOTA"), billing.getFreePlan().getDailyQuota()));
        }
        if (overrides.containsKey("BILLING_UNPAID_PLAN_NAME")) {
            billing.getUnpaidPlan().setName(overrides.get("BILLING_UNPAID_PLAN_NAME"));
        }
        if (overrides.containsKey("LEMON_SQUEEZY_WEBHOOK_SECRET")) {
            billing.getLemonSqueezy().setWebhookSecret(overrides.get("LEMON_SQUEEZY_WEBHOOK_SECRET"));
        }
        if (overrides.containsKey("BILLING_ALLOW_TEST_MODE")) {
            billing.getLemonSqueezy()
                    .setAllowTestMode(parseBoolean(overrides.get("BILLING_ALLOW_TEST_MODE"), billing.getLemonSqueezy().isAllowTestMode()));
        }
        applyProductOverrides(billing, overrides);
        return billing;
    }

    private void applyProductOverrides(AppProperties.Billing billing, Map<String, String> overrides) {
        boolean hasProductOverride = overrides.containsKey("BILLING_VARIANT_ID")
                || overrides.containsKey("BILLING_CHECKOUT_URL")
                || overrides.containsKey("BILLING_PLAN_NAME")
                || overrides.containsKey("BILLING_DAILY_QUOTA")
                || overrides.containsKey("BILLING_DURATION_DAYS")
                || overrides.containsKey("BILLING_PRODUCT_LABEL");
        if (!hasProductOverride) {
            return;
        }

        AppProperties.BillingProduct product;
        if (billing.getProducts().isEmpty()) {
            product = new AppProperties.BillingProduct();
            billing.setProducts(new ArrayList<>(List.of(product)));
        } else {
            product = billing.getProducts().getFirst();
        }

        if (overrides.containsKey("BILLING_VARIANT_ID")) {
            product.setVariantId(overrides.get("BILLING_VARIANT_ID"));
        }
        if (overrides.containsKey("BILLING_CHECKOUT_URL")) {
            product.setCheckoutUrl(overrides.get("BILLING_CHECKOUT_URL"));
        }
        if (overrides.containsKey("BILLING_PLAN_NAME")) {
            product.setPlanName(overrides.get("BILLING_PLAN_NAME"));
        }
        if (overrides.containsKey("BILLING_DAILY_QUOTA")) {
            product.setDailyQuota(parseInt(overrides.get("BILLING_DAILY_QUOTA"), product.getDailyQuota()));
        }
        if (overrides.containsKey("BILLING_DURATION_DAYS")) {
            product.setDurationDays(parseInt(overrides.get("BILLING_DURATION_DAYS"), product.getDurationDays()));
        }
        if (overrides.containsKey("BILLING_PRODUCT_LABEL")) {
            product.setLabel(overrides.get("BILLING_PRODUCT_LABEL"));
        }
    }

    private static AppProperties.Billing copyBilling(AppProperties.Billing source) {
        AppProperties.Billing copy = new AppProperties.Billing();
        copy.setEnabled(source.isEnabled());
        copy.getFreePlan().setName(source.getFreePlan().getName());
        copy.getFreePlan().setDailyQuota(source.getFreePlan().getDailyQuota());
        copy.getUnpaidPlan().setName(source.getUnpaidPlan().getName());
        copy.getLemonSqueezy().setWebhookSecret(source.getLemonSqueezy().getWebhookSecret());
        copy.getLemonSqueezy().setAllowTestMode(source.getLemonSqueezy().isAllowTestMode());

        List<AppProperties.BillingProduct> products = new ArrayList<>();
        for (AppProperties.BillingProduct product : source.getProducts()) {
            products.add(copyProduct(product));
        }
        copy.setProducts(products);
        return copy;
    }

    private static AppProperties.BillingProduct copyProduct(AppProperties.BillingProduct source) {
        AppProperties.BillingProduct copy = new AppProperties.BillingProduct();
        copy.setVariantId(source.getVariantId());
        copy.setPlanName(source.getPlanName());
        copy.setDailyQuota(source.getDailyQuota());
        copy.setDurationDays(source.getDurationDays());
        copy.setLabel(source.getLabel());
        copy.setCheckoutUrl(source.getCheckoutUrl());
        return copy;
    }

    private static boolean parseBoolean(String raw, boolean defaultValue) {
        if (!StringUtils.hasText(raw)) {
            return defaultValue;
        }
        return switch (raw.trim().toLowerCase()) {
            case "1", "true", "yes", "on" -> true;
            case "0", "false", "no", "off" -> false;
            default -> defaultValue;
        };
    }

    private static int parseInt(String raw, int defaultValue) {
        if (!StringUtils.hasText(raw)) {
            return defaultValue;
        }
        try {
            return Integer.parseInt(raw.trim());
        } catch (NumberFormatException ex) {
            return defaultValue;
        }
    }
}

package com.brian.easytrans.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.brian.easytrans.config.AppProperties.BillingProduct;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class BillingConfigProviderTest {

    @TempDir
    Path tempDir;

    @Test
    void reloadsBillingEnabledFromRuntimeEnvFile() throws Exception {
        AppProperties appProperties = new AppProperties();
        appProperties.getBilling().setEnabled(false);

        Path runtimeEnv = tempDir.resolve("runtime.env");
        Files.writeString(runtimeEnv, "BILLING_ENABLED=true\n");

        appProperties.getBilling().setRuntimeConfigPath(runtimeEnv.toString());
        BillingConfigProvider provider = new BillingConfigProvider(appProperties);

        assertTrue(provider.isEnabled());

        Files.writeString(runtimeEnv, "BILLING_ENABLED=false\n");
        assertFalse(provider.isEnabled());
    }

    @Test
    void overridesProductFieldsFromRuntimeEnvFile() throws Exception {
        AppProperties appProperties = new AppProperties();
        BillingProduct product = new BillingProduct();
        product.setVariantId("old");
        product.setCheckoutUrl("https://example.com/old");
        appProperties.getBilling().setProducts(java.util.List.of(product));

        Path runtimeEnv = tempDir.resolve("runtime.env");
        Files.writeString(
                runtimeEnv,
                """
                BILLING_ENABLED=true
                BILLING_VARIANT_ID=1785152
                BILLING_CHECKOUT_URL=https://store.lemonsqueezy.com/checkout/buy/demo
                """);

        appProperties.getBilling().setRuntimeConfigPath(runtimeEnv.toString());
        BillingConfigProvider provider = new BillingConfigProvider(appProperties);

        BillingProduct effective = provider.getBilling().getProducts().getFirst();
        assertEquals("1785152", effective.getVariantId());
        assertEquals("https://store.lemonsqueezy.com/checkout/buy/demo", effective.getCheckoutUrl());
    }
}

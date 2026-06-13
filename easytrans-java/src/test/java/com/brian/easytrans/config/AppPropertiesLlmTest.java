package com.brian.easytrans.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.brian.easytrans.integration.llm.LlmProvider;
import org.junit.jupiter.api.Test;

class AppPropertiesLlmTest {

    @Test
    void resolveConfiguredProvidersSkipsMissingApiKey() {
        AppProperties.Llm llm = new AppProperties.Llm();
        llm.setProviders(java.util.List.of(entry("mimo", ""), entry("deepseek", "ds-key"), entry("dashscope", "  ")));

        var configured = llm.resolveConfiguredProviders();
        assertEquals(1, configured.size());
        assertEquals(LlmProvider.DEEPSEEK.getConfigValue(), configured.getFirst().getProvider());
    }

    @Test
    void resolveConfiguredProvidersUsesLegacySingleConfig() {
        AppProperties.Llm llm = new AppProperties.Llm();
        llm.setProvider("mimo");
        llm.setApiKey("legacy-key");

        var configured = llm.resolveConfiguredProviders();
        assertEquals(1, configured.size());
        assertEquals("mimo", configured.getFirst().getProvider());
        assertEquals("legacy-key", configured.getFirst().getApiKey());
    }

    @Test
    void resolveConfiguredProvidersRespectsOrder() {
        AppProperties.Llm llm = new AppProperties.Llm();
        llm.setProviders(java.util.List.of(entry("mimo", "m1"), entry("deepseek", "d1"), entry("dashscope", "d1")));

        var configured = llm.resolveConfiguredProviders();
        assertEquals(3, configured.size());
        assertEquals("mimo", configured.get(0).getProvider());
        assertEquals("deepseek", configured.get(1).getProvider());
        assertEquals("dashscope", configured.get(2).getProvider());
    }

    @Test
    void resolveConfiguredProvidersSkipsDisabled() {
        AppProperties.Llm llm = new AppProperties.Llm();
        LlmProviderEntry disabled = entry("mimo", "m1");
        disabled.setEnabled(false);
        llm.setProviders(java.util.List.of(disabled, entry("deepseek", "d1")));

        var configured = llm.resolveConfiguredProviders();
        assertEquals(1, configured.size());
        assertEquals("deepseek", configured.getFirst().getProvider());
    }

    private static LlmProviderEntry entry(String provider, String apiKey) {
        LlmProviderEntry entry = new LlmProviderEntry();
        entry.setProvider(provider);
        entry.setApiKey(apiKey);
        return entry;
    }
}

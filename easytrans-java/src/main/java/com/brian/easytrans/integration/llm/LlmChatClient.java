package com.brian.easytrans.integration.llm;

import com.brian.easytrans.common.BusinessException;
import com.brian.easytrans.config.AppProperties;
import com.brian.easytrans.config.LlmProviderEntry;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

@Component
public class LlmChatClient {

    private static final Logger log = LoggerFactory.getLogger(LlmChatClient.class);

    private final AppProperties.Llm llm;
    private final LlmChatTransport transport;

    public LlmChatClient(AppProperties appProperties, LlmChatTransport transport) {
        this.llm = appProperties.getLlm();
        this.transport = transport;
    }

    public String streamChatWithMessages(
            List<Map<String, String>> messages, double temperature, Consumer<String> onDelta) {
        List<LlmProviderEntry> endpoints = llm.resolveConfiguredProviders();
        if (endpoints.isEmpty()) {
            throw new BusinessException(
                    "服务端未配置任何可用的 LLM（请在 application-local.yaml 的 app.llm.providers 中配置 api-key）");
        }

        List<String> failures = new ArrayList<>();
        for (int i = 0; i < endpoints.size(); i++) {
            LlmProviderEntry endpoint = endpoints.get(i);
            String providerName = endpoint.resolveProvider().getConfigValue();
            boolean hasFallback = i < endpoints.size() - 1;
            try {
                log.info(
                        "llm attempt provider={} model={} fallbackAvailable={}",
                        providerName,
                        endpoint.resolveModel(),
                        hasFallback);
                return transport.streamChatWithMessages(endpoint, messages, temperature, onDelta);
            } catch (Exception ex) {
                String reason = ex.getMessage() == null ? ex.getClass().getSimpleName() : ex.getMessage();
                failures.add(providerName + ": " + reason);
                if (hasFallback) {
                    log.warn("llm fallback provider={} failed, trying next: {}", providerName, reason);
                } else {
                    log.error("llm all providers failed, last provider={} reason={}", providerName, reason, ex);
                }
            }
        }

        throw new BusinessException("所有翻译模型均不可用: " + String.join("; ", failures), HttpStatus.BAD_GATEWAY);
    }
}

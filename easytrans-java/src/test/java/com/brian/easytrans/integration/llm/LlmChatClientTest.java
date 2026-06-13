package com.brian.easytrans.integration.llm;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.brian.easytrans.common.BusinessException;
import com.brian.easytrans.config.AppProperties;
import com.brian.easytrans.config.LlmProviderEntry;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class LlmChatClientTest {

    private final AppProperties appProperties = new AppProperties();
    private final StubTransport transport = new StubTransport();
    private LlmChatClient chatClient;

    @BeforeEach
    void setUp() {
        chatClient = new LlmChatClient(appProperties, transport);
        transport.reset();
    }

    @Test
    void fallsBackToNextProviderWhenFirstFails() {
        appProperties.getLlm().setProviders(List.of(entry("mimo", "m1"), entry("deepseek", "d1")));
        transport.enqueueFailure(new BusinessException("mimo down"));
        transport.enqueueSuccess("hello");

        String result = chatClient.streamChatWithMessages(
                List.of(Map.of("role", "user", "content", "hi")), 0.3, delta -> {});

        assertEquals("hello", result);
        assertEquals(2, transport.attemptCount);
    }

    @Test
    void usesFirstSuccessfulProviderWithoutTryingOthers() {
        appProperties.getLlm().setProviders(List.of(entry("mimo", "m1"), entry("deepseek", "d1")));
        transport.enqueueSuccess("ok");

        String result = chatClient.streamChatWithMessages(
                List.of(Map.of("role", "user", "content", "hi")), 0.3, delta -> {});

        assertEquals("ok", result);
        assertEquals(1, transport.attemptCount);
    }

    @Test
    void throwsWhenAllProvidersFail() {
        appProperties.getLlm().setProviders(List.of(entry("mimo", "m1"), entry("deepseek", "d1")));
        transport.enqueueFailure(new BusinessException("fail-1"));
        transport.enqueueFailure(new BusinessException("fail-2"));

        BusinessException ex = assertThrows(
                BusinessException.class,
                () -> chatClient.streamChatWithMessages(
                        List.of(Map.of("role", "user", "content", "hi")), 0.3, delta -> {}));

        assertTrue(ex.getMessage().contains("所有翻译模型均不可用"));
        assertEquals(2, transport.attemptCount);
    }

    private static LlmProviderEntry entry(String provider, String apiKey) {
        LlmProviderEntry entry = new LlmProviderEntry();
        entry.setProvider(provider);
        entry.setApiKey(apiKey);
        return entry;
    }

    private static final class StubTransport implements LlmChatTransport {
        private final List<RuntimeException> failures = new ArrayList<>();
        private final List<String> successes = new ArrayList<>();
        private int attemptCount;

        void reset() {
            failures.clear();
            successes.clear();
            attemptCount = 0;
        }

        void enqueueFailure(RuntimeException ex) {
            failures.add(ex);
        }

        void enqueueSuccess(String result) {
            successes.add(result);
        }

        @Override
        public String streamChatWithMessages(
                LlmProviderEntry endpoint,
                List<Map<String, String>> messages,
                double temperature,
                Consumer<String> onDelta) {
            attemptCount++;
            if (!failures.isEmpty()) {
                throw failures.removeFirst();
            }
            String result = successes.removeFirst();
            onDelta.accept(result);
            return result;
        }
    }
}

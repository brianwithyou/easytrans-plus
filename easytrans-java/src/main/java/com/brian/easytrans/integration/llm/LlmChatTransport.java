package com.brian.easytrans.integration.llm;

import com.brian.easytrans.config.LlmProviderEntry;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;

public interface LlmChatTransport {

    String streamChatWithMessages(
            LlmProviderEntry endpoint,
            List<Map<String, String>> messages,
            double temperature,
            Consumer<String> onDelta);
}

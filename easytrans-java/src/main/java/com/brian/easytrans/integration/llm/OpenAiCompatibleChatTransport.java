package com.brian.easytrans.integration.llm;

import com.brian.easytrans.common.BusinessException;
import com.brian.easytrans.config.LlmProviderEntry;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

@Component
public class OpenAiCompatibleChatTransport implements LlmChatTransport {

    private static final Logger log = LoggerFactory.getLogger(OpenAiCompatibleChatTransport.class);

    private final ObjectMapper objectMapper;

    public OpenAiCompatibleChatTransport(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @Override
    public String streamChatWithMessages(
            LlmProviderEntry endpoint,
            List<Map<String, String>> messages,
            double temperature,
            Consumer<String> onDelta) {
        LlmProvider provider = endpoint.resolveProvider();
        String model = endpoint.resolveModel();
        long startTime = System.currentTimeMillis();
        log.debug("llm stream start provider={} model={}", provider.getConfigValue(), model);

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("model", model);
        body.put("messages", messages);
        body.put("temperature", temperature);
        body.put("stream", true);
        applyProviderExtras(provider, body);

        HttpURLConnection connection = null;
        try {
            connection = openStreamConnection(endpoint);
            byte[] payload = objectMapper.writeValueAsBytes(body);
            try (OutputStream outputStream = connection.getOutputStream()) {
                outputStream.write(payload);
            }

            int status = connection.getResponseCode();
            InputStream inputStream =
                    status >= 400 ? connection.getErrorStream() : connection.getInputStream();
            if (status >= 400) {
                String errorBody = readAll(inputStream);
                log.warn(
                        "LLM stream failed provider={} model={} status={} body={}",
                        provider.getConfigValue(),
                        model,
                        status,
                        errorBody);
                throw new BusinessException(
                        "provider " + provider.getConfigValue() + " HTTP " + status, HttpStatus.BAD_GATEWAY);
            }

            List<String> chunks = new ArrayList<>();
            StringBuilder full = new StringBuilder();
            try (BufferedReader reader =
                    new BufferedReader(new InputStreamReader(inputStream, StandardCharsets.UTF_8))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    if (!line.startsWith("data:")) {
                        continue;
                    }
                    String data = line.substring(5).trim();
                    if ("[DONE]".equals(data)) {
                        break;
                    }
                    JsonNode root = objectMapper.readTree(data);
                    JsonNode contentNode =
                            root.path("choices").path(0).path("delta").path("content");
                    if (contentNode.isMissingNode() || contentNode.isNull()) {
                        continue;
                    }
                    String chunk = contentNode.asText("");
                    if (!chunk.isEmpty()) {
                        full.append(chunk);
                        chunks.add(chunk);
                    }
                }
            }

            if (!StringUtils.hasText(full)) {
                throw new BusinessException("provider " + provider.getConfigValue() + " 返回空结果");
            }

            for (String chunk : chunks) {
                onDelta.accept(chunk);
            }

            String result = full.toString().trim();
            log.info(
                    "llm stream success provider={} model={} outputChars={} durationMs={}",
                    provider.getConfigValue(),
                    model,
                    result.length(),
                    System.currentTimeMillis() - startTime);
            return result;
        } catch (BusinessException ex) {
            throw ex;
        } catch (Exception ex) {
            log.warn("LLM stream request failed provider={} model={}", provider.getConfigValue(), model, ex);
            throw new BusinessException(
                    "provider " + provider.getConfigValue() + " 请求失败: " + ex.getMessage(),
                    HttpStatus.BAD_GATEWAY);
        } finally {
            if (connection != null) {
                connection.disconnect();
            }
        }
    }

    private void applyProviderExtras(LlmProvider provider, Map<String, Object> body) {
        if (provider == LlmProvider.MIMO) {
            body.put("thinking", Map.of("type", "disabled"));
        }
    }

    private HttpURLConnection openStreamConnection(LlmProviderEntry endpoint) throws Exception {
        String baseUrl = endpoint.resolveBaseUrl().replaceAll("/+$", "");
        HttpURLConnection connection =
                (HttpURLConnection) URI.create(baseUrl + "/chat/completions").toURL().openConnection();
        connection.setRequestMethod("POST");
        connection.setDoOutput(true);
        connection.setDoInput(true);
        connection.setConnectTimeout(15000);
        connection.setReadTimeout(120000);
        connection.setRequestProperty("Content-Type", MediaType.APPLICATION_JSON_VALUE);
        connection.setRequestProperty("Accept", "text/event-stream");
        applyAuthHeaders(connection, endpoint);
        return connection;
    }

    private void applyAuthHeaders(HttpURLConnection connection, LlmProviderEntry endpoint) {
        String apiKey = endpoint.getApiKey();
        if (endpoint.resolveProvider() == LlmProvider.MIMO) {
            connection.setRequestProperty("api-key", apiKey);
        }
        connection.setRequestProperty("Authorization", "Bearer " + apiKey);
    }

    private String readAll(InputStream inputStream) throws Exception {
        if (inputStream == null) {
            return "";
        }
        try (BufferedReader reader =
                new BufferedReader(new InputStreamReader(inputStream, StandardCharsets.UTF_8))) {
            StringBuilder builder = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                builder.append(line);
            }
            return builder.toString();
        }
    }
}

package com.brian.easytrans.integration.email;

import com.brian.easytrans.common.BusinessException;
import com.brian.easytrans.config.AppProperties;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

@Component
@ConditionalOnProperty(prefix = "app.email", name = "dev-mode", havingValue = "false")
public class ResendEmailGateway implements EmailGateway {

    private static final Logger log = LoggerFactory.getLogger(ResendEmailGateway.class);
    private static final URI RESEND_EMAILS_URI = URI.create("https://api.resend.com/emails");

    private final AppProperties.Email emailConfig;
    private final ObjectMapper objectMapper;

    public ResendEmailGateway(AppProperties appProperties, ObjectMapper objectMapper) {
        this.emailConfig = appProperties.getEmail();
        this.objectMapper = objectMapper;
    }

    @Override
    public void sendVerificationCode(String email, String scene, String code) {
        AppProperties.Resend resend = emailConfig.getResend();
        validateConfig(resend);

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("from", resend.getFrom());
        body.put("to", List.of(email));
        body.put("subject", "EasyTrans Plus 注册验证码");
        body.put("html", buildHtml(code));

        HttpURLConnection connection = null;
        try {
            connection = openConnection(resend.getApiKey());
            byte[] payload = objectMapper.writeValueAsBytes(body);
            try (OutputStream outputStream = connection.getOutputStream()) {
                outputStream.write(payload);
            }

            int status = connection.getResponseCode();
            if (status >= 200 && status < 300) {
                log.info("Resend email sent email={} scene={}", maskEmail(email), scene);
                return;
            }

            String errorBody = readBody(connection.getErrorStream());
            log.error("Resend email failed status={} body={}", status, errorBody);
            throw new BusinessException("邮件发送失败，请稍后重试");
        } catch (BusinessException ex) {
            throw ex;
        } catch (Exception ex) {
            log.error("Resend email error email={}", maskEmail(email), ex);
            throw new BusinessException("邮件发送失败，请稍后重试");
        } finally {
            if (connection != null) {
                connection.disconnect();
            }
        }
    }

    private HttpURLConnection openConnection(String apiKey) throws Exception {
        HttpURLConnection connection = (HttpURLConnection) RESEND_EMAILS_URI.toURL().openConnection();
        connection.setRequestMethod("POST");
        connection.setConnectTimeout(10_000);
        connection.setReadTimeout(15_000);
        connection.setDoOutput(true);
        connection.setRequestProperty("Authorization", "Bearer " + apiKey);
        connection.setRequestProperty("Content-Type", MediaType.APPLICATION_JSON_VALUE);
        connection.setRequestProperty("Accept", MediaType.APPLICATION_JSON_VALUE);
        return connection;
    }

    private String buildHtml(String code) {
        return """
                <div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;line-height:1.6;color:#111;">
                  <p>你好，</p>
                  <p>你正在注册 EasyTrans Plus，验证码为：</p>
                  <p style="font-size:28px;font-weight:700;letter-spacing:4px;">%s</p>
                  <p>验证码 10 分钟内有效，请勿泄露给他人。</p>
                  <p style="color:#666;font-size:13px;">如非本人操作，请忽略此邮件。</p>
                </div>
                """
                .formatted(code);
    }

    private void validateConfig(AppProperties.Resend resend) {
        if (!StringUtils.hasText(resend.getApiKey()) || !StringUtils.hasText(resend.getFrom())) {
            throw new BusinessException("Resend 邮件服务未配置完整，请检查 RESEND_API_KEY 与 RESEND_FROM");
        }
    }

    private String readBody(InputStream stream) {
        if (stream == null) {
            return "";
        }
        try (stream) {
            return new String(stream.readAllBytes(), StandardCharsets.UTF_8);
        } catch (Exception ex) {
            return "";
        }
    }

    private String maskEmail(String email) {
        if (email == null || email.isBlank()) {
            return "";
        }
        int atIndex = email.indexOf('@');
        if (atIndex <= 1) {
            return "***" + email.substring(Math.max(atIndex, 0));
        }
        return email.charAt(0) + "***" + email.substring(atIndex);
    }
}

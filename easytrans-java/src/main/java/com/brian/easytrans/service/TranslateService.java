package com.brian.easytrans.service;

import com.brian.easytrans.common.BusinessException;
import com.brian.easytrans.common.DeleteFlagConstants;
import com.brian.easytrans.dto.TranslateStreamRequest;
import com.brian.easytrans.entity.AppUser;
import com.brian.easytrans.integration.llm.LlmChatClient;
import com.brian.easytrans.util.AuditFillHelper;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import java.io.IOException;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

@Service
public class TranslateService {

    private static final Logger log = LoggerFactory.getLogger(TranslateService.class);

    private final AppUserDao appUserDao;
    private final LlmChatClient chatClient;
    private final ObjectMapper objectMapper;

    public TranslateService(AppUserDao appUserDao, LlmChatClient chatClient, ObjectMapper objectMapper) {
        this.appUserDao = appUserDao;
        this.chatClient = chatClient;
        this.objectMapper = objectMapper;
    }

    public SseEmitter streamTranslate(String userId, TranslateStreamRequest request) {
        String text = request.getText().trim();
        if (!StringUtils.hasText(text)) {
            throw new BusinessException("翻译文本不能为空");
        }

        AppUser user = appUserDao
                .findByIdAndDeleteFlag(userId, DeleteFlagConstants.NOT_DELETED)
                .orElseThrow(() -> new BusinessException("用户不存在", HttpStatus.UNAUTHORIZED));

        assertActive(user);
        resetDailyUsageIfNeeded(user);
        ensureQuota(user, text.length());

        TranslationLanguage source = TranslationLanguage.fromCode(request.getSourceLanguage());
        TranslationLanguage target = TranslationLanguage.fromCode(request.getTargetLanguage());
        TranslationStyle style = TranslationStyle.fromApiValue(request.getStyle());

        String systemPrompt = TranslationPromptBuilder.systemPrompt(source, target, style);
        String userPrompt = TranslationPromptBuilder.userPrompt(text);
        String clientRequestId = StringUtils.hasText(request.getClientRequestId())
                ? request.getClientRequestId()
                : "unknown";

        log.info(
                "translate start userId={} requestId={} source={} target={} style={} inputChars={} quotaUsed={} quotaLimit={}",
                user.getId(),
                clientRequestId,
                source.getCode(),
                target.getCode(),
                style.name(),
                text.length(),
                user.getDailyUsed(),
                user.getDailyQuota());

        SseEmitter emitter = new SseEmitter(120_000L);
        long startTime = System.currentTimeMillis();
        Thread.startVirtualThread(() -> runStream(user, text.length(), clientRequestId, systemPrompt, userPrompt, emitter, startTime));
        return emitter;
    }

    private void runStream(
            AppUser user,
            int charCount,
            String clientRequestId,
            String systemPrompt,
            String userPrompt,
            SseEmitter emitter,
            long startTime) {
        try {
            String result = chatClient.streamChatWithMessages(
                    List.of(
                            Map.of("role", "system", "content", systemPrompt),
                            Map.of("role", "user", "content", userPrompt)),
                    0.3,
                    delta -> sendDelta(emitter, delta));

            emitter.send(SseEmitter.event().data("[DONE]"));
            consumeUsage(user, charCount);
            emitter.complete();

            log.info(
                    "translate success userId={} requestId={} inputChars={} outputChars={} durationMs={} quotaUsed={}",
                    user.getId(),
                    clientRequestId,
                    charCount,
                    result.length(),
                    System.currentTimeMillis() - startTime,
                    user.getDailyUsed());
        } catch (Exception ex) {
            log.warn(
                    "translate failed userId={} requestId={} inputChars={} durationMs={} message={}",
                    user.getId(),
                    clientRequestId,
                    charCount,
                    System.currentTimeMillis() - startTime,
                    ex.getMessage());
            emitter.completeWithError(ex);
        }
    }

    private void sendDelta(SseEmitter emitter, String delta) {
        try {
            ObjectNode node = objectMapper.createObjectNode();
            node.put("delta", delta);
            emitter.send(SseEmitter.event().data(objectMapper.writeValueAsString(node)));
        } catch (IOException ex) {
            throw new BusinessException("翻译流发送失败", HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    private void ensureQuota(AppUser user, int charCount) {
        int quota = user.getDailyQuota() == null ? 0 : user.getDailyQuota();
        int used = user.getDailyUsed() == null ? 0 : user.getDailyUsed();
        if (used + charCount > quota) {
            log.warn(
                    "translate quota exceeded userId={} inputChars={} quotaUsed={} quotaLimit={}",
                    user.getId(),
                    charCount,
                    used,
                    quota);
            throw new BusinessException("今日翻译额度已用尽", HttpStatus.TOO_MANY_REQUESTS);
        }
    }

    private void consumeUsage(AppUser user, int charCount) {
        int used = user.getDailyUsed() == null ? 0 : user.getDailyUsed();
        user.setDailyUsed(used + charCount);
        AuditFillHelper.fillOnUpdate(user, user.getId(), "用户");
        appUserDao.update(user);
    }

    private void assertActive(AppUser user) {
        if (user.isDeleted()) {
            throw new BusinessException("账号不存在", HttpStatus.UNAUTHORIZED);
        }
        if (user.getStatus() == null || user.getStatus() != 1) {
            throw new BusinessException("账号已被禁用", HttpStatus.FORBIDDEN);
        }
    }

    private void resetDailyUsageIfNeeded(AppUser user) {
        LocalDate today = LocalDate.now();
        if (user.getUsageResetDate() == null || !today.equals(user.getUsageResetDate())) {
            user.setUsageResetDate(today);
            user.setDailyUsed(0);
            AuditFillHelper.fillOnUpdate(user, user.getId(), "用户");
            appUserDao.update(user);
            log.info("usage reset userId={} date={}", user.getId(), today);
        }
    }
}

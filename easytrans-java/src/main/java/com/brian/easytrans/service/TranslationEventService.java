package com.brian.easytrans.service;

import com.brian.easytrans.entity.TranslationEventEntity;
import com.brian.easytrans.util.AuditFillHelper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

@Service
public class TranslationEventService {

    private static final Logger log = LoggerFactory.getLogger(TranslationEventService.class);
    private static final int MAX_ERROR_MESSAGE_LENGTH = 512;

    private final TranslationEventDao translationEventDao;

    public TranslationEventService(TranslationEventDao translationEventDao) {
        this.translationEventDao = translationEventDao;
    }

    public void recordSuccess(TranslationEventContext context, int outputChars) {
        TranslationEventEntity entity = baseEntity(context);
        entity.setOutputChars(outputChars);
        entity.setDurationMs(context.durationMs());
        entity.setStatus(TranslationEventStatus.SUCCESS.getValue());
        persist(entity);
    }

    public void recordFailure(TranslationEventContext context, String errorMessage) {
        TranslationEventEntity entity = baseEntity(context);
        entity.setDurationMs(context.durationMs());
        entity.setStatus(TranslationEventStatus.FAILED.getValue());
        entity.setErrorMessage(truncateErrorMessage(errorMessage));
        persist(entity);
    }

    public void recordQuotaExceeded(TranslationEventContext context) {
        TranslationEventEntity entity = baseEntity(context);
        entity.setDurationMs(context.durationMs());
        entity.setStatus(TranslationEventStatus.QUOTA_EXCEEDED.getValue());
        entity.setErrorMessage("今日翻译额度已用尽，请明日再试或续费");
        persist(entity);
    }

    private TranslationEventEntity baseEntity(TranslationEventContext context) {
        TranslationEventEntity entity = new TranslationEventEntity();
        entity.setUserId(context.getUserId());
        entity.setRequestId(context.getRequestId());
        entity.setClientRequestId(context.getClientRequestId());
        entity.setSourceLang(context.getSourceLang());
        entity.setTargetLang(context.getTargetLang());
        entity.setStyle(context.getStyle());
        entity.setInputChars(context.getInputChars());
        AuditFillHelper.fillOnCreate(entity, context.getUserId(), "用户");
        return entity;
    }

    private void persist(TranslationEventEntity entity) {
        try {
            translationEventDao.insert(entity);
        } catch (Exception ex) {
            log.warn(
                    "translation event persist failed userId={} requestId={} status={} message={}",
                    entity.getUserId(),
                    entity.getRequestId(),
                    entity.getStatus(),
                    ex.getMessage());
        }
    }

    private String truncateErrorMessage(String errorMessage) {
        if (!StringUtils.hasText(errorMessage)) {
            return null;
        }
        String trimmed = errorMessage.trim();
        if (trimmed.length() <= MAX_ERROR_MESSAGE_LENGTH) {
            return trimmed;
        }
        return trimmed.substring(0, MAX_ERROR_MESSAGE_LENGTH);
    }
}

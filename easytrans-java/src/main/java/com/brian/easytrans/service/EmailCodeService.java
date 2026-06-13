package com.brian.easytrans.service;

import com.brian.easytrans.common.BusinessException;
import com.brian.easytrans.common.DeleteFlagConstants;
import com.brian.easytrans.config.AppProperties;
import com.brian.easytrans.entity.EmailVerificationCodeEntity;
import com.brian.easytrans.integration.email.EmailGateway;
import com.brian.easytrans.util.AuditFillHelper;
import java.time.LocalDateTime;
import java.util.concurrent.ThreadLocalRandom;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class EmailCodeService {

    public static final String SCENE_REGISTER = "register";

    private static final Logger log = LoggerFactory.getLogger(EmailCodeService.class);

    private final EmailVerificationCodeDao emailVerificationCodeDao;
    private final AppUserDao appUserDao;
    private final AppProperties appProperties;
    private final EmailGateway emailGateway;

    public EmailCodeService(
            EmailVerificationCodeDao emailVerificationCodeDao,
            AppUserDao appUserDao,
            AppProperties appProperties,
            EmailGateway emailGateway) {
        this.emailVerificationCodeDao = emailVerificationCodeDao;
        this.appUserDao = appUserDao;
        this.appProperties = appProperties;
        this.emailGateway = emailGateway;
    }

    @Transactional
    public void sendCode(String email, String scene) {
        String normalizedEmail = normalizeEmail(email);
        assertSceneSupported(scene);
        assertCanSend(normalizedEmail, scene);

        AppProperties.Email emailConfig = appProperties.getEmail();
        String code = emailConfig.isDevMode()
                ? emailConfig.getDevCode()
                : String.format("%06d", ThreadLocalRandom.current().nextInt(0, 1_000_000));

        EmailVerificationCodeEntity entity = new EmailVerificationCodeEntity();
        entity.setEmail(normalizedEmail);
        entity.setCode(code);
        entity.setScene(scene);
        entity.setExpiresAt(LocalDateTime.now().plusMinutes(emailConfig.getExpireMinutes()));
        entity.setUsed(false);
        AuditFillHelper.fillOnCreate(entity, AuditFillHelper.SYSTEM_OPERATOR_ID, AuditFillHelper.SYSTEM_OPERATOR_NAME);
        emailVerificationCodeDao.insert(entity);

        emailGateway.sendVerificationCode(normalizedEmail, scene, code);
        log.info("email code sent email={} scene={}", maskEmail(normalizedEmail), scene);
    }

    @Transactional
    public void verifyCode(String email, String scene, String code) {
        String normalizedEmail = normalizeEmail(email);
        assertSceneSupported(scene);

        EmailVerificationCodeEntity latest = emailVerificationCodeDao
                .findLatestValid(normalizedEmail, scene, DeleteFlagConstants.NOT_DELETED, LocalDateTime.now())
                .orElseThrow(() -> new BusinessException("验证码无效或已过期"));

        if (!latest.getCode().equals(code)) {
            throw new BusinessException("验证码错误");
        }

        latest.setUsed(true);
        AuditFillHelper.fillOnUpdate(latest, AuditFillHelper.SYSTEM_OPERATOR_ID, AuditFillHelper.SYSTEM_OPERATOR_NAME);
        emailVerificationCodeDao.update(latest);
    }

    private void assertCanSend(String email, String scene) {
        if (SCENE_REGISTER.equals(scene)
                && appUserDao.existsByEmailAndDeleteFlag(email, DeleteFlagConstants.NOT_DELETED)) {
            throw new BusinessException("该邮箱已注册");
        }

        AppProperties.Email emailConfig = appProperties.getEmail();
        LocalDateTime now = LocalDateTime.now();

        emailVerificationCodeDao
                .findLatest(email, scene, DeleteFlagConstants.NOT_DELETED)
                .ifPresent(latest -> {
                    LocalDateTime nextAllowed =
                            latest.getCreateTime().plusSeconds(emailConfig.getResendIntervalSeconds());
                    if (nextAllowed.isAfter(now)) {
                        throw new BusinessException("发送过于频繁，请稍后再试");
                    }
                });

        long sentCount = emailVerificationCodeDao.countSince(
                email, scene, DeleteFlagConstants.NOT_DELETED, now.minusHours(24));
        if (sentCount >= emailConfig.getDailyLimit()) {
            throw new BusinessException("今日验证码发送次数已达上限");
        }
    }

    private void assertSceneSupported(String scene) {
        if (!SCENE_REGISTER.equals(scene)) {
            throw new BusinessException("不支持的验证码场景");
        }
    }

    private String normalizeEmail(String email) {
        return email.trim().toLowerCase();
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

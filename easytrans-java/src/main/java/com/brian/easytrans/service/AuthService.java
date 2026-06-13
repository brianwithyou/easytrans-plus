package com.brian.easytrans.service;

import com.brian.easytrans.common.BusinessException;
import com.brian.easytrans.common.DeleteFlagConstants;
import com.brian.easytrans.dto.AuthResultDto;
import com.brian.easytrans.dto.EmailLoginRequest;
import com.brian.easytrans.dto.EmailRegisterRequest;
import com.brian.easytrans.dto.MeResponse;
import com.brian.easytrans.entity.AppUser;
import com.brian.easytrans.security.JwtService;
import com.brian.easytrans.util.AuditFillHelper;
import java.time.LocalDate;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);

    private final AppUserDao appUserDao;
    private final JwtService jwtService;
    private final PasswordEncoder passwordEncoder;
    private final EmailCodeService emailCodeService;

    public AuthService(
            AppUserDao appUserDao,
            JwtService jwtService,
            PasswordEncoder passwordEncoder,
            EmailCodeService emailCodeService) {
        this.appUserDao = appUserDao;
        this.jwtService = jwtService;
        this.passwordEncoder = passwordEncoder;
        this.emailCodeService = emailCodeService;
    }

    @Transactional
    public AuthResultDto register(EmailRegisterRequest request) {
        String email = normalizeEmail(request.getEmail());
        if (appUserDao.existsByEmailAndDeleteFlag(email, DeleteFlagConstants.NOT_DELETED)) {
            log.warn("auth register failed email={} reason=already_exists", maskEmail(email));
            throw new BusinessException("该邮箱已注册");
        }

        emailCodeService.verifyCode(email, EmailCodeService.SCENE_REGISTER, request.getCode());

        AppUser user = new AppUser();
        user.setEmail(email);
        user.setPasswordHash(passwordEncoder.encode(request.getPassword()));
        user.setNickname(extractNickname(email));
        user.setPlanName("标准版");
        user.setDailyQuota(50000);
        user.setDailyUsed(0);
        user.setUsageResetDate(LocalDate.now());
        user.setStatus(1);
        AuditFillHelper.fillOnCreate(user, AuditFillHelper.SYSTEM_OPERATOR_ID, AuditFillHelper.SYSTEM_OPERATOR_NAME);
        appUserDao.insert(user);

        log.info("auth register success userId={} email={}", user.getId(), maskEmail(email));
        return buildAuthResult(user);
    }

    public AuthResultDto login(EmailLoginRequest request) {
        String email = normalizeEmail(request.getEmail());
        AppUser user = appUserDao
                .findByEmailAndDeleteFlag(email, DeleteFlagConstants.NOT_DELETED)
                .orElseThrow(() -> {
                    log.warn("auth login failed email={} reason=user_not_found", maskEmail(email));
                    return new BusinessException("邮箱或密码错误", HttpStatus.UNAUTHORIZED);
                });

        assertActive(user);
        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            log.warn("auth login failed userId={} email={} reason=bad_password", user.getId(), maskEmail(email));
            throw new BusinessException("邮箱或密码错误", HttpStatus.UNAUTHORIZED);
        }

        resetDailyUsageIfNeeded(user);
        log.info("auth login success userId={} email={}", user.getId(), maskEmail(email));
        return buildAuthResult(user);
    }

    public AuthResultDto refresh(String refreshToken) {
        String userId = jwtService.parseRefreshUserId(refreshToken);
        AppUser user = appUserDao
                .findByIdAndDeleteFlag(userId, DeleteFlagConstants.NOT_DELETED)
                .orElseThrow(() -> new BusinessException("登录已失效，请重新登录", HttpStatus.UNAUTHORIZED));

        assertActive(user);
        resetDailyUsageIfNeeded(user);
        log.info("auth refresh success userId={} email={}", user.getId(), maskEmail(user.getEmail()));
        return buildAuthResult(user);
    }

    public MeResponse getCurrentUser(String userId) {
        AppUser user = appUserDao
                .findByIdAndDeleteFlag(userId, DeleteFlagConstants.NOT_DELETED)
                .orElseThrow(() -> new BusinessException("用户不存在", HttpStatus.UNAUTHORIZED));

        assertActive(user);
        resetDailyUsageIfNeeded(user);
        return UserDtoMapper.toMeResponse(user);
    }

    private AuthResultDto buildAuthResult(AppUser user) {
        String accessToken = jwtService.generateAccessToken(user.getId());
        String refreshToken = jwtService.generateRefreshToken(user.getId());
        return new AuthResultDto(accessToken, refreshToken, UserDtoMapper.toAuthUserDto(user));
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

    private String normalizeEmail(String email) {
        return email.trim().toLowerCase();
    }

    private String extractNickname(String email) {
        int atIndex = email.indexOf('@');
        if (atIndex > 0) {
            return email.substring(0, atIndex);
        }
        return email;
    }
}

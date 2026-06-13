package com.brian.easytrans.integration.email;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(prefix = "app.email", name = "dev-mode", havingValue = "true", matchIfMissing = true)
public class DevEmailGateway implements EmailGateway {

    private static final Logger log = LoggerFactory.getLogger(DevEmailGateway.class);

    @Override
    public void sendVerificationCode(String email, String scene, String code) {
        log.info("[dev-email] email={}, scene={}, code={}", maskEmail(email), scene, code);
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

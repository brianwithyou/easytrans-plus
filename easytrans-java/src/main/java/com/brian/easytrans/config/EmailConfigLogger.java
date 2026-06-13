package com.brian.easytrans.config;

import com.brian.easytrans.config.AppProperties.Email;
import com.brian.easytrans.config.AppProperties.Resend;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

@Component
public class EmailConfigLogger implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(EmailConfigLogger.class);

    private final AppProperties appProperties;

    public EmailConfigLogger(AppProperties appProperties) {
        this.appProperties = appProperties;
    }

    @Override
    public void run(ApplicationArguments args) {
        Email email = appProperties.getEmail();
        if (email.isDevMode()) {
            log.warn(
                    "email service: DEV MODE is ON — verification codes are NOT emailed (fixed code={})",
                    email.getDevCode());
            return;
        }

        Resend resend = email.getResend();
        boolean apiKeyConfigured = StringUtils.hasText(resend.getApiKey());
        boolean fromConfigured = StringUtils.hasText(resend.getFrom());
        if (!apiKeyConfigured || !fromConfigured) {
            log.error(
                    "email service: Resend is enabled but incomplete — apiKeyConfigured={} fromConfigured={} from={}",
                    apiKeyConfigured,
                    fromConfigured,
                    resend.getFrom());
            return;
        }

        log.info("email service: Resend enabled, from={}", resend.getFrom());
    }
}

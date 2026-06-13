package com.brian.easytrans.service;

import com.brian.easytrans.common.BusinessException;
import com.brian.easytrans.common.DeleteFlagConstants;
import com.brian.easytrans.config.AppProperties;
import com.brian.easytrans.entity.AppUser;
import com.brian.easytrans.entity.BillingOrderEntity;
import com.brian.easytrans.util.AuditFillHelper;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import java.util.HexFormat;
import java.util.Optional;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

@Service
public class LemonSqueezyWebhookService {

    private static final Logger log = LoggerFactory.getLogger(LemonSqueezyWebhookService.class);

    private final AppProperties appProperties;
    private final AppUserDao appUserDao;
    private final BillingOrderDao billingOrderDao;
    private final PlanService planService;
    private final ObjectMapper objectMapper;

    public LemonSqueezyWebhookService(
            AppProperties appProperties,
            AppUserDao appUserDao,
            BillingOrderDao billingOrderDao,
            PlanService planService,
            ObjectMapper objectMapper) {
        this.appProperties = appProperties;
        this.appUserDao = appUserDao;
        this.billingOrderDao = billingOrderDao;
        this.planService = planService;
        this.objectMapper = objectMapper;
    }

    public void verifySignature(byte[] rawBody, String signatureHeader) {
        if (!appProperties.getBilling().isEnabled()) {
            throw new BusinessException("Billing disabled", HttpStatus.NOT_FOUND);
        }

        String secret = appProperties.getBilling().getLemonSqueezy().getWebhookSecret();
        if (!StringUtils.hasText(secret)) {
            throw new BusinessException("Webhook secret not configured", HttpStatus.SERVICE_UNAVAILABLE);
        }
        if (!StringUtils.hasText(signatureHeader)) {
            throw new BusinessException("Missing signature", HttpStatus.BAD_REQUEST);
        }

        String expected = hmacSha256Hex(secret, rawBody);
        if (!constantTimeEquals(expected, signatureHeader.trim())) {
            throw new BusinessException("Invalid signature", HttpStatus.BAD_REQUEST);
        }
    }

    @Transactional
    public void handleEvent(byte[] rawBody) {
        JsonNode root;
        try {
            root = objectMapper.readTree(rawBody);
        } catch (Exception ex) {
            throw new BusinessException("Invalid webhook payload", HttpStatus.BAD_REQUEST);
        }

        String eventName = textAt(root, "meta", "event_name");
        if (!StringUtils.hasText(eventName)) {
            throw new BusinessException("Missing event name", HttpStatus.BAD_REQUEST);
        }

        switch (eventName) {
            case "order_created" -> handleOrderCreated(root, eventName);
            case "order_refunded" -> handleOrderRefunded(root, eventName);
            default -> log.info("billing webhook ignored event={}", eventName);
        }
    }

    private void handleOrderCreated(JsonNode root, String eventName) {
        JsonNode attributes = root.path("data").path("attributes");
        String orderId = textAt(root, "data", "id");
        String status = attributes.path("status").asText("");
        boolean testMode = attributes.path("test_mode").asBoolean(false);

        if (!"paid".equalsIgnoreCase(status)) {
            log.info("billing webhook skip unpaid orderId={} status={}", orderId, status);
            return;
        }
        if (testMode && !appProperties.getBilling().getLemonSqueezy().isAllowTestMode()) {
            log.warn("billing webhook skip test orderId={}", orderId);
            return;
        }
        if (!StringUtils.hasText(orderId)) {
            throw new BusinessException("Missing order id", HttpStatus.BAD_REQUEST);
        }
        if (billingOrderDao.existsByLemonOrderIdAndEventName(orderId, eventName)) {
            log.info("billing webhook duplicate orderId={}", orderId);
            return;
        }

        JsonNode variantNode = attributes.path("first_order_item").path("variant_id");
        String variantId = variantNode.isNumber()
                ? String.valueOf(variantNode.asLong())
                : variantNode.asText("");
        if (!StringUtils.hasText(variantId)) {
            throw new BusinessException("Missing variant id", HttpStatus.BAD_REQUEST);
        }

        AppProperties.BillingProduct product = appProperties.getBilling().findProductByVariantId(variantId)
                .orElseThrow(() -> new BusinessException("Unknown variant: " + variantId, HttpStatus.BAD_REQUEST));

        AppUser user = resolveUser(root, attributes).orElseThrow(() -> {
            log.warn("billing webhook user not found orderId={} email={}", orderId, attributes.path("user_email").asText(""));
            return new BusinessException("User not found for order", HttpStatus.BAD_REQUEST);
        });

        planService.extendPaidPlan(user, product);
        saveBillingOrder(orderId, user.getId(), variantId, eventName, "paid");

        log.info(
                "billing order applied userId={} orderId={} variantId={} plan={} expiresAt={}",
                user.getId(),
                orderId,
                variantId,
                user.getPlanName(),
                user.getPlanExpiresAt());
    }

    private void handleOrderRefunded(JsonNode root, String eventName) {
        String orderId = textAt(root, "data", "id");
        if (!StringUtils.hasText(orderId)) {
            return;
        }
        if (billingOrderDao.existsByLemonOrderIdAndEventName(orderId, eventName)) {
            return;
        }

        billingOrderDao.findPaidOrderByLemonOrderId(orderId).ifPresent(paidOrder -> {
            appUserDao.findByIdAndDeleteFlag(paidOrder.getUserId(), DeleteFlagConstants.NOT_DELETED).ifPresent(user -> {
                planService.revokePaidPlan(user);
                saveBillingOrder(orderId, user.getId(), paidOrder.getVariantId(), eventName, "refunded");
                log.info("billing order refunded userId={} orderId={}", user.getId(), orderId);
            });
        });
    }

    private Optional<AppUser> resolveUser(JsonNode root, JsonNode attributes) {
        String userId = textAt(root, "meta", "custom_data", "user_id");
        if (StringUtils.hasText(userId)) {
            Optional<AppUser> byId = appUserDao.findByIdAndDeleteFlag(userId, DeleteFlagConstants.NOT_DELETED);
            if (byId.isPresent()) {
                return byId;
            }
        }

        String email = attributes.path("user_email").asText("");
        if (!StringUtils.hasText(email)) {
            return Optional.empty();
        }
        return appUserDao.findByEmailAndDeleteFlag(email.trim().toLowerCase(), DeleteFlagConstants.NOT_DELETED);
    }

    private void saveBillingOrder(
            String lemonOrderId, String userId, String variantId, String eventName, String status) {
        BillingOrderEntity entity = new BillingOrderEntity();
        entity.setLemonOrderId(lemonOrderId);
        entity.setUserId(userId);
        entity.setVariantId(variantId);
        entity.setEventName(eventName);
        entity.setStatus(status);
        AuditFillHelper.fillOnCreate(entity, AuditFillHelper.SYSTEM_OPERATOR_ID, AuditFillHelper.SYSTEM_OPERATOR_NAME);
        billingOrderDao.insert(entity);
    }

    private static String textAt(JsonNode root, String... path) {
        JsonNode current = root;
        for (String segment : path) {
            if (current == null || current.isMissingNode()) {
                return "";
            }
            current = current.path(segment);
        }
        return current.isMissingNode() || current.isNull() ? "" : current.asText("");
    }

    private static String hmacSha256Hex(String secret, byte[] body) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            return HexFormat.of().formatHex(mac.doFinal(body));
        } catch (Exception ex) {
            throw new IllegalStateException("HMAC init failed", ex);
        }
    }

    private static boolean constantTimeEquals(String left, String right) {
        if (left.length() != right.length()) {
            return false;
        }
        int result = 0;
        for (int i = 0; i < left.length(); i++) {
            result |= left.charAt(i) ^ right.charAt(i);
        }
        return result == 0;
    }
}

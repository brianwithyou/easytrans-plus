package com.brian.easytrans.service;

import com.brian.easytrans.common.BusinessException;
import com.brian.easytrans.common.DeleteFlagConstants;
import com.brian.easytrans.config.AppProperties;
import com.brian.easytrans.config.AppProperties;
import com.brian.easytrans.config.BillingConfigProvider;
import com.brian.easytrans.dto.BillingCheckoutResponse;
import com.brian.easytrans.dto.BillingConfigResponse;
import com.brian.easytrans.dto.BillingProductDto;
import com.brian.easytrans.entity.AppUser;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Locale;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

@Service
public class BillingService {

    private final BillingConfigProvider billingConfigProvider;
    private final AppUserDao appUserDao;

    public BillingService(BillingConfigProvider billingConfigProvider, AppUserDao appUserDao) {
        this.billingConfigProvider = billingConfigProvider;
        this.appUserDao = appUserDao;
    }

    public BillingConfigResponse getPublicConfig() {
        BillingConfigResponse response = new BillingConfigResponse();
        AppProperties.Billing billing = billingConfigProvider.getBilling();
        response.setEnabled(billing.isEnabled());
        response.setMode(billing.isEnabled() ? "paid" : "free");
        if (!billing.isEnabled()) {
            return response;
        }

        List<BillingProductDto> products = billing.getProducts().stream()
                .filter(product -> StringUtils.hasText(product.getVariantId()))
                .filter(product -> StringUtils.hasText(product.getCheckoutUrl()))
                .map(this::toProductDto)
                .toList();
        response.setProducts(products);
        return response;
    }

    public BillingCheckoutResponse createCheckout(String userId, String variantId) {
        assertBillingEnabled();

        AppProperties.BillingProduct product = billingConfigProvider.getBilling().findProductByVariantId(variantId)
                .filter(item -> StringUtils.hasText(item.getCheckoutUrl()))
                .orElseThrow(() -> new BusinessException("未找到可购买的基础版套餐", HttpStatus.NOT_FOUND));

        AppUser user = appUserDao
                .findByIdAndDeleteFlag(userId, DeleteFlagConstants.NOT_DELETED)
                .orElseThrow(() -> new BusinessException("用户不存在", HttpStatus.UNAUTHORIZED));

        BillingCheckoutResponse response = new BillingCheckoutResponse();
        response.setVariantId(product.getVariantId());
        response.setLabel(resolveLabel(product));
        response.setCheckoutUrl(buildCheckoutUrl(product.getCheckoutUrl(), user.getId(), user.getEmail()));
        return response;
    }

    private void assertBillingEnabled() {
        if (!billingConfigProvider.getBilling().isEnabled()) {
            throw new BusinessException("当前未开启付费功能", HttpStatus.NOT_FOUND);
        }
    }

    private BillingProductDto toProductDto(AppProperties.BillingProduct product) {
        BillingProductDto dto = new BillingProductDto();
        dto.setVariantId(product.getVariantId());
        dto.setPlanName(product.getPlanName());
        dto.setDailyQuota(product.getDailyQuota());
        dto.setDurationDays(product.getDurationDays());
        dto.setLabel(resolveLabel(product));
        return dto;
    }

    private String resolveLabel(AppProperties.BillingProduct product) {
        if (StringUtils.hasText(product.getLabel())) {
            return product.getLabel();
        }
        return product.getPlanName() + "（" + product.getDurationDays() + "天）";
    }

    static String buildCheckoutUrl(String baseUrl, String userId, String email) {
        String normalizedBase = baseUrl.trim();
        int queryIndex = normalizedBase.indexOf('?');
        if (queryIndex >= 0) {
            normalizedBase = normalizedBase.substring(0, queryIndex);
        }
        int fragmentIndex = normalizedBase.indexOf('#');
        if (fragmentIndex >= 0) {
            normalizedBase = normalizedBase.substring(0, fragmentIndex);
        }

        StringBuilder url = new StringBuilder(normalizedBase);
        char separator = '?';
        if (StringUtils.hasText(email)) {
            url.append(separator)
                    .append("checkout[email]=")
                    .append(encodeCheckoutQueryValue(email.trim()));
            separator = '&';
        }
        if (StringUtils.hasText(userId)) {
            url.append(separator)
                    .append("checkout[custom][user_id]=")
                    .append(encodeCheckoutQueryValue(userId));
        }
        return url.toString();
    }

    private static String encodeCheckoutQueryValue(String value) {
        if (value == null || value.isEmpty()) {
            return "";
        }
        StringBuilder out = new StringBuilder(value.length());
        for (int offset = 0; offset < value.length(); ) {
            int codePoint = value.codePointAt(offset);
            if (isCheckoutQueryLiteral(codePoint)) {
                out.appendCodePoint(codePoint);
            } else {
                byte[] bytes = new String(Character.toChars(codePoint)).getBytes(StandardCharsets.UTF_8);
                for (byte b : bytes) {
                    out.append('%').append(String.format(Locale.ROOT, "%02X", b & 0xFF));
                }
            }
            offset += Character.charCount(codePoint);
        }
        return out.toString();
    }

    private static boolean isCheckoutQueryLiteral(int codePoint) {
        return (codePoint >= 'A' && codePoint <= 'Z')
                || (codePoint >= 'a' && codePoint <= 'z')
                || (codePoint >= '0' && codePoint <= '9')
                || codePoint == '-'
                || codePoint == '_'
                || codePoint == '.'
                || codePoint == '@';
    }
}

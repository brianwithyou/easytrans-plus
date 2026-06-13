package com.brian.easytrans.service;

import com.brian.easytrans.common.BusinessException;
import com.brian.easytrans.common.DeleteFlagConstants;
import com.brian.easytrans.config.AppProperties;
import com.brian.easytrans.dto.BillingCheckoutResponse;
import com.brian.easytrans.dto.BillingConfigResponse;
import com.brian.easytrans.dto.BillingProductDto;
import com.brian.easytrans.entity.AppUser;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

@Service
public class BillingService {

    private final AppProperties appProperties;
    private final AppUserDao appUserDao;

    public BillingService(AppProperties appProperties, AppUserDao appUserDao) {
        this.appProperties = appProperties;
        this.appUserDao = appUserDao;
    }

    public BillingConfigResponse getPublicConfig() {
        BillingConfigResponse response = new BillingConfigResponse();
        AppProperties.Billing billing = appProperties.getBilling();
        response.setEnabled(billing.isEnabled());
        response.setMode(billing.isEnabled() ? "paid" : "free");
        if (!billing.isEnabled()) {
            return response;
        }

        List<BillingProductDto> products = billing.getProducts().stream()
                .filter(product -> StringUtils.hasText(product.getCheckoutUrl()))
                .map(this::toProductDto)
                .toList();
        response.setProducts(products);
        return response;
    }

    public BillingCheckoutResponse createCheckout(String userId, String variantId) {
        assertBillingEnabled();

        AppProperties.BillingProduct product = appProperties.getBilling().findProductByVariantId(variantId)
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
        if (!appProperties.getBilling().isEnabled()) {
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
        StringBuilder url = new StringBuilder(baseUrl.trim());
        char separator = baseUrl.contains("?") ? '&' : '?';
        url.append(separator)
                .append("checkout[email]=")
                .append(encode(email));
        url.append("&checkout[custom][user_id]=").append(encode(userId));
        return url.toString();
    }

    private static String encode(String value) {
        return URLEncoder.encode(value == null ? "" : value, StandardCharsets.UTF_8);
    }
}

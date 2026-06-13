package com.brian.easytrans.controller;

import com.brian.easytrans.dto.BillingCheckoutResponse;
import com.brian.easytrans.dto.BillingConfigResponse;
import com.brian.easytrans.security.JwtAuthInterceptor;
import com.brian.easytrans.service.BillingService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/billing")
public class BillingController {

    private final BillingService billingService;

    public BillingController(BillingService billingService) {
        this.billingService = billingService;
    }

    @GetMapping("/config")
    public BillingConfigResponse config() {
        return billingService.getPublicConfig();
    }

    @GetMapping("/checkout")
    public BillingCheckoutResponse checkout(
            HttpServletRequest request, @RequestParam("variantId") String variantId) {
        String userId = (String) request.getAttribute(JwtAuthInterceptor.USER_ID_ATTR);
        return billingService.createCheckout(userId, variantId);
    }
}

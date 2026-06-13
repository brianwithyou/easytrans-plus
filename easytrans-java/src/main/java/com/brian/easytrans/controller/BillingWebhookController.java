package com.brian.easytrans.controller;

import com.brian.easytrans.service.LemonSqueezyWebhookService;
import jakarta.servlet.http.HttpServletRequest;
import java.io.IOException;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/billing")
public class BillingWebhookController {

    private final LemonSqueezyWebhookService webhookService;

    public BillingWebhookController(LemonSqueezyWebhookService webhookService) {
        this.webhookService = webhookService;
    }

    @PostMapping("/webhook")
    public ResponseEntity<Void> webhook(HttpServletRequest request) throws IOException {
        byte[] rawBody = request.getInputStream().readAllBytes();
        String signature = request.getHeader("X-Signature");
        webhookService.verifySignature(rawBody, signature);
        webhookService.handleEvent(rawBody);
        return ResponseEntity.ok().build();
    }
}

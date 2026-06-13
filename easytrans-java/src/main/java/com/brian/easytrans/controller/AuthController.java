package com.brian.easytrans.controller;

import com.brian.easytrans.dto.AuthResultDto;
import com.brian.easytrans.dto.EmailLoginRequest;
import com.brian.easytrans.dto.EmailRegisterRequest;
import com.brian.easytrans.dto.EmailSendCodeRequest;
import com.brian.easytrans.dto.RefreshTokenRequest;
import com.brian.easytrans.service.AuthService;
import com.brian.easytrans.service.EmailCodeService;
import jakarta.validation.Valid;
import java.util.Map;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    private final AuthService authService;
    private final EmailCodeService emailCodeService;

    public AuthController(AuthService authService, EmailCodeService emailCodeService) {
        this.authService = authService;
        this.emailCodeService = emailCodeService;
    }

    @PostMapping("/email/send-code")
    public Map<String, Boolean> sendEmailCode(@Valid @RequestBody EmailSendCodeRequest request) {
        emailCodeService.sendCode(request.getEmail(), request.getScene());
        return Map.of("success", true);
    }

    @PostMapping("/register")
    public AuthResultDto register(@Valid @RequestBody EmailRegisterRequest request) {
        return authService.register(request);
    }

    @PostMapping("/login")
    public AuthResultDto login(@Valid @RequestBody EmailLoginRequest request) {
        return authService.login(request);
    }

    @PostMapping("/refresh")
    public AuthResultDto refresh(@Valid @RequestBody RefreshTokenRequest request) {
        return authService.refresh(request.getRefreshToken());
    }
}

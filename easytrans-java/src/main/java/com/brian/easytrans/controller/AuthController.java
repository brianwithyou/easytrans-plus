package com.brian.easytrans.controller;

import com.brian.easytrans.dto.AuthResultDto;
import com.brian.easytrans.dto.EmailLoginRequest;
import com.brian.easytrans.dto.EmailRegisterRequest;
import com.brian.easytrans.dto.RefreshTokenRequest;
import com.brian.easytrans.service.AuthService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
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

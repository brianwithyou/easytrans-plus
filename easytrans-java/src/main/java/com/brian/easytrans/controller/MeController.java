package com.brian.easytrans.controller;

import com.brian.easytrans.dto.MeResponse;
import com.brian.easytrans.security.JwtAuthInterceptor;
import com.brian.easytrans.service.AuthService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/me")
public class MeController {

    private final AuthService authService;

    public MeController(AuthService authService) {
        this.authService = authService;
    }

    @GetMapping
    public MeResponse me(HttpServletRequest request) {
        String userId = (String) request.getAttribute(JwtAuthInterceptor.USER_ID_ATTR);
        return authService.getCurrentUser(userId);
    }
}

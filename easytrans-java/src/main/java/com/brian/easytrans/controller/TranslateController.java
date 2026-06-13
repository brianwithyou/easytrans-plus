package com.brian.easytrans.controller;

import com.brian.easytrans.dto.TranslateStreamRequest;
import com.brian.easytrans.security.JwtAuthInterceptor;
import com.brian.easytrans.service.TranslateService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

@RestController
@RequestMapping("/api/v1/translate")
public class TranslateController {

    private final TranslateService translateService;

    public TranslateController(TranslateService translateService) {
        this.translateService = translateService;
    }

    @PostMapping(value = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter stream(@Valid @RequestBody TranslateStreamRequest request, HttpServletRequest httpRequest) {
        String userId = (String) httpRequest.getAttribute(JwtAuthInterceptor.USER_ID_ATTR);
        return translateService.streamTranslate(userId, request);
    }
}

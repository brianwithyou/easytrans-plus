package com.brian.easytrans.controller;

import com.brian.easytrans.dto.DeviceReportRequest;
import com.brian.easytrans.security.JwtAuthInterceptor;
import com.brian.easytrans.service.DeviceReportService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.Map;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/device")
public class DeviceController {

    private final DeviceReportService deviceReportService;

    public DeviceController(DeviceReportService deviceReportService) {
        this.deviceReportService = deviceReportService;
    }

    @PostMapping("/report")
    public Map<String, Boolean> report(@Valid @RequestBody DeviceReportRequest request, HttpServletRequest httpRequest) {
        String userId = (String) httpRequest.getAttribute(JwtAuthInterceptor.USER_ID_ATTR);
        deviceReportService.report(userId, request);
        return Map.of("success", true);
    }
}

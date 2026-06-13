package com.brian.easytrans.security;

import com.brian.easytrans.common.BusinessException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

@Component
public class JwtAuthInterceptor implements HandlerInterceptor {

    private static final Logger log = LoggerFactory.getLogger(JwtAuthInterceptor.class);

    public static final String USER_ID_ATTR = "userId";

    private final JwtService jwtService;

    public JwtAuthInterceptor(JwtService jwtService) {
        this.jwtService = jwtService;
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        String authorization = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (authorization == null || !authorization.startsWith("Bearer ")) {
            log.warn("auth rejected path={} reason=missing_bearer_token", request.getRequestURI());
            throw new BusinessException("未登录或 token 无效", HttpStatus.UNAUTHORIZED);
        }
        String token = authorization.substring(7).trim();
        String userId = jwtService.parseAccessUserId(token);
        request.setAttribute(USER_ID_ATTR, userId);
        UserContext.setUserId(userId);
        log.debug("auth accepted userId={} path={}", userId, request.getRequestURI());
        return true;
    }

    @Override
    public void afterCompletion(
            HttpServletRequest request, HttpServletResponse response, Object handler, Exception ex) {
        UserContext.clear();
    }
}

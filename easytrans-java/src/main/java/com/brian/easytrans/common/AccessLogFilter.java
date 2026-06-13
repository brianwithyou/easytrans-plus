package com.brian.easytrans.common;

import com.brian.easytrans.security.JwtAuthInterceptor;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpMethod;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 1)
public class AccessLogFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(AccessLogFilter.class);

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return HttpMethod.OPTIONS.matches(request.getMethod());
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        long startTime = System.currentTimeMillis();
        try {
            filterChain.doFilter(request, response);
        } finally {
            logAccess(request, response, startTime);
        }
    }

    private void logAccess(HttpServletRequest request, HttpServletResponse response, long startTime) {
        long durationMs = System.currentTimeMillis() - startTime;
        Object userId = request.getAttribute(JwtAuthInterceptor.USER_ID_ATTR);
        String query = request.getQueryString();
        String path = query == null ? request.getRequestURI() : request.getRequestURI() + "?" + query;

        if (response.getStatus() >= 500) {
            log.error(
                    "access method={} path={} status={} durationMs={} userId={} clientIp={}",
                    request.getMethod(),
                    path,
                    response.getStatus(),
                    durationMs,
                    userId,
                    clientIp(request));
            return;
        }

        if (response.getStatus() >= 400) {
            log.warn(
                    "access method={} path={} status={} durationMs={} userId={} clientIp={}",
                    request.getMethod(),
                    path,
                    response.getStatus(),
                    durationMs,
                    userId,
                    clientIp(request));
            return;
        }

        log.info(
                "access method={} path={} status={} durationMs={} userId={} clientIp={}",
                request.getMethod(),
                path,
                response.getStatus(),
                durationMs,
                userId,
                clientIp(request));
    }

    private String clientIp(HttpServletRequest request) {
        String forwarded = request.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            return forwarded.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }
}

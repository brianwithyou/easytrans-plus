package com.brian.easytrans.config;

import com.brian.easytrans.security.JwtAuthInterceptor;
import java.util.Arrays;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebMvcConfig implements WebMvcConfigurer {

    private final JwtAuthInterceptor jwtAuthInterceptor;
    private final AppProperties appProperties;

    public WebMvcConfig(JwtAuthInterceptor jwtAuthInterceptor, AppProperties appProperties) {
        this.jwtAuthInterceptor = jwtAuthInterceptor;
        this.appProperties = appProperties;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(jwtAuthInterceptor)
                .addPathPatterns(
                        "/api/v1/me/**",
                        "/api/v1/translate/**",
                        "/api/v1/license/**",
                        "/api/v1/billing/checkout",
                        "/api/v1/device/**");
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        String[] origins = Arrays.stream(appProperties.getCors().getAllowedOrigins().split(","))
                .map(String::trim)
                .toArray(String[]::new);
        registry.addMapping("/api/**")
                .allowedOriginPatterns(origins)
                .allowedMethods("GET", "POST", "OPTIONS")
                .allowedHeaders("*");
    }
}

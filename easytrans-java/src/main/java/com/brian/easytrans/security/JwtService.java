package com.brian.easytrans.security;

import com.brian.easytrans.common.BusinessException;
import com.brian.easytrans.config.AppProperties;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Date;
import javax.crypto.SecretKey;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

@Service
public class JwtService {

    private static final String TOKEN_TYPE = "type";
    private static final String ACCESS = "access";
    private static final String REFRESH = "refresh";

    private final AppProperties appProperties;
    private final SecretKey secretKey;

    public JwtService(AppProperties appProperties) {
        this.appProperties = appProperties;
        this.secretKey = Keys.hmacShaKeyFor(appProperties.getJwt().getSecret().getBytes(StandardCharsets.UTF_8));
    }

    public String generateAccessToken(String userId) {
        return buildToken(userId, ACCESS, appProperties.getJwt().getExpireHours());
    }

    public String generateRefreshToken(String userId) {
        return buildToken(userId, REFRESH, appProperties.getJwt().getRefreshExpireHours());
    }

    public String parseAccessUserId(String token) {
        return parseUserId(token, ACCESS);
    }

    public String parseRefreshUserId(String token) {
        return parseUserId(token, REFRESH);
    }

    private String buildToken(String userId, String type, int expireHours) {
        Instant now = Instant.now();
        Instant expireAt = now.plus(expireHours, ChronoUnit.HOURS);
        return Jwts.builder()
                .subject(userId)
                .claim(TOKEN_TYPE, type)
                .issuedAt(Date.from(now))
                .expiration(Date.from(expireAt))
                .signWith(secretKey)
                .compact();
    }

    private String parseUserId(String token, String expectedType) {
        try {
            Claims claims = Jwts.parser()
                    .verifyWith(secretKey)
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();
            String type = claims.get(TOKEN_TYPE, String.class);
            if (!expectedType.equals(type)) {
                throw new BusinessException("登录已失效，请重新登录", HttpStatus.UNAUTHORIZED);
            }
            return claims.getSubject();
        } catch (BusinessException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new BusinessException("登录已失效，请重新登录", HttpStatus.UNAUTHORIZED);
        }
    }
}

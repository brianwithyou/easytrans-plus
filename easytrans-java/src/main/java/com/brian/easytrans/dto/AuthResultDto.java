package com.brian.easytrans.dto;

public class AuthResultDto {

    private String token;
    private String refreshToken;
    private AuthUserDto user;

    public AuthResultDto() {}

    public AuthResultDto(String token, String refreshToken, AuthUserDto user) {
        this.token = token;
        this.refreshToken = refreshToken;
        this.user = user;
    }

    public String getToken() {
        return token;
    }

    public void setToken(String token) {
        this.token = token;
    }

    public String getRefreshToken() {
        return refreshToken;
    }

    public void setRefreshToken(String refreshToken) {
        this.refreshToken = refreshToken;
    }

    public AuthUserDto getUser() {
        return user;
    }

    public void setUser(AuthUserDto user) {
        this.user = user;
    }
}

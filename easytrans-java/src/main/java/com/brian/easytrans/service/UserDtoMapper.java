package com.brian.easytrans.service;

import com.brian.easytrans.dto.AuthUserDto;
import com.brian.easytrans.dto.MeResponse;
import com.brian.easytrans.entity.AppUser;

public final class UserDtoMapper {

    private UserDtoMapper() {}

    public static AuthUserDto toAuthUserDto(AppUser user) {
        AuthUserDto dto = new AuthUserDto();
        dto.setEmail(user.getEmail());
        dto.setPlanName(user.getPlanName());
        dto.setDailyQuota(user.getDailyQuota());
        dto.setDailyUsed(user.getDailyUsed());
        return dto;
    }

    public static MeResponse toMeResponse(AppUser user) {
        MeResponse response = new MeResponse();
        response.setEmail(user.getEmail());
        response.setPlanName(user.getPlanName());
        response.setDailyQuota(user.getDailyQuota());
        response.setDailyUsed(user.getDailyUsed());
        return response;
    }
}

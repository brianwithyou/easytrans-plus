package com.brian.easytrans.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.brian.easytrans.common.DeleteFlagConstants;
import com.brian.easytrans.entity.AppUser;
import com.brian.easytrans.mapper.AppUserMapper;
import java.util.Optional;
import org.springframework.stereotype.Component;

@Component
public class AppUserDao {

    private final AppUserMapper appUserMapper;

    public AppUserDao(AppUserMapper appUserMapper) {
        this.appUserMapper = appUserMapper;
    }

    public Optional<AppUser> findByEmailAndDeleteFlag(String email, Long deleteFlag) {
        return Optional.ofNullable(appUserMapper.selectOne(new LambdaQueryWrapper<AppUser>()
                .eq(AppUser::getEmail, email)
                .eq(AppUser::getDeleteFlag, deleteFlag)));
    }

    public Optional<AppUser> findByIdAndDeleteFlag(String id, Long deleteFlag) {
        return Optional.ofNullable(appUserMapper.selectOne(new LambdaQueryWrapper<AppUser>()
                .eq(AppUser::getId, id)
                .eq(AppUser::getDeleteFlag, deleteFlag)));
    }

    public boolean existsByEmailAndDeleteFlag(String email, Long deleteFlag) {
        return appUserMapper.exists(new LambdaQueryWrapper<AppUser>()
                .eq(AppUser::getEmail, email)
                .eq(AppUser::getDeleteFlag, deleteFlag));
    }

    public void insert(AppUser user) {
        appUserMapper.insert(user);
    }

    public void update(AppUser user) {
        appUserMapper.updateById(user);
    }
}

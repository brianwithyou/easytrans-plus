package com.brian.easytrans.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.brian.easytrans.common.DeleteFlagConstants;
import com.brian.easytrans.entity.UserDeviceEntity;
import com.brian.easytrans.mapper.UserDeviceMapper;
import java.util.Optional;
import org.springframework.stereotype.Component;

@Component
public class UserDeviceDao {

    private final UserDeviceMapper userDeviceMapper;

    public UserDeviceDao(UserDeviceMapper userDeviceMapper) {
        this.userDeviceMapper = userDeviceMapper;
    }

    public Optional<UserDeviceEntity> findByUserIdAndDeviceId(String userId, String deviceId) {
        return Optional.ofNullable(userDeviceMapper.selectOne(new LambdaQueryWrapper<UserDeviceEntity>()
                .eq(UserDeviceEntity::getUserId, userId)
                .eq(UserDeviceEntity::getDeviceId, deviceId)
                .eq(UserDeviceEntity::getDeleteFlag, DeleteFlagConstants.NOT_DELETED)));
    }

    public void insert(UserDeviceEntity entity) {
        userDeviceMapper.insert(entity);
    }

    public void update(UserDeviceEntity entity) {
        userDeviceMapper.updateById(entity);
    }
}

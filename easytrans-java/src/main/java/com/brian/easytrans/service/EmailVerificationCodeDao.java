package com.brian.easytrans.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.brian.easytrans.entity.EmailVerificationCodeEntity;
import com.brian.easytrans.mapper.EmailVerificationCodeMapper;
import java.time.LocalDateTime;
import java.util.Optional;
import org.springframework.stereotype.Component;

@Component
public class EmailVerificationCodeDao {

    private final EmailVerificationCodeMapper emailVerificationCodeMapper;

    public EmailVerificationCodeDao(EmailVerificationCodeMapper emailVerificationCodeMapper) {
        this.emailVerificationCodeMapper = emailVerificationCodeMapper;
    }

    public Optional<EmailVerificationCodeEntity> findLatestValid(
            String email, String scene, Long deleteFlag, LocalDateTime now) {
        return Optional.ofNullable(emailVerificationCodeMapper.selectOne(new LambdaQueryWrapper<EmailVerificationCodeEntity>()
                .eq(EmailVerificationCodeEntity::getEmail, email)
                .eq(EmailVerificationCodeEntity::getScene, scene)
                .eq(EmailVerificationCodeEntity::getUsed, false)
                .eq(EmailVerificationCodeEntity::getDeleteFlag, deleteFlag)
                .gt(EmailVerificationCodeEntity::getExpiresAt, now)
                .orderByDesc(EmailVerificationCodeEntity::getCreateTime)
                .last("LIMIT 1")));
    }

    public Optional<EmailVerificationCodeEntity> findLatest(
            String email, String scene, Long deleteFlag) {
        return Optional.ofNullable(emailVerificationCodeMapper.selectOne(new LambdaQueryWrapper<EmailVerificationCodeEntity>()
                .eq(EmailVerificationCodeEntity::getEmail, email)
                .eq(EmailVerificationCodeEntity::getScene, scene)
                .eq(EmailVerificationCodeEntity::getDeleteFlag, deleteFlag)
                .orderByDesc(EmailVerificationCodeEntity::getCreateTime)
                .last("LIMIT 1")));
    }

    public long countSince(String email, String scene, Long deleteFlag, LocalDateTime since) {
        return emailVerificationCodeMapper.selectCount(new LambdaQueryWrapper<EmailVerificationCodeEntity>()
                .eq(EmailVerificationCodeEntity::getEmail, email)
                .eq(EmailVerificationCodeEntity::getScene, scene)
                .eq(EmailVerificationCodeEntity::getDeleteFlag, deleteFlag)
                .ge(EmailVerificationCodeEntity::getCreateTime, since));
    }

    public void insert(EmailVerificationCodeEntity entity) {
        emailVerificationCodeMapper.insert(entity);
    }

    public void update(EmailVerificationCodeEntity entity) {
        emailVerificationCodeMapper.updateById(entity);
    }
}

package com.brian.easytrans.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.brian.easytrans.entity.EmailVerificationCodeEntity;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface EmailVerificationCodeMapper extends BaseMapper<EmailVerificationCodeEntity> {}

package com.brian.easytrans.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.brian.easytrans.entity.AppUser;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface AppUserMapper extends BaseMapper<AppUser> {}

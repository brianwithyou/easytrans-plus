package com.brian.easytrans.config;

import com.baomidou.mybatisplus.core.handlers.MetaObjectHandler;
import com.brian.easytrans.common.DeleteFlagConstants;
import java.time.LocalDateTime;
import org.apache.ibatis.reflection.MetaObject;
import org.springframework.stereotype.Component;

@Component
public class MyMetaObjectHandler implements MetaObjectHandler {

    @Override
    public void insertFill(MetaObject metaObject) {
        LocalDateTime now = LocalDateTime.now();
        strictInsertFill(metaObject, "createTime", LocalDateTime.class, now);
        strictInsertFill(metaObject, "updateTime", LocalDateTime.class, now);
        strictInsertFill(metaObject, "deleteFlag", Long.class, DeleteFlagConstants.NOT_DELETED);
        strictInsertFill(metaObject, "version", Long.class, 0L);
    }

    @Override
    public void updateFill(MetaObject metaObject) {
        this.setFieldValByName("updateTime", LocalDateTime.now(), metaObject);
    }
}

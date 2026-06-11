package com.brian.easytrans.util;

import com.brian.easytrans.entity.base.BaseEntity;
import com.brian.easytrans.security.UserContext;

public final class AuditFillHelper {

    public static final String SYSTEM_OPERATOR_ID = "system";
    public static final String SYSTEM_OPERATOR_NAME = "系统";

    private AuditFillHelper() {}

    public static void fillOnCreate(BaseEntity entity) {
        fillOnCreate(entity, currentOperatorId(), currentOperatorName());
    }

    public static void fillOnCreate(BaseEntity entity, String operatorId, String operatorName) {
        entity.setCreatorId(operatorId);
        entity.setCreatorName(operatorName);
        entity.setModifierId(operatorId);
        entity.setModifierName(operatorName);
    }

    public static void fillOnUpdate(BaseEntity entity) {
        fillOnUpdate(entity, currentOperatorId(), currentOperatorName());
    }

    public static void fillOnUpdate(BaseEntity entity, String operatorId, String operatorName) {
        entity.setModifierId(operatorId);
        entity.setModifierName(operatorName);
    }

    private static String currentOperatorId() {
        String userId = UserContext.getUserId();
        return userId != null ? userId : SYSTEM_OPERATOR_ID;
    }

    private static String currentOperatorName() {
        String userId = UserContext.getUserId();
        return userId != null ? "用户" : SYSTEM_OPERATOR_NAME;
    }
}

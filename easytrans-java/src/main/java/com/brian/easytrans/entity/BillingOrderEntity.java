package com.brian.easytrans.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.brian.easytrans.entity.base.BaseEntity;

@TableName("billing_order")
public class BillingOrderEntity extends BaseEntity {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("lemon_order_id")
    private String lemonOrderId;

    @TableField("user_id")
    private String userId;

    @TableField("variant_id")
    private String variantId;

    @TableField("event_name")
    private String eventName;

    @TableField
    private String status;

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getLemonOrderId() {
        return lemonOrderId;
    }

    public void setLemonOrderId(String lemonOrderId) {
        this.lemonOrderId = lemonOrderId;
    }

    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    public String getVariantId() {
        return variantId;
    }

    public void setVariantId(String variantId) {
        this.variantId = variantId;
    }

    public String getEventName() {
        return eventName;
    }

    public void setEventName(String eventName) {
        this.eventName = eventName;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }
}

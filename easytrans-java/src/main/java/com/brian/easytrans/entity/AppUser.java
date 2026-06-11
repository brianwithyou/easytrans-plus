package com.brian.easytrans.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.brian.easytrans.entity.base.BaseEntity;
import java.time.LocalDate;

@TableName("app_user")
public class AppUser extends BaseEntity {

    @TableId(type = IdType.ASSIGN_UUID)
    private String id;

    @TableField
    private String email;

    @TableField("password_hash")
    private String passwordHash;

    @TableField
    private String nickname;

    @TableField("plan_name")
    private String planName = "标准版";

    @TableField("daily_quota")
    private Integer dailyQuota = 50000;

    @TableField("daily_used")
    private Integer dailyUsed = 0;

    @TableField("usage_reset_date")
    private LocalDate usageResetDate;

    @TableField
    private Integer status = 1;

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public void setPasswordHash(String passwordHash) {
        this.passwordHash = passwordHash;
    }

    public String getNickname() {
        return nickname;
    }

    public void setNickname(String nickname) {
        this.nickname = nickname;
    }

    public String getPlanName() {
        return planName;
    }

    public void setPlanName(String planName) {
        this.planName = planName;
    }

    public Integer getDailyQuota() {
        return dailyQuota;
    }

    public void setDailyQuota(Integer dailyQuota) {
        this.dailyQuota = dailyQuota;
    }

    public Integer getDailyUsed() {
        return dailyUsed;
    }

    public void setDailyUsed(Integer dailyUsed) {
        this.dailyUsed = dailyUsed;
    }

    public LocalDate getUsageResetDate() {
        return usageResetDate;
    }

    public void setUsageResetDate(LocalDate usageResetDate) {
        this.usageResetDate = usageResetDate;
    }

    public Integer getStatus() {
        return status;
    }

    public void setStatus(Integer status) {
        this.status = status;
    }
}

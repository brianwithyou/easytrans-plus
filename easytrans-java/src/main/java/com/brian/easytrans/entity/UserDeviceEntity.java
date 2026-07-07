package com.brian.easytrans.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.brian.easytrans.entity.base.BaseEntity;

@TableName("user_device")
public class UserDeviceEntity extends BaseEntity {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("user_id")
    private String userId;

    @TableField("device_id")
    private String deviceId;

    @TableField("os_version")
    private String osVersion;

    @TableField
    private String platform;

    @TableField
    private String architecture;

    @TableField("app_version")
    private String appVersion;

    @TableField("screen_size")
    private String screenSize;

    @TableField
    private String locale;

    @TableField
    private String timezone;

    @TableField("gpu_name")
    private String gpuName;

    @TableField("memory_bytes")
    private Long memoryBytes;

    @TableField("cpu_cores")
    private Integer cpuCores;

    @TableField("cpu_brand")
    private String cpuBrand;

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    public String getDeviceId() {
        return deviceId;
    }

    public void setDeviceId(String deviceId) {
        this.deviceId = deviceId;
    }

    public String getOsVersion() {
        return osVersion;
    }

    public void setOsVersion(String osVersion) {
        this.osVersion = osVersion;
    }

    public String getPlatform() {
        return platform;
    }

    public void setPlatform(String platform) {
        this.platform = platform;
    }

    public String getArchitecture() {
        return architecture;
    }

    public void setArchitecture(String architecture) {
        this.architecture = architecture;
    }

    public String getAppVersion() {
        return appVersion;
    }

    public void setAppVersion(String appVersion) {
        this.appVersion = appVersion;
    }

    public String getScreenSize() {
        return screenSize;
    }

    public void setScreenSize(String screenSize) {
        this.screenSize = screenSize;
    }

    public String getLocale() {
        return locale;
    }

    public void setLocale(String locale) {
        this.locale = locale;
    }

    public String getTimezone() {
        return timezone;
    }

    public void setTimezone(String timezone) {
        this.timezone = timezone;
    }

    public String getGpuName() {
        return gpuName;
    }

    public void setGpuName(String gpuName) {
        this.gpuName = gpuName;
    }

    public Long getMemoryBytes() {
        return memoryBytes;
    }

    public void setMemoryBytes(Long memoryBytes) {
        this.memoryBytes = memoryBytes;
    }

    public Integer getCpuCores() {
        return cpuCores;
    }

    public void setCpuCores(Integer cpuCores) {
        this.cpuCores = cpuCores;
    }

    public String getCpuBrand() {
        return cpuBrand;
    }

    public void setCpuBrand(String cpuBrand) {
        this.cpuBrand = cpuBrand;
    }
}

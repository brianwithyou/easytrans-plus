package com.brian.easytrans.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public class DeviceReportRequest {

    @NotBlank(message = "设备 ID 不能为空")
    @Size(max = 64, message = "设备 ID 过长")
    private String deviceId;

    @NotBlank(message = "App 版本不能为空")
    @Size(max = 32, message = "App 版本过长")
    private String appVersion;

    @Size(max = 64, message = "操作系统版本过长")
    private String osVersion;

    @Size(max = 32, message = "系统平台过长")
    private String platform;

    @Size(max = 16, message = "CPU 架构过长")
    private String architecture;

    @Size(max = 32, message = "屏幕尺寸过长")
    private String screenSize;

    @Size(max = 32, message = "默认语言过长")
    private String locale;

    @Size(max = 64, message = "时区过长")
    private String timezone;

    @Size(max = 128, message = "GPU 型号过长")
    private String gpuName;

    private Long memoryBytes;

    private Integer cpuCores;

    @Size(max = 128, message = "CPU 型号过长")
    private String cpuBrand;

    public String getDeviceId() {
        return deviceId;
    }

    public void setDeviceId(String deviceId) {
        this.deviceId = deviceId;
    }

    public String getAppVersion() {
        return appVersion;
    }

    public void setAppVersion(String appVersion) {
        this.appVersion = appVersion;
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

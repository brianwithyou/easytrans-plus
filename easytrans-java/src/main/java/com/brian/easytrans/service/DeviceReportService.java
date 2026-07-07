package com.brian.easytrans.service;

import com.brian.easytrans.dto.DeviceReportRequest;
import com.brian.easytrans.entity.UserDeviceEntity;
import com.brian.easytrans.util.AuditFillHelper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

@Service
public class DeviceReportService {

    private static final Logger log = LoggerFactory.getLogger(DeviceReportService.class);

    private final UserDeviceDao userDeviceDao;

    public DeviceReportService(UserDeviceDao userDeviceDao) {
        this.userDeviceDao = userDeviceDao;
    }

    @Transactional
    public void report(String userId, DeviceReportRequest request) {
        String deviceId = request.getDeviceId().trim();
        UserDeviceEntity entity = userDeviceDao
                .findByUserIdAndDeviceId(userId, deviceId)
                .orElseGet(UserDeviceEntity::new);

        boolean isNew = entity.getId() == null;
        entity.setUserId(userId);
        entity.setDeviceId(deviceId);
        entity.setOsVersion(trimToNull(request.getOsVersion()));
        entity.setPlatform(trimToNull(request.getPlatform()));
        entity.setArchitecture(trimToNull(request.getArchitecture()));
        entity.setAppVersion(trimToNull(request.getAppVersion()));
        entity.setScreenSize(trimToNull(request.getScreenSize()));
        entity.setLocale(trimToNull(request.getLocale()));
        entity.setTimezone(trimToNull(request.getTimezone()));
        entity.setGpuName(trimToNull(request.getGpuName()));
        entity.setMemoryBytes(request.getMemoryBytes());
        entity.setCpuCores(request.getCpuCores());
        entity.setCpuBrand(trimToNull(request.getCpuBrand()));

        if (isNew) {
            AuditFillHelper.fillOnCreate(entity, userId, "用户");
            userDeviceDao.insert(entity);
            log.info(
                    "device report created userId={} deviceId={} appVersion={} platform={} architecture={}",
                    userId,
                    deviceId,
                    entity.getAppVersion(),
                    entity.getPlatform(),
                    entity.getArchitecture());
            return;
        }

        AuditFillHelper.fillOnUpdate(entity, userId, "用户");
        userDeviceDao.update(entity);
        log.info(
                "device report updated userId={} deviceId={} appVersion={} platform={} architecture={}",
                userId,
                deviceId,
                entity.getAppVersion(),
                entity.getPlatform(),
                entity.getArchitecture());
    }

    private String trimToNull(String value) {
        if (!StringUtils.hasText(value)) {
            return null;
        }
        return value.trim();
    }
}

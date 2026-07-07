-- 用户设备信息表（已有库升级用；新库也会由 01_schema.sql 创建）
USE easytrans;

CREATE TABLE IF NOT EXISTS `user_device` (
    `id`              BIGINT       NOT NULL AUTO_INCREMENT,
    `user_id`         VARCHAR(36)  NOT NULL COMMENT '用户ID',
    `device_id`       VARCHAR(64)  NOT NULL COMMENT '客户端设备ID',
    `os_version`      VARCHAR(64)  NULL COMMENT '操作系统版本',
    `platform`        VARCHAR(32)  NULL COMMENT '系统平台',
    `architecture`    VARCHAR(16)  NULL COMMENT 'CPU 架构',
    `app_version`     VARCHAR(32)  NULL COMMENT 'App 版本',
    `screen_size`     VARCHAR(32)  NULL COMMENT '主屏分辨率',
    `locale`          VARCHAR(32)  NULL COMMENT '默认语言',
    `timezone`        VARCHAR(64)  NULL COMMENT '时区',
    `gpu_name`        VARCHAR(128) NULL COMMENT 'GPU 型号',
    `memory_bytes`    BIGINT       NULL COMMENT '物理内存字节数',
    `cpu_cores`       INT          NULL COMMENT 'CPU 核心数',
    `cpu_brand`       VARCHAR(128) NULL COMMENT 'CPU 型号',
    `delete_flag`     BIGINT       NOT NULL DEFAULT 0 COMMENT '删除标记: 0未删除',
    `create_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `version`         BIGINT       NOT NULL DEFAULT 0 COMMENT '乐观锁版本',
    `creator_id`      VARCHAR(36)  NULL COMMENT '创建人ID',
    `modifier_id`     VARCHAR(36)  NULL COMMENT '修改人ID',
    `creator_name`    VARCHAR(64)  NULL COMMENT '创建人名称',
    `modifier_name`   VARCHAR(64)  NULL COMMENT '修改人名称',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_device` (`user_id`, `device_id`, `delete_flag`),
    KEY `idx_user_update` (`user_id`, `update_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户设备信息';

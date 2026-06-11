-- EasyTrans Pro 数据库建表脚本 (MySQL 8.0+)

USE easytrans;

CREATE TABLE IF NOT EXISTS `app_user` (
    `id`                VARCHAR(36)  NOT NULL COMMENT '用户ID (UUID)',
    `email`             VARCHAR(128) NOT NULL COMMENT '邮箱',
    `password_hash`     VARCHAR(100) NOT NULL COMMENT 'BCrypt 密码哈希',
    `nickname`          VARCHAR(64)  NULL COMMENT '昵称',
    `plan_name`         VARCHAR(64)  NOT NULL DEFAULT '标准版' COMMENT '套餐名称',
    `daily_quota`       INT          NOT NULL DEFAULT 50000 COMMENT '每日字符配额',
    `daily_used`        INT          NOT NULL DEFAULT 0 COMMENT '今日已用字符数',
    `usage_reset_date`  DATE         NULL COMMENT '用量重置日期',
    `status`            TINYINT      NOT NULL DEFAULT 1 COMMENT '1=正常 0=禁用',
    `delete_flag`       BIGINT       NOT NULL DEFAULT 0 COMMENT '删除标记: 0未删除',
    `create_time`       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time`       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `version`           BIGINT       NOT NULL DEFAULT 0 COMMENT '乐观锁版本',
    `creator_id`        VARCHAR(36)  NULL COMMENT '创建人ID',
    `modifier_id`       VARCHAR(36)  NULL COMMENT '修改人ID',
    `creator_name`      VARCHAR(64)  NULL COMMENT '创建人名称',
    `modifier_name`     VARCHAR(64)  NULL COMMENT '修改人名称',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_email` (`email`, `delete_flag`),
    KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户';

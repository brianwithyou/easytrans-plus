-- EasyTrans Pro 数据库建表脚本 (MySQL 8.0+)

USE easytrans;

CREATE TABLE IF NOT EXISTS `app_user` (
    `id`                VARCHAR(36)  NOT NULL COMMENT '用户ID (UUID)',
    `email`             VARCHAR(128) NOT NULL COMMENT '邮箱',
    `password_hash`     VARCHAR(100) NOT NULL COMMENT 'BCrypt 密码哈希',
    `nickname`          VARCHAR(64)  NULL COMMENT '昵称',
    `plan_name`         VARCHAR(64)  NOT NULL DEFAULT '基础版' COMMENT '套餐名称',
    `daily_quota`       INT          NOT NULL DEFAULT 50000 COMMENT '每日字符配额',
    `daily_used`        INT          NOT NULL DEFAULT 0 COMMENT '今日已用字符数',
    `usage_reset_date`  DATE         NULL COMMENT '用量重置日期',
    `plan_expires_at`   DATETIME     NULL COMMENT '付费套餐到期时间（billing.enabled=true 时生效）',
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

CREATE TABLE IF NOT EXISTS `email_verification_code` (
    `id`            BIGINT       NOT NULL AUTO_INCREMENT,
    `email`         VARCHAR(128) NOT NULL COMMENT '邮箱',
    `code`          VARCHAR(10)  NOT NULL COMMENT '验证码',
    `scene`         VARCHAR(32)  NOT NULL COMMENT '场景: register',
    `expires_at`    DATETIME     NOT NULL COMMENT '过期时间',
    `used`          TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '是否已使用',
    `delete_flag`   BIGINT       NOT NULL DEFAULT 0 COMMENT '删除标记: 0未删除',
    `create_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `version`       BIGINT       NOT NULL DEFAULT 0 COMMENT '乐观锁版本',
    `creator_id`    VARCHAR(36)  NULL COMMENT '创建人ID',
    `modifier_id`   VARCHAR(36)  NULL COMMENT '修改人ID',
    `creator_name`  VARCHAR(64)  NULL COMMENT '创建人名称',
    `modifier_name` VARCHAR(64)  NULL COMMENT '修改人名称',
    PRIMARY KEY (`id`),
    KEY `idx_email_scene_create` (`email`, `scene`, `create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='邮箱验证码';

CREATE TABLE IF NOT EXISTS `translation_event` (
    `id`                BIGINT       NOT NULL AUTO_INCREMENT,
    `user_id`           VARCHAR(36)  NOT NULL COMMENT '用户ID',
    `request_id`        VARCHAR(64)  NULL COMMENT '服务端请求ID (X-Request-Id)',
    `client_request_id` VARCHAR(64)  NULL COMMENT '客户端请求ID',
    `source_lang`       VARCHAR(16)  NOT NULL COMMENT '源语言',
    `target_lang`       VARCHAR(16)  NOT NULL COMMENT '目标语言',
    `style`             VARCHAR(32)  NOT NULL COMMENT '翻译风格',
    `input_chars`       INT          NOT NULL COMMENT '输入字符数',
    `output_chars`      INT          NULL COMMENT '输出字符数',
    `duration_ms`       BIGINT       NOT NULL COMMENT '耗时毫秒',
    `status`            VARCHAR(32)  NOT NULL COMMENT 'success / failed / quota_exceeded',
    `error_message`     VARCHAR(512) NULL COMMENT '失败原因（不含正文）',
    `delete_flag`       BIGINT       NOT NULL DEFAULT 0 COMMENT '删除标记: 0未删除',
    `create_time`       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time`       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `version`           BIGINT       NOT NULL DEFAULT 0 COMMENT '乐观锁版本',
    `creator_id`        VARCHAR(36)  NULL COMMENT '创建人ID',
    `modifier_id`       VARCHAR(36)  NULL COMMENT '修改人ID',
    `creator_name`      VARCHAR(64)  NULL COMMENT '创建人名称',
    `modifier_name`     VARCHAR(64)  NULL COMMENT '修改人名称',
    PRIMARY KEY (`id`),
    KEY `idx_user_create` (`user_id`, `create_time`),
    KEY `idx_create_time` (`create_time`),
    KEY `idx_status_create` (`status`, `create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='翻译请求元数据事件';

CREATE TABLE IF NOT EXISTS `billing_order` (
    `id`              BIGINT       NOT NULL AUTO_INCREMENT,
    `lemon_order_id`  VARCHAR(64)  NOT NULL COMMENT 'Lemon Squeezy order id',
    `user_id`         VARCHAR(36)  NOT NULL COMMENT '用户ID',
    `variant_id`      VARCHAR(32)  NULL COMMENT 'Lemon variant id',
    `event_name`      VARCHAR(64)  NOT NULL COMMENT 'webhook event',
    `status`          VARCHAR(32)  NOT NULL COMMENT 'paid / refunded',
    `delete_flag`     BIGINT       NOT NULL DEFAULT 0 COMMENT '删除标记: 0未删除',
    `create_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `update_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `version`         BIGINT       NOT NULL DEFAULT 0 COMMENT '乐观锁版本',
    `creator_id`      VARCHAR(36)  NULL COMMENT '创建人ID',
    `modifier_id`     VARCHAR(36)  NULL COMMENT '修改人ID',
    `creator_name`    VARCHAR(64)  NULL COMMENT '创建人名称',
    `modifier_name`   VARCHAR(64)  NULL COMMENT '修改人名称',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_lemon_order_event` (`lemon_order_id`, `event_name`),
    KEY `idx_user_create` (`user_id`, `create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Lemon Squeezy 订单记录';

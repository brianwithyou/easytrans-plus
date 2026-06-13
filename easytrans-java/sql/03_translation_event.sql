-- 翻译请求元数据事件表（已有库升级用；新库也会由 01_schema.sql 创建）
USE easytrans;

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

-- 邮箱验证码表（已有库升级用；新库也会由 01_schema.sql 创建）
USE easytrans;

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

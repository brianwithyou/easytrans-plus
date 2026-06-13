-- Lemon Squeezy 计费（已有库升级用；新库也会由 01_schema.sql 创建）

USE easytrans;

ALTER TABLE `app_user`
    ADD COLUMN `plan_expires_at` DATETIME NULL COMMENT '付费套餐到期时间（billing.enabled=true 时生效）' AFTER `usage_reset_date`;

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

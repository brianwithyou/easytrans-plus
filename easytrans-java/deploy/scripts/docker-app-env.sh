#!/usr/bin/env bash
# 供 deploy-prebuilt.sh / deploy-docker.sh 共用：把 .env 中的应用配置传给 docker run
# 用法：source 本文件后调用 append_docker_app_env RUN_ARGS

append_docker_app_env() {
  local -n _run_args=$1

  _run_args+=(
    -e "SPRING_PROFILES_ACTIVE=prod"
    -e "TZ=Asia/Shanghai"
    -e "JWT_SECRET=${JWT_SECRET}"
    -e "MYSQL_USERNAME=${MYSQL_USERNAME:-root}"
    -e "MYSQL_PASSWORD=${MYSQL_PASSWORD}"
    -e "SPRING_DATASOURCE_URL=${DATASOURCE_URL}"
    -e "DASHSCOPE_API_KEY=${DASHSCOPE_API_KEY:-}"
    -e "MIMO_API_KEY=${MIMO_API_KEY:-}"
    -e "DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY:-}"
    -e "EMAIL_DEV_MODE=${EMAIL_DEV_MODE:-false}"
    -e "RESEND_API_KEY=${RESEND_API_KEY:-}"
    -e "RESEND_FROM=${RESEND_FROM:-}"
    -e "APP_CORS_ALLOWED_ORIGINS=${APP_CORS_ALLOWED_ORIGINS:-*}"
    -e "BILLING_ENABLED=${BILLING_ENABLED:-false}"
    -e "LEMON_SQUEEZY_WEBHOOK_SECRET=${LEMON_SQUEEZY_WEBHOOK_SECRET:-}"
    -e "BILLING_ALLOW_TEST_MODE=${BILLING_ALLOW_TEST_MODE:-true}"
    -e "BILLING_VARIANT_ID=${BILLING_VARIANT_ID:-}"
    -e "BILLING_PLAN_NAME=${BILLING_PLAN_NAME:-基础版}"
    -e "BILLING_DAILY_QUOTA=${BILLING_DAILY_QUOTA:-500000}"
    -e "BILLING_DURATION_DAYS=${BILLING_DURATION_DAYS:-30}"
    -e "BILLING_PRODUCT_LABEL=${BILLING_PRODUCT_LABEL:-基础版（1个月）}"
    -e "BILLING_CHECKOUT_URL=${BILLING_CHECKOUT_URL:-}"
  )
}

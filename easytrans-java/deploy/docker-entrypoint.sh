#!/bin/sh
set -e

# 挂载卷会覆盖镜像内目录权限，启动前确保日志目录可写
mkdir -p /app/logs
chown -R easytrans:easytrans /app/logs

exec gosu easytrans java -jar /app/app.jar "$@"

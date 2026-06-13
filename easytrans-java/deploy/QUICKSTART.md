# EasyTrans Plus 后端部署（CentOS + 已有 MySQL 8）

按顺序执行，不要跳步。

---

## 架构

```
Mac 客户端  →  HTTPS  →  Nginx（可选）  →  easytrans-api:9091  →  已有 MySQL 8
```

---

## 第一步：服务器准备

```bash
# 1. 安装 Docker
curl -fsSL https://get.docker.com | sh
systemctl enable docker && systemctl start docker

# 2. 配置 Docker 镜像加速（国内必做）
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": ["https://mirror.ccs.tencentyun.com"]
}
EOF
systemctl restart docker

# 3. 安装 Git
yum install -y git

# 4. 配置 GitHub SSH（Deploy Key），然后克隆
cd /opt
git clone git@github.com:brianwithyou/easytrans-plus.git
```

---

## 第二步：初始化 MySQL（只需一次）

```bash
# 查看 MySQL 容器名
docker ps | grep -i mysql

# 导入表结构（把 <mysql容器名> 和密码换成你的）
docker exec -i <mysql容器名> mysql -uroot -p你的密码 < /opt/easytrans-plus/easytrans-java/sql/01_schema.sql

# 确认库已创建
docker exec -i <mysql容器名> mysql -uroot -p你的密码 -e "SHOW DATABASES LIKE 'easytrans';"
```

---

## 第三步：配置 deploy/.env

```bash
cd /opt/easytrans-plus/easytrans-java/deploy
cp .env.example .env
vi .env
```

**必填内容示例：**

```env
API_PORT=9091

# 连接本机已有 MySQL（CentOS 7 推荐这样配）
USE_HOST_NETWORK=true
MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
MYSQL_DATABASE=easytrans
MYSQL_USERNAME=root
MYSQL_PASSWORD=你的MySQL密码

# 至少 32 位随机字符串
JWT_SECRET=用 openssl rand -base64 48 生成

# LLM 至少填一个
DASHSCOPE_API_KEY=sk-xxx
MIMO_API_KEY=
DEEPSEEK_API_KEY=

# 日志落到宿主机（推荐）
LOG_HOST_PATH=/var/log/easytrans
```

生成 JWT：

```bash
openssl rand -base64 48
```

---

## 第四步：一键构建并部署

```bash
cd /opt/easytrans-plus/easytrans-java/deploy
chmod +x scripts/*.sh
./scripts/deploy-server.sh
```

这条命令会：
1. 在服务器用 Docker + Maven（JDK 25）编译 JAR
2. 构建 API 运行时镜像
3. 启动 `easytrans-api` 容器

**第一次构建约 10～20 分钟**（下载 Maven 依赖），属正常。

成功标志：

```bash
curl http://127.0.0.1:9091/api/v1/health
# {"status":"ok"}
```

---

## 第五步：配置 HTTPS（对外服务必做）

```bash
yum install -y nginx certbot python3-certbot-nginx

# 复制并修改域名
cp nginx/easytrans-api.conf.example /etc/nginx/conf.d/easytrans-api.conf
vi /etc/nginx/conf.d/easytrans-api.conf   # 改 api.example.com

nginx -t && systemctl reload nginx
certbot --nginx -d api.example.com
```

防火墙只开放 **22、80、443**，不要对公网开放 9091。

---

## 第六步：配置 Mac 客户端

1. 打开 **EasyTrans Plus → 设置**
2. 翻译通道：**云端服务**
3. API 地址：`https://api.example.com`（你的域名，不要末尾 `/`）
4. 注册 → 登录 → 测试翻译

---

## 日常运维命令

```bash
cd /opt/easytrans-plus/easytrans-java/deploy

# 拉代码 + 重新构建部署
git pull origin main
./scripts/deploy-server.sh

# 仅重启（未改代码时）
./scripts/restart.sh

# 查看日志
docker logs -f easytrans-api
tail -f /var/log/easytrans/easytrans.log

# 诊断
./scripts/diagnose.sh
```

---

## 常见问题

| 现象 | 处理 |
|------|------|
| 构建很慢 | 第一次下载 Maven 依赖，等 10～20 分钟 |
| 健康检查超时 | `docker logs easytrans-api --tail 50` 看报错 |
| MySQL 连不上 | `.env` 设 `USE_HOST_NETWORK=true` + `MYSQL_HOST=127.0.0.1` |
| 未找到 JAR | 先跑 `./scripts/build-jar-on-server.sh` |
| 日志目录报错 Permission denied | `chown -R 10001:10001 /var/log/easytrans` 后重新部署；或 `git pull` 用最新 entrypoint |

---

## 脚本说明（只需记住一个）

| 你想做什么 | 命令 |
|------------|------|
| **首次部署 / 更新代码后部署** | `./scripts/deploy-server.sh` |
| 只重启 | `./scripts/restart.sh` |
| 只看日志 | `docker logs -f easytrans-api` |

其他脚本（`deploy-docker.sh`、`deploy-prebuilt.sh`）是备选，**日常用 `deploy-server.sh` 即可**。

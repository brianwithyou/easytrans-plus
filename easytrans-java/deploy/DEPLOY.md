# EasyTrans Plus 后端部署指南

本文说明如何将 `easytrans-java` 部署到你的 Linux 服务器，并让 macOS 客户端通过「云端服务」连接。

## 架构

```
macOS 客户端 (EasyTrans Plus)
        │ HTTPS
        ▼
   Nginx (可选，推荐)
        │
        ▼
   easytrans-api :9091  (Docker)
        │
        ▼
   已有 MySQL 8 容器 / 宿主机 3306
```

---

## 一、服务器要求

| 项目 | 建议 |
|------|------|
| 系统 | Ubuntu 22.04+ / Debian 12+ / 其他支持 Docker 的 Linux |
| 配置 | 2 核 CPU、2GB+ 内存、20GB+ 磁盘 |
| 软件 | Docker 24+、Docker Compose v2 |
| 网络 | 开放 80/443（Nginx）；9091 可仅内网访问 |
| 域名 | 建议 `api.yourdomain.com` + HTTPS |

---

## 二、快速部署（Docker，推荐）

### 1. 安装 Docker（如未安装）

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"
# 重新登录 SSH 后再继续
```

### 2. 上传代码到服务器

```bash
# 本地
cd easytrans-plus
git archive --format=tar HEAD easytrans-java | ssh user@your-server 'mkdir -p ~/easytrans-plus && tar -x -C ~/easytrans-plus'

# 或在服务器上 git clone
git clone <your-repo-url> ~/easytrans-plus
```

### 3. 配置环境变量

```bash
cd ~/easytrans-plus/easytrans-java/deploy
cp .env.example .env
nano .env
```

必填项：

| 变量 | 说明 |
|------|------|
| `MYSQL_PASSWORD` | 你的 MySQL 8 密码 |
| `MYSQL_HOST` | 默认 `host.docker.internal`（MySQL 映射到宿主机 3306 时） |
| `JWT_SECRET` | JWT 密钥，至少 32 位随机字符串 |
| `DASHSCOPE_API_KEY` / `MIMO_API_KEY` / `DEEPSEEK_API_KEY` | 至少填一个 LLM Key |

### 3.1 使用本机已有 MySQL 8 容器

**方式 A（最常见）**：MySQL 容器已 `-p 3306:3306` 映射到宿主机

`.env` 保持：

```env
MYSQL_HOST=host.docker.internal
MYSQL_PORT=3306
MYSQL_DATABASE=easytrans
MYSQL_USERNAME=root
MYSQL_PASSWORD=你的mysql密码
```

在 MySQL 中创建库并导入表结构（只需一次）：

```bash
# 若宿主机有 mysql 客户端
mysql -h 127.0.0.1 -P 3306 -uroot -p < ../sql/01_schema.sql

# 或进入你的 MySQL 容器
docker exec -i <mysql容器名> mysql -uroot -p你的密码 < ../sql/01_schema.sql
```

**方式 B**：API 与 MySQL 在同一 Docker 网络（未映射宿主机端口时）

```bash
# 查看 MySQL 容器名和网络
docker ps
docker inspect <mysql容器名> --format '{{json .NetworkSettings.Networks}}'

# .env 增加：
# MYSQL_HOST=<mysql容器名>
# MYSQL_PORT=3306
# MYSQL_DOCKER_NETWORK=<网络名>

docker compose -f docker-compose.yml -f docker-compose.mysql-network.yml up -d --build
```

生成随机 JWT：

```bash
openssl rand -base64 48
```

### 4. 一键部署

```bash
chmod +x scripts/*.sh
./scripts/deploy.sh
```

成功后可访问：

```bash
curl http://127.0.0.1:9091/api/v1/health
# {"status":"ok"}
```

### 5. 常用运维命令

```bash
cd ~/easytrans-plus/easytrans-java/deploy

./scripts/logs.sh          # 查看 API 日志
./scripts/update.sh        # 重新构建并更新
docker compose ps          # 查看状态
docker compose down        # 停止服务
```

---

## 三、配置 HTTPS（生产必做）

macOS 客户端应使用 `https://` 地址，不要用明文 HTTP 公网暴露。

```bash
sudo apt install -y nginx certbot python3-certbot-nginx
sudo cp nginx/easytrans-api.conf.example /etc/nginx/sites-available/easytrans-api
sudo ln -s /etc/nginx/sites-available/easytrans-api /etc/nginx/sites-enabled/
# 编辑 server_name 为你的域名
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d api.yourdomain.com
```

防火墙示例：

```bash
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw enable
# 9091 不要对公网开放，只给本机 Nginx 用
```

---

## 四、配置 macOS 客户端

1. 打开 **EasyTrans Plus → 设置**
2. 翻译通道选 **云端服务**
3. **API 地址** 填：`https://api.yourdomain.com`（不要带末尾 `/`）
4. 注册账号 → 登录 → 测试翻译

> 默认地址 `http://127.0.0.1:9091` 仅适合本机开发。

---

## 五、部署后自检清单

```bash
# 1. 健康检查
curl https://api.yourdomain.com/api/v1/health

# 2. 注册
curl -X POST https://api.yourdomain.com/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@example.com","password":"test123456"}'

# 3. 登录
curl -X POST https://api.yourdomain.com/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@example.com","password":"test123456"}'
```

在客户端用同一账号登录，执行一次主窗口翻译和 `⌘⇧D` 快捷翻译。

---

## 六、你还需要做的其他事情

### 必做（上线前）

- [ ] 修改 `deploy/.env` 中所有默认密码和密钥
- [ ] 配置域名 + HTTPS（Let's Encrypt）
- [ ] 至少配置一个 LLM API Key
- [ ] 客户端 `云端服务 API 地址` 指向你的 HTTPS 域名
- [ ] 云服务器安全组：只开放 22、80、443

### 强烈建议

- [ ] 定期备份 MySQL：`docker exec easytrans-mysql mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" easytrans > backup.sql`
- [ ] 设置 `APP_CORS_ALLOWED_ORIGINS`（若未来有 Web 端）
- [ ] 监控磁盘和内存；日志在容器内 stdout，可用 `docker compose logs`
- [ ] 限制开放注册（当前任何人可注册）——可临时靠不公开注册页，或后续加邀请码

### 可选（商业版完善）

- [ ] 移除客户端中尚未实现的 **License 激活** UI
- [ ] 管理后台（用户封禁、改配额）
- [ ] 支付 / 套餐系统
- [ ] CI 自动构建镜像

---

## 七、故障排查

| 现象 | 排查 |
|------|------|
| `deploy.sh` 超时 | `docker compose logs api`，常见原因：MySQL 未就绪、JWT_SECRET 未设置 |
| 客户端连不上 | 检查域名、HTTPS 证书、安全组 443 |
| 翻译失败 | 检查 LLM API Key；`docker compose logs api` 看兜底日志 |
| 401 未登录 | 客户端重新登录；检查服务器时间是否同步 |
| 429 额度用尽 | 默认每日 50000 字符，可在数据库 `app_user.daily_quota` 调整 |

---

## 八、非 Docker 部署（可选）

若不想用 Docker，需自行安装 **Java 25**、**MySQL 8**，然后：

```bash
cd easytrans-java
cp src/main/resources/application-example.yaml src/main/resources/application-local.yaml
# 编辑 application-local.yaml
mvn -DskipTests package
java -jar target/easytrans-java-0.0.1-SNAPSHOT.jar
```

仍需执行 `sql/01_schema.sql` 初始化数据库。

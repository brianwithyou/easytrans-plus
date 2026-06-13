# EasyTrans Plus 部署与发布文档

本文档涵盖 macOS 客户端的开发环境、本地构建、**Release 发布**，以及后端配合说明。

## 目录

- [开发环境](#开发环境)
- [本地构建](#本地构建)
- [发布 Release](#发布-release)
- [代码签名与公证](#代码签名与公证)
- [后端配合发布](#后端配合发布)
- [辅助功能与开发构建](#辅助功能与开发构建)
- [故障排查](#故障排查)

---

## 开发环境

### 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | macOS 13.0+ |
| Xcode | 15.0+ |
| 账号 | 云端服务账号（应用内登录）；Apple Developer 账号（对外分发时） |

### 打开项目

```bash
cd easytrans-plus/easytrans-swift
open EasyTrans.xcodeproj
```

| 属性 | 值 |
|------|-----|
| Scheme | `EasyTrans` |
| 应用名称 | EasyTrans Plus |
| Bundle ID | `com.easytrans.pro` |
| 最低系统版本 | macOS 13.0 |
| 内置云端 API | `https://api.normalblog.cn`（见 `AppSettings.builtInCloudBaseURL`） |

---

## 本地构建

### 从 Xcode

1. 选择 Scheme **EasyTrans**，目标 **My Mac**
2. `⌘ + R`：Debug；`Product → Archive`：用于签名分发

构建产物输出到项目目录（便于辅助功能授权路径稳定）：

```
build/Debug/EasyTrans Plus.app
build/Release/EasyTrans Plus.app
```

### 命令行

```bash
cd easytrans-plus/easytrans-swift

# Release 构建（发布用）
xcodebuild \
  -scheme EasyTrans \
  -configuration Release \
  -destination 'platform=macOS' \
  clean build

# 验证产物
ls -la "build/Release/EasyTrans Plus.app"
open "build/Release/EasyTrans Plus.app"
```

### 本机安装

```bash
cp -R "build/Release/EasyTrans Plus.app" /Applications/
```

首次运行若被 Gatekeeper 拦截：Finder 中右键应用 → **打开**。

---

## 发布 Release

完整发布流程分为：**发布前检查 → 改版本号 → Release 构建 → 本地验证 → 打包 → 签名/公证（可选）→ 打标签 → 上传 GitHub Release**。

### 1. 发布前检查

在改版本号、打标签之前确认：

- [ ] **功能自测通过**：菜单栏、翻译快捷键、剪贴板历史、登录/注册、设置页快捷键自定义
- [ ] **后端已部署且可用**（若本次包含 API 变更）：见 [后端配合发布](#后端配合发布)
- [ ] **内置 API 地址正确**：`EasyTrans/Models/AppSettings.swift` 中 `builtInCloudBaseURL` 指向线上环境
- [ ] **无开发向残留**：设置页无调试路径、无测试提示文案
- [ ] **无敏感信息**：代码与配置中无 API Key、JWT、数据库密码等硬编码
- [ ] **`.gitignore` 已忽略 `build/`**，不会把构建产物提交进仓库

### 2. 修改版本号

在 Xcode 中打开 **EasyTrans** target → **General**：

| 字段 | 说明 | 示例 |
|------|------|------|
| **Version**（`MARKETING_VERSION`） | 用户可见版本号 | `1.0.0` |
| **Build**（`CURRENT_PROJECT_VERSION`） | 构建号，每次发布递增 | `2` |

也可直接改 `EasyTrans.xcodeproj/project.pbxproj` 中的 `MARKETING_VERSION` 与 `CURRENT_PROJECT_VERSION`（Debug / Release 两处保持一致）。

版本号与 Git 标签建议对齐，例如 Version `1.0.0` 对应标签 `v1.0.0`。

### 3. Release 构建

```bash
cd easytrans-plus/easytrans-swift

xcodebuild \
  -scheme EasyTrans \
  -configuration Release \
  -destination 'platform=macOS' \
  clean build
```

成功后在：

```
build/Release/EasyTrans Plus.app
```

### 4. 发布前本地验证

在**未签名**的 Release 包上做一次完整冒烟测试（建议先复制到 `/Applications/` 再测）：

1. 完全退出旧版本（菜单栏 → 退出，或活动监视器中结束进程）
2. 打开新构建的 `EasyTrans Plus.app`
3. 在 **系统设置 → 隐私与安全性 → 辅助功能** 中确认已授权（路径变化时需重新添加）
4. 验证：
   - 菜单栏图标与菜单项正常
   - **打开主窗口**、翻译快捷键、剪贴板历史快捷键
   - 登录 / 注册（邮箱验证码）
   - 翻译流程与结果展示
   - Dock 中**不**出现图标（`LSUIElement` 菜单栏应用）

### 5. 打包分发文件

将版本号代入 `VERSION`（与 `MARKETING_VERSION` 一致，如 `1.0.0`）。

#### 方式 A：ZIP（简单，适合内测）

```bash
cd easytrans-plus/easytrans-swift/build/Release

ditto -c -k --sequesterRsrc --keepParent \
  "EasyTrans Plus.app" \
  "EasyTrans-Plus-${VERSION}-macOS.zip"
```

#### 方式 B：DMG（适合对外发布）

```bash
cd easytrans-plus/easytrans-swift

VERSION=1.0.0   # 改成当前版本

hdiutil create \
  -volname "EasyTrans Plus" \
  -srcfolder "build/Release/EasyTrans Plus.app" \
  -ov -format UDZO \
  "EasyTrans-Plus-${VERSION}-macOS.dmg"
```

产物示例：`EasyTrans-Plus-1.0.0-macOS.dmg`

### 6. 代码签名与公证（对外分发时必做）

仅本机使用可跳过；分发给其他用户或上传公开 Release 时，需要 **Developer ID** 签名 + **公证（Notarization）**，否则对方 Mac 会拦截运行。

详见下一节 [代码签名与公证](#代码签名与公证)。完成后再执行第 7 步上传。

### 7. 提交代码并打 Git 标签

```bash
cd easytrans-plus   # 或你的 monorepo 根目录

git add -A
git commit -m "release: EasyTrans Plus v1.0.0"
git tag -a v1.0.0 -m "EasyTrans Plus 1.0.0"
git push origin main
git push origin v1.0.0
```

> 若客户端与后端在同一仓库，确保本次 release 对应的后端代码也已部署到线上。

### 8. 创建 GitHub Release

1. 打开 GitHub 仓库 → **Releases** → **Draft a new release**
2. **Choose a tag**：选择 `v1.0.0`（或新建同名标签）
3. **Release title**：例如 `EasyTrans Plus 1.0.0`
4. **说明**（建议包含）：
   - 新功能与修复摘要
   - 系统要求：macOS 13.0+
   - 安装方式：下载 DMG/ZIP → 拖入「应用程序」→ 首次右键「打开」
   - 辅助功能授权说明（全局快捷键依赖）
5. **上传附件**：`EasyTrans-Plus-1.0.0-macOS.dmg` 或 `.zip`
6. 发布 **Publish release**

### 9. 发布后验证

- [ ] 从 Release 页下载安装包，在**另一台 Mac** 或新用户账号下安装测试（若已公证）
- [ ] 确认能连接 `https://api.normalblog.cn` 并完成登录、翻译
- [ ] 检查 Release 附件与标签版本一致

### 发布流程速查

```bash
# 1. 改 Xcode 中 Version / Build
# 2. 构建
cd easytrans-plus/easytrans-swift
xcodebuild -scheme EasyTrans -configuration Release -destination 'platform=macOS' clean build

# 3. 本地测试 build/Release/EasyTrans Plus.app

# 4. 打包（二选一）
VERSION=1.0.0
cd build/Release && ditto -c -k --sequesterRsrc --keepParent "EasyTrans Plus.app" "EasyTrans-Plus-${VERSION}-macOS.zip"

# 5. （可选）签名 + 公证 DMG/ZIP

# 6. 打标签并推送
git tag -a v1.0.0 -m "EasyTrans Plus 1.0.0" && git push origin v1.0.0

# 7. GitHub Releases 页面上传并发布
```

---

## 代码签名与公证

需要 [Apple Developer Program](https://developer.apple.com/programs/) 会员资格。

### 在 Xcode 中配置

1. **Signing & Capabilities** → Team 选择你的开发者团队
2. Release 配置使用 **Developer ID Application** 证书（分发到 App Store 外）
3. 或使用 `Product → Archive` → **Distribute App** → **Developer ID** 向导导出已签名应用

### 命令行签名与公证（示例）

将 `VERSION`、`TEAM_ID`、证书名称、Apple ID 替换为实际值。

```bash
cd easytrans-plus/easytrans-swift
VERSION=1.0.0
APP="build/Release/EasyTrans Plus.app"
DMG="EasyTrans-Plus-${VERSION}-macOS.dmg"

# 1. 签名 .app
codesign --deep --force --options runtime --timestamp \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  "$APP"

codesign --verify --verbose "$APP"

# 2. 制作 DMG（若尚未制作）
hdiutil create -volname "EasyTrans Plus" -srcfolder "$APP" -ov -format UDZO "$DMG"

# 3. 提交公证
xcrun notarytool submit "$DMG" \
  --apple-id "your@email.com" \
  --team-id "TEAM_ID" \
  --password "app-specific-password" \
  --wait

# 4. 装订公证票据
xcrun stapler staple "$DMG"
```

`app-specific-password` 在 [appleid.apple.com](https://appleid.apple.com) → 登录与安全 → App 专用密码 中生成。

上传 GitHub Release 的应为**已签名且已公证**的 DMG 或 ZIP。

---

## 后端配合发布

客户端内置云端地址为 `https://api.normalblog.cn`。若本次发布依赖后端 API 变更，需**先部署后端，再发布客户端**。

后端部署文档：`easytrans-java/deploy/DEPLOY.md`（日常更新执行 `deploy-server.sh`）。

建议顺序：

1. 在服务器上部署/更新 `easytrans-java` API
2. 用 curl 或 Postman 验证注册、登录、翻译接口
3. 再构建并发布 macOS 客户端 Release

仅客户端 UI 或本地逻辑变更、且 API 兼容时，可单独发客户端 Release。

---

## 辅助功能与开发构建

全局快捷键依赖**辅助功能**权限。

| 构建方式 | 应用路径 | 授权稳定性 |
|----------|----------|------------|
| 项目内固定输出 | `easytrans-swift/build/Debug/EasyTrans Plus.app` | 高 |
| Xcode DerivedData 默认路径 | `~/Library/Developer/Xcode/DerivedData/...` | 低，路径易变 |

**推荐开发流程：**

1. Xcode `⌘R` 构建运行
2. 将 `build/Debug/EasyTrans Plus.app` 加入 **系统设置 → 隐私与安全性 → 辅助功能**
3. `⌘Q` 完全退出后重新打开

本地数据目录：

```
~/Library/Application Support/com.easytrans.pro/
```

---

## 故障排查

### `xcodebuild: error: Unable to find a destination`

确认已安装完整 Xcode：

```bash
xcode-select -p
# 应输出 /Applications/Xcode.app/Contents/Developer
```

### 构建成功但无法运行（本机开发）

```bash
xattr -cr "build/Release/EasyTrans Plus.app"
```

### 用户下载后提示「已损坏」或无法打开

- 未签名/未公证：需完成 [代码签名与公证](#代码签名与公证)
- 或让用户：系统设置 → 隐私与安全性 → 仍要打开

### 快捷键不生效

1. 确认辅助功能已授权**当前正在运行的** `.app` 路径
2. 菜单栏查看「快捷键状态」
3. Release 包测试前建议完全退出再启动

### 无法连接云端

1. 确认 `AppSettings.builtInCloudBaseURL` 与线上一致
2. 检查服务器 API 与 Nginx/HTTPS 是否正常
3. 参考 `easytrans-java/deploy/DEPLOY.md` 查看容器日志

# EasyTrans 部署文档

本文档涵盖开发环境搭建、本地构建、发布打包，以及将项目上传到 GitHub 的完整流程。

## 目录

- [开发环境](#开发环境)
- [从 Xcode 构建](#从-xcode-构建)
- [命令行构建](#命令行构建)
- [安装与分发](#安装与分发)
- [发布 Release（可选）](#发布-release可选)
- [上传到 GitHub](#上传到-github)
- [代码签名说明](#代码签名说明)
- [辅助功能与开发构建](#辅助功能与开发构建)
- [环境变量与密钥管理](#环境变量与密钥管理)

---

## 开发环境

### 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | macOS 13.0+ |
| Xcode | 15.0+（从 App Store 或开发者网站安装完整版） |
| Swift | 随 Xcode 自带（项目使用 SwiftUI） |
| 账号 | 阿里云 DashScope API Key（运行时配置，非构建依赖） |

### 克隆项目

```bash
git clone https://github.com/<your-username>/easytrans.git
cd easytrans
```

### 打开项目

```bash
open EasyTrans.xcodeproj
```

项目信息：

| 属性 | 值 |
|------|-----|
| Scheme | `EasyTrans` |
| Bundle ID | `com.easytrans.app` |
| 最低系统版本 | macOS 13.0 |
| 版本号 | 1.0 |

---

## 从 Xcode 构建

1. 在 Xcode 中选择 Scheme **EasyTrans**
2. 选择目标 **My Mac**
3. 按 `⌘ + R` 运行 Debug 构建，或 `⌘ + Shift + R` 运行 Release 构建

项目已配置将构建产物输出到项目目录：

```
build/Debug/EasyTrans.app    # Debug
build/Release/EasyTrans.app  # Release
```

固定输出路径有助于辅助功能授权在开发期间保持稳定（详见 [辅助功能与开发构建](#辅助功能与开发构建)）。

---

## 命令行构建

### Debug 构建

```bash
cd easytrans
xcodebuild \
  -scheme EasyTrans \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

### Release 构建

```bash
xcodebuild \
  -scheme EasyTrans \
  -configuration Release \
  -destination 'platform=macOS' \
  build
```

### 清理构建缓存

```bash
xcodebuild -scheme EasyTrans -configuration Release clean
rm -rf build/
```

### 构建产物位置

成功构建后，应用位于：

```
build/Release/EasyTrans.app
```

可用以下命令验证：

```bash
ls -la build/Release/EasyTrans.app
open build/Release/EasyTrans.app
```

---

## 安装与分发

### 本机安装

将 `EasyTrans.app` 拖入「应用程序」文件夹：

```bash
cp -R build/Release/EasyTrans.app /Applications/
```

首次运行若被 Gatekeeper 拦截：

1. 在 Finder 中右键点击 `EasyTrans.app`
2. 选择「打开」→ 确认打开

或在「系统设置 → 隐私与安全性」中允许该应用运行。

### 分发给他人

未签名的 `.app` 在其他 Mac 上可能无法直接运行。可选方案：

| 方案 | 适用场景 |
|------|----------|
| 提供源码 + 构建说明 | 开发者用户 |
| Ad Hoc / Developer ID 签名 | 小范围分发 |
| 公证（Notarization）+ DMG | 公开发布 |

---

## 发布 Release（可选）

### 创建 DMG（简易方式）

```bash
# 确保已有 Release 构建
hdiutil create \
  -volname "EasyTrans" \
  -srcfolder build/Release/EasyTrans.app \
  -ov -format UDZO \
  EasyTrans-1.0.dmg
```

### GitHub Release 流程

1. 打标签：

```bash
git tag -a v1.0.0 -m "EasyTrans 1.0.0"
git push origin v1.0.0
```

2. 在 GitHub 仓库页面 → **Releases → Draft a new release**
3. 选择标签 `v1.0.0`，上传 `EasyTrans-1.0.dmg` 或 `EasyTrans.app.zip`
4. 填写更新说明

---

## 上传到 GitHub

### 1. 检查 .gitignore

项目已忽略以下内容，确认无误后再提交：

```
.DS_Store
build/
DerivedData/
*.xcuserstate
xcuserdata/
```

> `build/` 目录不应提交。用户需自行构建或从 Release 下载。

### 2. 确认无敏感信息

**上传前务必检查：**

- [ ] 代码中无硬编码的 API Key、Token 或密码
- [ ] `AppSettings.swift` 中 API Key 默认值为空字符串
- [ ] 无个人路径、内网地址等敏感配置
- [ ] 剪贴板历史、UserDefaults 等本地数据未纳入版本控制

### 3. 初始化仓库并推送

```bash
cd easytrans

# 若尚未初始化 git
git init
git add .
git commit -m "Initial commit: EasyTrans macOS translation app"

# 在 GitHub 创建空仓库后
git remote add origin https://github.com/<your-username>/easytrans.git
git branch -M main
git push -u origin main
```

### 4. 建议的仓库说明

在 GitHub 仓库 Settings 中可填写：

- **Description**: macOS menu bar translation app powered by Alibaba DashScope Qwen
- **Topics**: `macos`, `swift`, `swiftui`, `translation`, `dashscope`, `qwen`

### 5. 推荐仓库文件结构

```
easytrans/
├── .gitignore
├── README.md
├── docs/
│   ├── USAGE.md
│   └── DEPLOYMENT.md
├── EasyTrans.xcodeproj/
└── EasyTrans/
```

可选补充：`LICENSE`（如 MIT）、`CONTRIBUTING.md`、GitHub Actions CI（macOS 构建验证）。

---

## 代码签名说明

### 个人开发 / 本机使用

Xcode 默认使用「Sign to Run Locally」，无需 Apple Developer 账号，仅能在本机运行。

### 分发给其他用户

需要 [Apple Developer Program](https://developer.apple.com/programs/) 会员资格：

1. 在 Xcode → **Signing & Capabilities** 中选择 Team
2. 使用 **Developer ID Application** 证书签名
3. 通过 `notarytool` 提交公证：

```bash
# 示例：签名并公证（需替换证书名称与 Apple ID）
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  build/Release/EasyTrans.app

xcrun notarytool submit EasyTrans-1.0.dmg \
  --apple-id "your@email.com" \
  --team-id "TEAM_ID" \
  --password "app-specific-password" \
  --wait

xcrun stapler staple EasyTrans-1.0.dmg
```

### Entitlements

当前应用使用辅助功能（Accessibility）读取选中文字与模拟按键，用户需在系统设置中手动授权，无需在 entitlements 中声明额外权限。

---

## 辅助功能与开发构建

全局快捷键（`⌘⇧D`、`⌘⇧V`）依赖辅助功能权限。

| 构建方式 | 应用路径 | 授权稳定性 |
|----------|----------|------------|
| Xcode `⌘R`（项目已配置） | `easytrans/build/Debug/EasyTrans.app` | 高，路径固定 |
| DerivedData 默认输出 | `~/Library/Developer/Xcode/DerivedData/...` | 低，每次编译路径可能变化 |

**推荐开发流程：**

1. 使用 Xcode `⌘R` 构建并运行
2. 设置页 →「在 Finder 中显示应用」
3. 将 `EasyTrans.app` 拖入「系统设置 → 隐私与安全性 → 辅助功能」
4. `⌘Q` 完全退出后重新打开

授权后菜单栏「快捷键状态」应至少显示一项 ✓。

---

## 环境变量与密钥管理

EasyTrans **不在构建时**注入 API Key。用户在应用设置页运行时填写，保存在：

```
~/Library/Preferences/com.easytrans.app.plist  # UserDefaults
```

### 开发者注意事项

- 不要将 API Key 写入源码、配置文件或 Git 历史
- 若曾误提交密钥，立即在 DashScope 控制台轮换 Key，并使用 `git filter-repo` 或 BFG 清理历史
- CI 环境如需自动化测试，通过 Xcode Scheme 环境变量或本地未提交的 `xcconfig` 注入，并加入 `.gitignore`

### DashScope 端点

| 区域 | Base URL |
|------|----------|
| 中国大陆 | `https://dashscope.aliyuncs.com/compatible-mode/v1` |
| 国际 | `https://dashscope-intl.aliyuncs.com/compatible-mode/v1` |

---

## 故障排查（构建相关）

### `xcodebuild: error: Unable to find a destination`

确认已安装完整 Xcode（非仅 Command Line Tools）：

```bash
xcode-select -p
# 应输出 /Applications/Xcode.app/Contents/Developer
```

### 构建成功但无法运行

```bash
# 查看是否被隔离
xattr -l build/Release/EasyTrans.app

# 移除隔离属性（仅本机开发）
xattr -cr build/Release/EasyTrans.app
```

### Swift 编译错误

确保 Xcode 版本 ≥ 15，macOS 部署目标为 13.0：

```bash
xcodebuild -showBuildSettings -scheme EasyTrans | grep MACOSX_DEPLOYMENT_TARGET
```

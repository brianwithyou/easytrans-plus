# EasyTrans Plus

EasyTrans 商业版，基于开源版 [easytrans](https://github.com/brianwithyou/easytrans)  fork 开发。

macOS 菜单栏翻译工具，通过阿里云 DashScope 调用通义千问（Qwen）模型，支持主窗口翻译、全局快捷键翻译与剪贴板历史管理。

## 与开源版的区别

| 项目 | 开源版 (`easytrans`) | 商业版 (`easytrans-pro`) |
|------|----------------------|--------------------------|
| 目录 | `easytrans/` | `easytrans-pro/` |
| 应用名称 | EasyTrans | EasyTrans Plus |
| Bundle ID | `com.easytrans.app` | `com.easytrans.pro` |
| 数据目录 | `~/Library/Application Support/com.easytrans.app/` | `~/Library/Application Support/com.easytrans.pro/` |
| Git 仓库 | 独立开源仓库 | 独立商业仓库（私有） |

两个版本可同时安装在本机，配置与剪贴板历史互不影响。

## 环境要求

- macOS 13.0+
- Xcode 15+
- 阿里云 [DashScope API Key](https://dashscope.console.aliyun.com/apiKey)

## 快速开始

```bash
cd easytrans-pro
open EasyTrans.xcodeproj
```

在 Xcode 中按 `⌘ + R` 运行，打开 **EasyTrans Plus → Settings…**（`⌘ + ,`）配置 API Key。

命令行构建：

```bash
xcodebuild -scheme EasyTrans -configuration Release -destination 'platform=macOS' build
```

产物：`build/Release/EasyTrans.app`（显示名称为 EasyTrans Plus）

## 文档

- [使用文档](docs/USAGE.md)
- [部署文档](docs/DEPLOYMENT.md)

> 文档内容基于开源版，部分路径与名称请以商业版 README 为准。

## License

商业版专有代码，未经授权不得分发。

# 🦐 飞秋 FeiQiu - macOS 版

兼容 IPMSG / Windows 飞秋 / 飞鸽传书协议的 macOS 局域网即时通讯工具。

## ✨ 特性

- ✅ **兼容 IPMSG 协议** — 与 Windows 飞秋、飞鸽传书互通
- ✅ **局域网自动发现** — 同网段用户自动上线
- ✅ **实时聊天** — 消息收发 + 送达/已读回执
- ✅ **文件传输** — 选择/拖拽/截图发送 + 进度跟踪
- ✅ **群发消息** — 一键群发给所有在线用户
- ✅ **聊天记录持久化** — 关闭重启不丢消息
- ✅ **macOS 原生** — SwiftUI 三栏布局 + 菜单栏图标
- ✅ **UTF-8/GBK 双编码** — 兼容老版飞秋
- ✅ **暗黑模式** — 自动适配系统主题

## 📸 界面预览

三栏布局：左侧用户列表（搜索+群发） | 右侧聊天窗口（气泡+附件）

## 🚀 快速开始

### 环境要求

- macOS 13.0 (Ventura)+
- Xcode 14.0+
- XcodeGen

### 一键构建

```bash
# 克隆仓库
git clone https://github.com/你的用户名/FeiQiu.git
cd FeiQiu

# 生成 Xcode 项目
brew install xcodegen
xcodegen generate

# 打开并运行
open FeiQiu.xcodeproj
```

> 📖 详细步骤见 [BUILD_GUIDE.md](BUILD_GUIDE.md)

### DMG 打包

```bash
./scripts/build.sh
```

## 📡 协议兼容

| 协议 | 兼容性 |
|------|--------|
| IPMSG v1 (标准) | ✅ 完全兼容 |
| 飞鸽传书 (IPMsg) | ✅ 兼容 |
| 飞秋 (FeiQiu) | ✅ 基本兼容 |
| 飞秋私有扩展 | ⏳ 部分支持（开发中） |

端口: UDP/TCP 2425 | 编码: UTF-8 + GBK fallback

## 🛠️ 开发状态

| 功能 | 状态 |
|------|------|
| IPMSG 协议引擎 | ✅ 完成 |
| UDP 用户发现/消息 | ✅ 完成 |
| TCP 文件传输 | ✅ 完成 |
| macOS 原生 UI | ✅ 完成 |
| 文件拖拽发送 | ✅ 完成 |
| 聊天记录持久化 | ✅ 完成 |
| 群发消息 | ✅ 完成 |
| AppIcon | ✅ 完成 |
| DMG 打包脚本 | ✅ 完成 |
| GitHub Actions CI | ✅ 完成 |
| 暗黑模式适配 | ✅ 完成 |
| 图片内联预览 | ⏳ 开发中 |
| 文件夹传输 | ⏳ 开发中 |
| 消息加密 | ⏳ 开发中 |
| 飞秋私有扩展 | 📋 计划中 |

## 📁 项目结构

```
FeiQiu/
├── FeiQiu-macOS/
│   ├── FeiQiuApp.swift           App 入口 + 菜单栏
│   ├── Info.plist
│   ├── Models/
│   │   ├── IPMSGCommand.swift    IPMSG 命令字/选项
│   │   ├── IPMSGMessage.swift    消息编解码
│   │   └── User.swift            用户/消息/传输模型
│   ├── Services/
│   │   ├── UDPService.swift      UDP 通讯 (BSD Socket)
│   │   ├── TCPFileService.swift  TCP 文件传输
│   │   ├── FileSharingService.swift 文件发送/下载
│   │   ├── ChatHistoryStore.swift   聊天记录持久化
│   │   └── FeiQiuManager.swift   业务管理器
│   ├── Views/
│   │   ├── MainWindow.swift      三栏布局 + 群发
│   │   ├── ChatView.swift        聊天气泡 + 附件
│   │   ├── TransferListView.swift 传输管理
│   │   └── SettingsView.swift    设置
│   ├── Utilities/
│   │   └── NetworkInterface.swift
│   └── Assets.xcassets/          AppIcon
├── FeiQiuTests/
├── scripts/build.sh              构建脚本
├── .github/workflows/            CI/CD
├── project.yml                   XcodeGen 配置
└── BUILD_GUIDE.md                编译指南
```

## 🧪 测试

1. Mac 和 Windows 连同一 WiFi
2. Windows 打开飞秋
3. Mac 启动飞秋 → 用户列表显示 Windows 用户
4. 互发消息 / 互传文件

## 📜 License

MIT

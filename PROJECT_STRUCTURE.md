# 🚀 FeiQiu-iOS 项目结构说明

## 📁 目录结构

```
FeiQiu-iOS/
├── README.md
├── PROJECT_STRUCTURE.md       (本文件)
├── FeiQiu/                    主项目代码
│   ├── FeiQiuApp.swift        App 入口 + TabView
│   ├── Info.plist             权限/Bonjour/网络配置
│   │
│   ├── Models/                数据模型层
│   │   ├── IPMSGCommand.swift IPMSG 命令字定义
│   │   ├── IPMSGMessage.swift IPMSG 消息编解码
│   │   └── User.swift         用户/聊天消息/传输任务
│   │
│   ├── Services/              业务服务层
│   │   ├── UDPService.swift   UDP 广播/单播 (用户发现+消息)
│   │   ├── TCPFileService.swift TCP 文件传输
│   │   └── FeiQiuManager.swift 业务管理器 (协调所有服务)
│   │
│   ├── Views/                 SwiftUI 界面
│   │   ├── UserListView.swift 用户列表
│   │   ├── ChatView.swift     聊天界面
│   │   ├── TransferListView.swift 传输任务
│   │   └── SettingsView.swift 设置
│   │
│   ├── ViewModels/            (预留)
│   ├── Utilities/             工具类
│   │   └── NetworkInterface.swift 网络接口/IP 获取
│   └── Assets/                (待补充: AppIcon, Colors)
│
└── FeiQiuTests/               单元测试 (待补充)
```

## 🔧 在 Xcode 中创建项目

由于在 Linux 环境下无法直接生成 `.xcodeproj`，需要在 Mac 上按以下步骤集成：

### 方法 1：手动创建 Xcode 项目（推荐）

```bash
# 1. 在 Mac 上打开 Xcode
# 2. File → New → Project
# 3. 选择 iOS → App
# 4. 配置:
#    Product Name: FeiQiu
#    Interface: SwiftUI
#    Language: Swift
#    Minimum Deployment: iOS 15.0
#    Bundle Identifier: com.yourname.feiqiu
# 5. 删除自动生成的 ContentView.swift、FeiQiuApp.swift
# 6. 将本仓库的 FeiQiu/ 目录全部文件拖入 Xcode 项目
# 7. 替换 Info.plist
# 8. 编译运行
```

### 方法 2：用 XcodeGen 自动生成（更稳定）

```bash
# 安装 XcodeGen
brew install xcodegen

# 在项目根目录执行
cd FeiQiu-iOS
xcodegen generate

# 然后打开生成的 FeiQiu.xcodeproj
open FeiQiu.xcodeproj
```

> 💡 我已经准备了 `project.yml` 配置文件，详见下文。

## ⚙️ 关键配置项

### 1. Info.plist 必备权限

- `NSLocalNetworkUsageDescription` — 本地网络使用说明（iOS 14+ 强制要求）
- `NSBonjourServices` — 声明 IPMSG Bonjour 服务
- `NSAppTransportSecurity.NSAllowsLocalNetworking` — 允许局域网通信

### 2. Build Settings

- **iOS Deployment Target**: 15.0+
- **Swift Language Version**: 5.7+
- **Enable Bitcode**: No

## 🧪 本地测试

1. **同网段测试**:
   - iPhone 和 Windows 电脑连同一 WiFi
   - Windows 打开飞秋
   - iPhone 启动 App → 用户列表应显示 Windows 用户
   - 互相发消息

2. **iOS 模拟器测试**:
   - 模拟器使用 Mac 的网络
   - 同样可以和局域网内其他飞秋互通

## 🐛 已知限制

1. **iOS 后台限制**: App 退至后台后 UDP 监听会被挂起，无法实时收消息
2. **编码兼容性**: 当前默认 UTF-8，部分旧版飞秋可能用 GBK，已做 fallback
3. **大文件传输**: 当前无断点续传
4. **群聊未实现**: Phase 3 计划

## 📚 下一步开发

- [ ] 完善文件发送 UI（选择文件 + 发送）
- [ ] 文件下载实现（接收方下载流程）
- [ ] 头像支持
- [ ] 消息加密
- [ ] 飞秋私有协议扩展（截图、表情等）

## 🔗 相关协议参考

- IP Messenger 协议: https://ipmsg.org/protocol.html
- 飞秋是国人在 IPMSG 基础上的扩展版本

# 🦐 FeiQiu-macOS

macOS 版飞秋 — 兼容 IPMSG / 飞鸽传书协议的局域网即时通讯工具。

可与 Windows 飞秋、飞鸽传书互通！

## ✨ 特性

- ✅ 兼容 IP Messenger 协议，可与 Windows 飞秋、飞鸽传书互通
- ✅ 局域网用户自动发现
- ✅ 实时聊天消息收发 + 送达/已读回执
- ✅ 文件传输（TCP）
- ✅ macOS 原生界面（SwiftUI）
- ✅ 菜单栏常驻图标
- ✅ 后台持续运行（无 iOS 后台限制）
- ✅ UTF-8 / GBK 双编码兼容
- ✅ 支持 macOS 13+

## 🏗️ 架构

```
┌───────────────────────────────────┐
│        SwiftUI macOS 界面          │
│  三栏布局 / 菜单栏 / 聊天气泡       │
├───────────────────────────────────┤
│         FeiQiuManager             │
│  用户列表 / 聊天历史 / 消息确认     │
├──────────────┬────────────────────┤
│  UDP Service │  TCP File Service  │
│ BSD Socket   │  NWConnection      │
│ 广播/消息收发 │  文件传输           │
└──────────────┴────────────────────┘
```

## 📡 协议规范

兼容 IPMSG v2 协议：

- **端口**: UDP/TCP 2425
- **消息格式**: `版本号:包序号:用户名:主机名:命令字:附加数据`
- **字符编码**: UTF-8（优先） / GBK（fallback）

### 主要命令字

| 命令字 | 名称 | 说明 |
|--------|------|------|
| `0x00000001` | BR_ENTRY | 上线广播 |
| `0x00000002` | BR_EXIT | 下线通知 |
| `0x00000003` | ANSENTRY | 应答上线 |
| `0x00000020` | SENDMSG | 发送消息 |
| `0x00000021` | RECVMSG | 消息接收确认 |
| `0x00000030` | READMSG | 已读通知 |
| `0x00000060` | GETFILEDATA | 请求文件数据 |

## 🛠️ 快速开始

### 环境要求

- macOS 13.0+
- Xcode 14.0+
- Swift 5.7+

### 方式 1：XcodeGen（推荐）

```bash
# 安装 XcodeGen
brew install xcodegen

# 生成 Xcode 项目
cd FeiQiu-macOS
xcodegen generate

# 打开并运行
open FeiQiu.xcodeproj
```

### 方式 2：手动创建

1. Xcode → File → New → Project → macOS → App
2. Interface: SwiftUI, Language: Swift
3. 删除自动生成文件，拖入 `FeiQiu-macOS/` 目录
4. 替换 Info.plist
5. 编译运行

## 🎯 使用方法

1. **启动飞秋** — 自动广播上线，发现同网段用户
2. **选择用户** — 左侧用户列表点击
3. **发送消息** — 右侧聊天窗口输入，`Cmd+Enter` 发送
4. **传文件** — 点击📎按钮选择文件（开发中）
5. **菜单栏** — 右上角气泡图标，快速访问

## 🧪 测试

1. Mac 和 Windows 连同一 WiFi
2. Windows 打开飞秋
3. Mac 启动飞秋 → 用户列表显示 Windows 用户
4. 互相发消息 / 传文件

## 🛠️ 开发计划

- [x] **Phase 0**: 项目骨架 & 协议引擎
- [x] **Phase 1**: macOS 原生界面 + UDP 通讯 + 用户发现
- [ ] **Phase 2**: 文件传输 UI + 完整收发流程
- [ ] **Phase 3**: 群组聊天、截图、图片消息
- [ ] **Phase 4**: 飞秋私有协议扩展

## 📁 项目结构

```
FeiQiu-macOS/
├── FeiQiuApp.swift           App 入口 + 菜单栏
├── Info.plist                权限配置
├── Models/
│   ├── IPMSGCommand.swift    命令字定义
│   ├── IPMSGMessage.swift    消息编解码
│   └── User.swift            用户/消息模型
├── Services/
│   ├── UDPService.swift      UDP 通讯 (BSD Socket)
│   ├── TCPFileService.swift  TCP 文件传输
│   └── FeiQiuManager.swift   业务管理器
├── Views/
│   ├── MainWindow.swift      三栏布局 + 侧边栏
│   ├── ChatView.swift        聊天界面
│   ├── TransferListView.swift 传输列表
│   └── SettingsView.swift    设置
└── Utilities/
    └── NetworkInterface.swift 网络接口
```

## 📜 License

MIT

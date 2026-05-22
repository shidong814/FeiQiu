# 🦐 FeiQiu-iOS

iOS 版飞秋（FeiQiu）— 兼容 IPMSG / 飞鸽传书协议的局域网即时通讯工具。

## ✨ 特性

- ✅ 兼容 IP Messenger 协议，可与 Windows 飞秋、飞鸽传书互通
- ✅ 局域网用户自动发现
- ✅ 实时聊天消息收发
- ✅ 文件传输（TCP）
- ✅ SwiftUI 现代界面
- ✅ 支持 iOS 15+

## 🏗️ 架构

```
┌─────────────────────────────┐
│         SwiftUI UI 层        │
│  用户列表 / 聊天 / 文件传输   │
├─────────────────────────────┤
│        ViewModel 层          │
│  ChatVM / UserListVM / FileVM│
├─────────────────────────────┤
│       IPMSG 协议引擎         │
│  UDP广播 / TCP传输 / 编解码  │
├─────────────────────────────┤
│     Network.framework        │
│  NWConnection / NWListener   │
└─────────────────────────────┘
```

## 📡 协议规范

兼容 IPMSG v2 协议：

- **端口**: UDP/TCP 2425
- **消息格式**: `版本号:包序号:用户名:主机名:命令字:附加数据`
- **字符编码**: GBK（兼容 Windows 客户端）/ UTF-8

### 主要命令字

| 命令字 | 名称 | 说明 |
|--------|------|------|
| `0x00000001` | NOOPERATION | 无操作 |
| `0x00000002` | BR_ENTRY | 上线广播 |
| `0x00000003` | BR_EXIT | 下线通知 |
| `0x00000004` | ANSENTRY | 应答上线 |
| `0x00000005` | BR_ABSENCE | 状态变更 |
| `0x00000020` | SENDMSG | 发送消息 |
| `0x00000021` | RECVMSG | 消息接收确认 |
| `0x00000060` | GETINFO | 获取版本信息 |
| `0x00000061` | SENDINFO | 应答版本信息 |
| `0x00000040` | READMSG | 已读通知 |
| `0x00000050` | GETFILEDATA | 请求文件数据 |
| `0x00000051` | RELEASEFILES | 释放文件 |

### 消息选项标志位（命令字高 16 位）

- `0x00000010` SENDCHECKOPT — 需要确认
- `0x00000020` SECRETOPT — 密文/封装消息
- `0x00000100` BROADCASTOPT — 广播消息
- `0x00000200` MULTICASTOPT — 多播消息
- `0x00100000` FILEATTACHOPT — 附件文件
- `0x00200000` ENCRYPTOPT — 加密

## 🛠️ 开发计划

- [x] **Phase 0**: 项目骨架 & 协议引擎设计
- [ ] **Phase 1**: UDP 通讯 + 用户发现 + 文本消息
- [ ] **Phase 2**: TCP 文件传输
- [ ] **Phase 3**: 群组、表情、图片消息
- [ ] **Phase 4**: 飞秋私有协议扩展

## 📱 系统要求

- iOS 15.0+
- Xcode 14.0+
- Swift 5.7+

## 📄 协议参考

- [IP Messenger 官方协议](https://ipmsg.org/protocol.html)
- 飞秋协议（飞鸽 IPMSG 扩展）

## 📜 License

MIT

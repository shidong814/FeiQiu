import Foundation

// MARK: - 用户模型

/// 局域网用户
class LANUser: Identifiable, ObservableObject {
    let id = UUID()
    
    @Published var name: String           // 用户名
    @Published var host: String           // 主机名
    @Published var ipAddress: String      // IP 地址
    @Published var port: UInt16           // 端口
    @Published var groupName: String      // 组名/部门
    @Published var status: UserStatus     // 在线状态
    @Published var lastSeen: Date         // 最后在线时间
    @Published var absenceMessage: String?// 离开消息
    @Published var version: String?       // 客户端版本
    @Published var avatarData: Data?      // 头像数据
    
    init(name: String, host: String, ipAddress: String, port: UInt16 = 2425) {
        self.name = name
        self.host = host
        self.ipAddress = ipAddress
        self.port = port
        self.groupName = ""
        self.status = .online
        self.lastSeen = Date()
    }
    
    /// 从 IPMSG BR_ENTRY 消息创建用户
    convenience init(from message: IPMSGMessage, ipAddress: String) {
        // 附加数据格式: 用户名\0组名\0...
        // 有些客户端格式: 用户名\0组名\0主机名\0...
        let parts = message.additionalData.split(separator: "\0", omittingEmptySubsequences: false)
        
        let displayName = parts.count > 0 ? String(parts[0]) : message.senderName
        let group = parts.count > 1 ? String(parts[1]) : ""
        
        self.init(
            name: displayName.isEmpty ? message.senderName : displayName,
            host: message.senderHost,
            ipAddress: ipAddress,
            port: 2425
        )
        self.groupName = group
    }
    
    /// 更新用户信息
    func update(from message: IPMSGMessage) {
        let parts = message.additionalData.split(separator: "\0", omittingEmptySubsequences: false)
        
        if parts.count > 0 && !parts[0].isEmpty {
            name = String(parts[0])
        }
        if parts.count > 1 {
            groupName = String(parts[1])
        }
        lastSeen = Date()
    }
    
    var displayName: String {
        if !groupName.isEmpty {
            return "\(name)(\(groupName))"
        }
        return name
    }
}

// MARK: - 用户状态

enum UserStatus: Int {
    case online = 0       // 在线
    case away = 1         // 离开
    case busy = 2         // 忙碌
    case doNotDisturb = 3 // 请勿打扰
    case offline = 4      // 离线
    
    var localizedString: String {
        switch self {
        case .online: return "在线"
        case .away: return "离开"
        case .busy: return "忙碌"
        case .doNotDisturb: return "请勿打扰"
        case .offline: return "离线"
        }
    }
    
    var systemImage: String {
        switch self {
        case .online: return "circle.fill"
        case .away: return "moon.fill"
        case .busy: return "clock.fill"
        case .doNotDisturb: return "bell.slash.fill"
        case .offline: return "circle"
        }
    }
    
    var tintColor: String {
        switch self {
        case .online: return "green"
        case .away: return "yellow"
        case .busy: return "orange"
        case .doNotDisturb: return "red"
        case .offline: return "gray"
        }
    }
}

// MARK: - 聊天消息

enum ChatMessageDirection {
    case sent      // 发出的
    case received  // 收到的
}

enum ChatMessageType {
    case text           // 纯文本
    case image          // 图片
    case file           // 文件
    case folder         // 文件夹
}

class ChatMessage: Identifiable {
    let id = UUID()
    let packetNo: UInt32           // IPMSG 包序号
    let sender: LANUser?           // 发送者
    let direction: ChatMessageDirection
    let type: ChatMessageType
    let content: String            // 消息内容
    let timestamp: Date
    var isRead: Bool
    var isConfirmed: Bool          // 对方是否确认收到
    var attachments: [IPMSGFileAttachment]? // 附件列表
    
    init(packetNo: UInt32, sender: LANUser?, direction: ChatMessageDirection,
         type: ChatMessageType = .text, content: String, isRead: Bool = false) {
        self.packetNo = packetNo
        self.sender = sender
        self.direction = direction
        self.type = type
        self.content = content
        self.timestamp = Date()
        self.isRead = isRead
        self.isConfirmed = false
    }
}

// MARK: - 文件传输任务

enum FileTransferState {
    case waiting       // 等待中
    case transferring  // 传输中
    case paused        // 已暂停
    case completed     // 已完成
    case failed        // 失败
    case cancelled     // 已取消
}

class FileTransferTask: Identifiable, ObservableObject {
    let id = UUID()
    let fileName: String
    let fileSize: UInt64
    let direction: ChatMessageDirection
    let remoteIP: String
    let remotePort: UInt16
    
    @Published var state: FileTransferState = .waiting
    @Published var transferredSize: UInt64 = 0
    @Published var speed: Double = 0  // bytes/sec
    
    var progress: Double {
        guard fileSize > 0 else { return 0 }
        return Double(transferredSize) / Double(fileSize)
    }
    
    var formattedSpeed: String {
        ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file) + "/s"
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
    
    var formattedTransferred: String {
        ByteCountFormatter.string(fromByteCount: Int64(transferredSize), countStyle: .file)
    }
    
    init(fileName: String, fileSize: UInt64, direction: ChatMessageDirection,
         remoteIP: String, remotePort: UInt16 = 2425) {
        self.fileName = fileName
        self.fileSize = fileSize
        self.direction = direction
        self.remoteIP = remoteIP
        self.remotePort = remotePort
    }
}

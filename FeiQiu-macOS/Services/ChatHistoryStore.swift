import Foundation

// MARK: - 聊天历史持久化

/// 聊天记录持久化管理器
/// 将聊天记录保存到本地文件，重启后自动恢复
class ChatHistoryStore {
    
    static let shared = ChatHistoryStore()
    
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.feiqiu.history", qos: .utility)
    
    // 存储目录
    private var storeDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("FeiQiu/ChatHistory")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    // 用户信息目录
    private var usersFile: URL {
        storeDirectory.appendingPathComponent("users.json")
    }
    
    private init() {}
    
    // MARK: - 保存聊天记录
    
    /// 保存指定用户的聊天记录
    func saveMessages(for ipAddress: String, messages: [ChatMessage]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let file = self.storeDirectory.appendingPathComponent("\(ipAddress.replacingOccurrences(of: ".", with: "_")).json")
            
            let dtos = messages.map { MessageDTO(from: $0) }
            
            do {
                let data = try JSONEncoder().encode(dtos)
                try data.write(to: file, options: .atomic)
            } catch {
                print("保存聊天记录失败: \(error)")
            }
        }
    }
    
    /// 保存所有聊天记录
    func saveAllHistory(_ history: [String: [ChatMessage]]) {
        for (ip, msgs) in history {
            saveMessages(for: ip, messages: msgs)
        }
    }
    
    // MARK: - 加载聊天记录
    
    /// 加载指定用户的聊天记录
    func loadMessages(for ipAddress: String) -> [ChatMessage] {
        let file = storeDirectory.appendingPathComponent("\(ipAddress.replacingOccurrences(of: ".", with: "_")).json")
        
        guard let data = try? Data(contentsOf: file) else { return [] }
        
        do {
            let dtos = try JSONDecoder().decode([MessageDTO].self, from: data)
            return dtos.map { $0.toChatMessage() }
        } catch {
            print("加载聊天记录失败: \(error)")
            return []
        }
    }
    
    /// 加载所有聊天记录
    func loadAllHistory() -> [String: [ChatMessage]] {
        var history: [String: [ChatMessage]] = [:]
        
        guard let files = try? fileManager.contentsOfDirectory(at: storeDirectory, includingPropertiesForKeys: nil) else {
            return history
        }
        
        for file in files where file.pathExtension == "json" && file.lastPathComponent != "users.json" {
            let ipWithUnderscores = file.deletingPathExtension().lastPathComponent
            let ipAddress = ipWithUnderscores.replacingOccurrences(of: "_", with: ".")
            
            guard let data = try? Data(contentsOf: file) else { continue }
            
            do {
                let dtos = try JSONDecoder().decode([MessageDTO].self, from: data)
                history[ipAddress] = dtos.map { $0.toChatMessage() }
            } catch {
                print("加载 \(ipAddress) 聊天记录失败: \(error)")
            }
        }
        
        return history
    }
    
    // MARK: - 清理
    
    /// 清除所有聊天记录
    func clearAllHistory() {
        guard let files = try? fileManager.contentsOfDirectory(at: storeDirectory, includingPropertiesForKeys: nil) else { return }
        for file in files where file.pathExtension == "json" && file.lastPathComponent != "users.json" {
            try? fileManager.removeItem(at: file)
        }
    }
    
    /// 清除指定用户的聊天记录
    func clearHistory(for ipAddress: String) {
        let file = storeDirectory.appendingPathComponent("\(ipAddress.replacingOccurrences(of: ".", with: "_")).json")
        try? fileManager.removeItem(at: file)
    }
}

// MARK: - 消息 DTO（可序列化）

struct MessageDTO: Codable {
    let packetNo: UInt32
    let direction: Int        // 0=sent, 1=received
    let type: Int             // 0=text, 1=image, 2=file, 3=folder
    let content: String
    let timestamp: Double     // timeIntervalSince1970
    let isRead: Bool
    let isConfirmed: Bool
    let senderName: String?
    let senderHost: String?
    let senderIP: String?
    let attachments: [AttachmentDTO]?
    let attachmentSavePaths: [String: String]?
    
    struct AttachmentDTO: Codable {
        let fileID: String
        let fileName: String
        let fileSize: UInt64
        let fileAttr: UInt32
        let fileTime: UInt64
    }
    
    init(from message: ChatMessage) {
        self.packetNo = message.packetNo
        self.direction = message.direction == .sent ? 0 : 1
        self.type = message.type == .text ? 0 : (message.type == .image ? 1 : (message.type == .file ? 2 : 3))
        self.content = message.content
        self.timestamp = message.timestamp.timeIntervalSince1970
        self.isRead = message.isRead
        self.isConfirmed = message.isConfirmed
        self.senderName = message.sender?.name
        self.senderHost = message.sender?.host
        self.senderIP = message.sender?.ipAddress
        self.attachments = message.attachments?.map { AttachmentDTO(from: $0) }
        self.attachmentSavePaths = message.attachmentSavePaths?.mapValues { $0.path }
    }
    
    func toChatMessage() -> ChatMessage {
        let chatType: ChatMessageType
        switch type {
        case 1: chatType = .image
        case 2: chatType = .file
        case 3: chatType = .folder
        default: chatType = .text
        }
        
        let message = ChatMessage(
            packetNo: packetNo,
            sender: nil,  // 用户需要重新发现后才能关联
            direction: direction == 0 ? .sent : .received,
            type: chatType,
            content: content
        )
        message.isRead = isRead
        message.isConfirmed = isConfirmed
        
        // 恢复附件
        if let atts = attachments {
            message.attachments = atts.map { 
                IPMSGFileAttachment(
                    fileID: $0.fileID,
                    fileName: $0.fileName,
                    fileSize: $0.fileSize,
                    fileAttr: $0.fileAttr,
                    fileTime: $0.fileTime
                )
            }
        }
        
        // 恢复附件保存路径
        if let paths = attachmentSavePaths {
            message.attachmentSavePaths = paths.mapValues { URL(fileURLWithPath: $0) }
        }
        
        return message
    }
}

extension MessageDTO.AttachmentDTO {
    init(from attachment: IPMSGFileAttachment) {
        self.fileID = attachment.fileID
        self.fileName = attachment.fileName
        self.fileSize = attachment.fileSize
        self.fileAttr = attachment.fileAttr
        self.fileTime = attachment.fileTime
    }
}

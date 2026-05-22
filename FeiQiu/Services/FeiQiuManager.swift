import Foundation
import Combine
import SwiftUI

// MARK: - 飞秋消息管理器（核心服务）

/// FeiQiu 主要业务管理器
/// 协调 UDP 服务、用户列表、聊天消息、文件传输
@MainActor
class FeiQiuManager: ObservableObject {
    
    static let shared = FeiQiuManager()
    
    // MARK: - 发布的状态
    
    @Published var users: [LANUser] = []
    @Published var chatHistory: [String: [ChatMessage]] = [:] // ipAddress -> messages
    @Published var transferTasks: [FileTransferTask] = []
    @Published var connectionState: ConnectionState = .disconnected
    @Published var localIPAddress: String = ""
    
    // 用户设置
    @AppStorage("userName") var userName: String = "iOS用户"
    @AppStorage("groupName") var groupName: String = ""
    @AppStorage("hostName") private var hostName: String = ""
    
    // MARK: - 服务
    
    private let udpService = UDPService()
    private let tcpService = TCPFileService()
    
    // 用于消息去重
    private var seenPackets: Set<UInt32> = []
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case failed(String)
    }
    
    // MARK: - 初始化
    
    private init() {
        if hostName.isEmpty {
            hostName = NetworkInterface.getDeviceName()
        }
        setupServices()
    }
    
    // MARK: - 启动/停止
    
    /// 启动服务
    func start() {
        connectionState = .connecting
        
        // 配置用户信息
        udpService.userName = userName
        udpService.hostName = hostName
        
        // 获取本机 IP
        if let firstIP = NetworkInterface.getLocalIPAddresses().first {
            localIPAddress = firstIP
        }
        
        // 启动 UDP/TCP
        udpService.start()
        tcpService.start()
        
        // 发送上线广播，让其他人发现自己
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.udpService.sendEntryBroadcast(groupName: self?.groupName ?? "")
            self?.connectionState = .connected
        }
    }
    
    /// 停止服务
    func stop() {
        // 通知其他人下线
        udpService.sendExitBroadcast()
        
        // 停止服务
        udpService.stop()
        tcpService.stop()
        
        connectionState = .disconnected
    }
    
    // MARK: - 配置服务回调
    
    private func setupServices() {
        udpService.onMessageReceived = { [weak self] message, fromIP in
            Task { @MainActor in
                self?.handleIncomingMessage(message, fromIP: fromIP)
            }
        }
        
        udpService.onError = { error in
            print("UDP Error: \(error.localizedDescription)")
        }
        
        tcpService.onError = { error in
            print("TCP Error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 消息处理
    
    private func handleIncomingMessage(_ message: IPMSGMessage, fromIP: String) {
        // 忽略自己发送的消息
        if message.senderName == userName && message.senderHost == hostName {
            return
        }
        
        // 清理 IP 字符串（去掉可能的 % 号区域标识）
        let cleanIP = fromIP.components(separatedBy: "%").first ?? fromIP
        
        switch message.pureCommand {
        case IPMSGCommand.brEntry.rawValue:
            // 别人上线，添加到用户列表，并回复 ANSENTRY
            addOrUpdateUser(from: message, ipAddress: cleanIP)
            udpService.sendEntryReply(to: cleanIP, groupName: groupName)
            
        case IPMSGCommand.ansEntry.rawValue:
            // 别人应答我的上线，加入用户列表
            addOrUpdateUser(from: message, ipAddress: cleanIP)
            
        case IPMSGCommand.brExit.rawValue:
            // 别人下线，从列表移除
            removeUser(ipAddress: cleanIP)
            
        case IPMSGCommand.brAbsence.rawValue:
            // 状态变更
            updateUserStatus(ipAddress: cleanIP, message: message)
            
        case IPMSGCommand.sendMsg.rawValue:
            // 收到聊天消息
            handleChatMessage(message, fromIP: cleanIP)
            
        case IPMSGCommand.recvMsg.rawValue:
            // 对方确认收到消息
            handleMessageReceipt(message, fromIP: cleanIP)
            
        case IPMSGCommand.readMsg.rawValue:
            // 对方已读
            handleMessageRead(message, fromIP: cleanIP)
            
        default:
            break
        }
    }
    
    // MARK: - 用户管理
    
    private func addOrUpdateUser(from message: IPMSGMessage, ipAddress: String) {
        if let existingUser = users.first(where: { $0.ipAddress == ipAddress }) {
            existingUser.update(from: message)
        } else {
            let newUser = LANUser(from: message, ipAddress: ipAddress)
            users.append(newUser)
        }
    }
    
    private func removeUser(ipAddress: String) {
        users.removeAll { $0.ipAddress == ipAddress }
    }
    
    private func updateUserStatus(ipAddress: String, message: IPMSGMessage) {
        if let user = users.first(where: { $0.ipAddress == ipAddress }) {
            user.absenceMessage = message.additionalData
            user.lastSeen = Date()
        }
    }
    
    // MARK: - 聊天消息处理
    
    private func handleChatMessage(_ message: IPMSGMessage, fromIP: String) {
        // 去重
        guard !seenPackets.contains(message.packetNo) else { return }
        seenPackets.insert(message.packetNo)
        
        // 如果用户不在列表里，自动添加
        if !users.contains(where: { $0.ipAddress == fromIP }) {
            let newUser = LANUser(
                name: message.senderName,
                host: message.senderHost,
                ipAddress: fromIP
            )
            users.append(newUser)
        }
        
        let sender = users.first(where: { $0.ipAddress == fromIP })
        
        // 判断是否含附件
        let hasFiles = message.hasOptionFileAttach
        let chatType: ChatMessageType = hasFiles ? .file : .text
        
        // 拆分正文和附件信息
        // IPMSG 附件格式: 正文\0文件1信息\afile2信息\a...
        var textContent = message.additionalData
        var attachments: [IPMSGFileAttachment] = []
        
        if hasFiles {
            let parts = textContent.components(separatedBy: "\0")
            if parts.count >= 2 {
                textContent = parts[0]
                // 附件部分用 \a (0x07) 分隔
                let fileStrings = parts[1].split(separator: "\u{07}")
                for fs in fileStrings {
                    if let attachment = IPMSGFileAttachment.parse(from: String(fs)) {
                        attachments.append(attachment)
                    }
                }
            }
        }
        
        let chatMessage = ChatMessage(
            packetNo: message.packetNo,
            sender: sender,
            direction: .received,
            type: chatType,
            content: textContent
        )
        chatMessage.attachments = attachments.isEmpty ? nil : attachments
        
        // 加入聊天历史
        if chatHistory[fromIP] == nil {
            chatHistory[fromIP] = []
        }
        chatHistory[fromIP]?.append(chatMessage)
        
        // 如果需要确认，发送 RECVMSG
        if message.hasOptionSendCheck {
            udpService.sendReceiveConfirm(packetNo: message.packetNo, to: fromIP)
        }
    }
    
    private func handleMessageReceipt(_ message: IPMSGMessage, fromIP: String) {
        guard let confirmedNo = UInt32(message.additionalData) else { return }
        
        if let msgs = chatHistory[fromIP] {
            if let msg = msgs.first(where: { $0.packetNo == confirmedNo }) {
                msg.isConfirmed = true
            }
        }
    }
    
    private func handleMessageRead(_ message: IPMSGMessage, fromIP: String) {
        guard let readNo = UInt32(message.additionalData) else { return }
        
        if let msgs = chatHistory[fromIP] {
            if let msg = msgs.first(where: { $0.packetNo == readNo }) {
                msg.isRead = true
            }
        }
    }
    
    // MARK: - 发送消息接口
    
    /// 发送文本消息
    func sendText(_ text: String, to user: LANUser) {
        udpService.sendChatMessage(text: text, to: user.ipAddress)
        
        // 加入本地聊天历史
        let message = ChatMessage(
            packetNo: UInt32(Date().timeIntervalSince1970),
            sender: nil,
            direction: .sent,
            type: .text,
            content: text
        )
        
        if chatHistory[user.ipAddress] == nil {
            chatHistory[user.ipAddress] = []
        }
        chatHistory[user.ipAddress]?.append(message)
    }
    
    /// 手动刷新用户列表（重新发送 BR_ENTRY）
    func refreshUserList() {
        udpService.sendEntryBroadcast(groupName: groupName)
    }
    
    /// 获取指定用户的聊天历史
    func chatMessages(for user: LANUser) -> [ChatMessage] {
        chatHistory[user.ipAddress] ?? []
    }
}

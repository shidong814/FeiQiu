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
    
    /// 发送文件
    func sendFiles(_ fileURLs: [URL], to user: LANUser, message: String = "") {
        guard !fileURLs.isEmpty else { return }
        
        let packetNo = UInt32(Date().timeIntervalSince1970)
        let fileService = FileSharingService.shared
        
        // 准备附件信息
        let attachmentData = fileService.prepareFileAttachments(fileURLs: fileURLs, packetNo: packetNo)
        
        // 构建消息内容: 正文\0附件数据
        let text = message.isEmpty ? "发送了 \(fileURLs.count) 个文件" : message
        let additionalData = "\(text)\0\(attachmentData)"
        
        // 发送带附件的 IPMSG 消息
        let ipmsgMessage = IPMSGMessageBuilder()
            .setSender(name: userName, host: hostName)
            .setCommand(.sendMsg, options: [.sendCheck, .utf8, .fileAttach])
            .setAdditionalData(additionalData)
            .build()
        
        udpService.send(message: ipmsgMessage, to: user.ipAddress)
        
        // 加入本地聊天历史
        let chatMessage = ChatMessage(
            packetNo: packetNo,
            sender: nil,
            direction: .sent,
            type: .file,
            content: text
        )
        
        // 解析附件信息
        var attachments: [IPMSGFileAttachment] = []
        for (index, url) in fileURLs.enumerated() {
            let fileID = String(index + 1)
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = (attrs?[.size] as? UInt64) ?? 0
            let modDate = (attrs?[.modificationDate] as? Date)
            let fileTime = modDate != nil ? UInt64(modDate!.timeIntervalSince1970) : 0
            let isDir = (attrs?[.type] as? FileAttributeType) == .typeDirectory
            
            let attachment = IPMSGFileAttachment(
                fileID: fileID,
                fileName: url.lastPathComponent,
                fileSize: fileSize,
                fileAttr: isDir ? IPMSGFileAttr.dir.rawValue : IPMSGFileAttr.file.rawValue,
                fileTime: fileTime
            )
            attachments.append(attachment)
        }
        chatMessage.attachments = attachments
        
        if chatHistory[user.ipAddress] == nil {
            chatHistory[user.ipAddress] = []
        }
        chatHistory[user.ipAddress]?.append(chatMessage)
        
        // 创建发送任务（用于显示在传输列表）
        for att in attachments {
            let task = FileTransferTask(
                fileName: att.fileName,
                fileSize: att.fileSize,
                direction: .sent,
                remoteIP: user.ipAddress,
                packetNo: packetNo,
                fileID: att.fileID
            )
            task.state = .completed  // 发送方文件已在本地，标记为"等待对方下载"
            transferTasks.append(task)
        }
    }
    
    /// 下载文件
    func downloadFile(attachment: IPMSGFileAttachment, packetNo: UInt32, from user: LANUser, saveDirectory: URL? = nil) {
        let fileService = FileSharingService.shared
        
        let task = fileService.downloadFile(
            packetNo: packetNo,
            fileID: attachment.fileID,
            fileName: attachment.fileName,
            fileSize: attachment.fileSize,
            remoteIP: user.ipAddress,
            localUserName: userName,
            localHostName: hostName,
            saveDirectory: saveDirectory
        )
        
        transferTasks.append(task)
        
        // 监听完成
        fileService.onTransferComplete = { [weak self] completedTask, result in
            DispatchQueue.main.async {
                if case .success(let saveURL) = result {
                    // 更新聊天消息中的附件保存路径
                    if let msgs = self?.chatHistory[user.ipAddress] {
                        for msg in msgs {
                            if msg.packetNo == packetNo {
                                if msg.attachmentSavePaths == nil {
                                    msg.attachmentSavePaths = [:]
                                }
                                msg.attachmentSavePaths?[attachment.fileID] = saveURL
                            }
                        }
                    }
                    // 更新传输任务的保存路径
                    completedTask.saveURL = saveURL
                }
            }
        }
    }
    
    /// 选择文件并发送
    func selectAndSendFiles(to user: LANUser) {
        let fileURLs = FileSharingService.showOpenPanel(allowMultiple: true)
        guard !fileURLs.isEmpty else { return }
        sendFiles(fileURLs, to: user)
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

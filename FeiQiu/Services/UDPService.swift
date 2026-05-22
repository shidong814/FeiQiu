import Foundation
import Network

// MARK: - UDP 服务

/// IPMSG UDP 通讯服务
/// 负责: 广播发现用户、发送/接收聊天消息
class UDPService {
    
    static let defaultPort: UInt16 = 2425
    static let ipmsgVersion: UInt32 = 1
    
    // 回调
    var onMessageReceived: ((IPMSGMessage, String) -> Void)?
    var onError: ((Error) -> Void)?
    
    private var connection: NWConnection?
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.feiqiu.udp", qos: .userInitiated)
    
    private(set) var isRunning = false
    private(set) var localPort: UInt16 = defaultPort
    
    // 当前用户信息
    var userName: String = ""
    var hostName: String = ""
    
    // MARK: - 启动/停止
    
    /// 启动 UDP 监听
    func start(port: UInt16 = defaultPort) {
        guard !isRunning else { return }
        
        localPort = port
        
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        
        // 创建监听器
        do {
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            onError?(UDPServiceError.listenerCreationFailed(error))
            return
        }
        
        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isRunning = true
                self?.startReceiving()
            case .failed(let error):
                self?.isRunning = false
                self?.onError?(UDPServiceError.listenerFailed(error))
            default:
                break
            }
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        
        listener?.start(queue: queue)
    }
    
    /// 停止 UDP 监听
    func stop() {
        listener?.cancel()
        connection?.cancel()
        isRunning = false
    }
    
    // MARK: - 发送消息
    
    /// 发送 IPMSG 消息到指定地址
    func send(message: IPMSGMessage, to address: String, port: UInt16 = defaultPort) {
        guard let data = message.encode() else {
            onError?(UDPServiceError.encodingFailed)
            return
        }
        
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(address),
            port: NWEndpoint.Port(rawValue: port)!
        )
        
        let conn = NWConnection(to: endpoint, using: .udp)
        conn.start(queue: queue)
        conn.send(content: data, completion: .contentProcessed { [weak conn] error in
            if let error = error {
                self.onError?(UDPServiceError.sendFailed(error))
            }
            conn?.cancel()
        })
    }
    
    /// 广播 IPMSG 消息到局域网
    func broadcast(message: IPMSGMessage, port: UInt16 = defaultPort) {
        // 获取所有本地网络接口的广播地址
        let broadcastAddresses = NetworkInterface.getBroadcastAddresses()
        
        for address in broadcastAddresses {
            send(message: message, to: address, port: port)
        }
        
        // 同时发送到全局广播地址
        send(message: message, to: "255.255.255.255", port: port)
    }
    
    // MARK: - 接收消息
    
    private func startReceiving() {
        guard let listener = listener else { return }
        
        listener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveLoop(on: connection)
    }
    
    private func receiveLoop(on connection: NWConnection) {
        connection.receiveMessage { [weak self, weak connection] content, context, isComplete, error in
            if let error = error {
                self?.onError?(UDPServiceError.receiveFailed(error))
                return
            }
            
            if let data = content, let ipmsgMsg = IPMSGMessage.decode(from: data) {
                // 尝试获取发送者 IP
                var senderIP = ""
                if let endpoint = connection?.currentPath?.remoteEndpoint,
                   case .hostPort(let host, _) = endpoint {
                    senderIP = host.debugDescription
                }
                self?.onMessageReceived?(ipmsgMsg, senderIP)
            }
            
            // 继续接收
            if let connection = connection, !isComplete {
                self?.receiveLoop(on: connection)
            }
        }
    }
    
    // MARK: - 便捷方法
    
    /// 发送上线广播
    func sendEntryBroadcast(groupName: String = "") {
        let additionalData = "\(userName)\0\(groupName)"
        
        let message = IPMSGMessageBuilder()
            .setSender(name: userName, host: hostName)
            .setCommand(.brEntry, options: [.sendCheck, .utf8])
            .setAdditionalData(additionalData)
            .build()
        
        broadcast(message: message)
    }
    
    /// 发送下线广播
    func sendExitBroadcast() {
        let message = IPMSGMessageBuilder()
            .setSender(name: userName, host: hostName)
            .setCommand(.brExit, options: [.broadcast, .utf8])
            .setAdditionalData("")
            .build()
        
        broadcast(message: message)
    }
    
    /// 应答上线消息
    func sendEntryReply(to address: String, groupName: String = "") {
        let additionalData = "\(userName)\0\(groupName)"
        
        let message = IPMSGMessageBuilder()
            .setSender(name: userName, host: hostName)
            .setCommand(.ansEntry, options: [.sendCheck, .utf8])
            .setAdditionalData(additionalData)
            .build()
        
        send(message: message, to: address)
    }
    
    /// 发送聊天消息
    func sendChatMessage(text: String, to address: String, options: IPMSGOpt = []) {
        let message = IPMSGMessageBuilder()
            .setSender(name: userName, host: hostName)
            .setCommand(.sendMsg, options: [.sendCheck, .utf8].union(options))
            .setAdditionalData(text)
            .build()
        
        send(message: message, to: address)
    }
    
    /// 确认收到消息
    func sendReceiveConfirm(packetNo: UInt32, to address: String) {
        let message = IPMSGMessageBuilder()
            .setSender(name: userName, host: hostName)
            .setCommand(.recvMsg, options: [.utf8])
            .setAdditionalData(String(packetNo))
            .build()
        
        send(message: message, to: address)
    }
    
    /// 发送已读通知
    func sendReadNotify(packetNo: UInt32, to address: String) {
        let message = IPMSGMessageBuilder()
            .setSender(name: userName, host: hostName)
            .setCommand(.readMsg, options: [.utf8])
            .setAdditionalData(String(packetNo))
            .build()
        
        send(message: message, to: address)
    }
}

// MARK: - 错误类型

enum UDPServiceError: LocalizedError {
    case listenerCreationFailed(Error)
    case listenerFailed(Error)
    case sendFailed(Error)
    case receiveFailed(Error)
    case encodingFailed
    case notRunning
    
    var errorDescription: String? {
        switch self {
        case .listenerCreationFailed(let e): return "监听器创建失败: \(e.localizedDescription)"
        case .listenerFailed(let e): return "监听器错误: \(e.localizedDescription)"
        case .sendFailed(let e): return "发送失败: \(e.localizedDescription)"
        case .receiveFailed(let e): return "接收失败: \(e.localizedDescription)"
        case .encodingFailed: return "消息编码失败"
        case .notRunning: return "UDP 服务未启动"
        }
    }
}

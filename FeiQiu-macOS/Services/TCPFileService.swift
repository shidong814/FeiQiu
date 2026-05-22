import Foundation
import Network

// MARK: - TCP 文件传输服务

/// IPMSG TCP 文件传输服务
/// 飞秋/IPMSG 文件传输协议:
/// 1. 发送方在 SENDMSG 消息中携带 FILEATTACHOPT 标志和文件信息
/// 2. 接收方解析文件信息后, 通过 TCP 连接到发送方的 2425 端口
/// 3. 接收方发送 GETFILEDATA 请求, 包含包序号、文件序号、偏移量
/// 4. 发送方响应文件数据流
class TCPFileService {
    
    static let defaultPort: UInt16 = 2425
    
    // 回调
    var onIncomingTransfer: ((FileTransferTask) -> Void)?
    var onError: ((Error) -> Void)?
    
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.feiqiu.tcp", qos: .userInitiated)
    
    // 待发送的文件映射: packetNo -> [fileID: filePath]
    private var pendingFiles: [String: URL] = [:]
    private let pendingLock = NSLock()
    
    // MARK: - 启动/停止
    
    /// 启动 TCP 监听
    func start(port: UInt16 = defaultPort) {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        
        do {
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            onError?(TCPServiceError.listenerCreationFailed(error))
            return
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleIncomingConnection(connection)
        }
        
        listener?.start(queue: queue)
    }
    
    func stop() {
        listener?.cancel()
    }
    
    // MARK: - 注册待发送文件
    
    /// 注册文件供对方下载
    /// - Parameters:
    ///   - packetNo: 消息包序号
    ///   - fileID: 文件序号
    ///   - fileURL: 本地文件路径
    func registerFile(packetNo: UInt32, fileID: String, fileURL: URL) {
        let key = "\(packetNo):\(fileID)"
        pendingLock.lock()
        pendingFiles[key] = fileURL
        pendingLock.unlock()
    }
    
    /// 移除已发送完毕的文件
    func releaseFile(packetNo: UInt32, fileID: String) {
        let key = "\(packetNo):\(fileID)"
        pendingLock.lock()
        pendingFiles.removeValue(forKey: key)
        pendingLock.unlock()
    }
    
    // MARK: - 接收文件请求（作为发送方）
    
    private func handleIncomingConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        
        // 接收 GETFILEDATA 请求
        connection.receiveMessage { [weak self, weak connection] content, _, _, error in
            guard let self = self, let connection = connection else { return }
            
            if let error = error {
                self.onError?(TCPServiceError.receiveFailed(error))
                connection.cancel()
                return
            }
            
            guard let data = content, let request = IPMSGMessage.decode(from: data) else {
                connection.cancel()
                return
            }
            
            // 处理 GETFILEDATA: additionalData 格式 = packetNo:fileID:offset
            if request.pureCommand == IPMSGCommand.getFileData.rawValue {
                self.handleFileDataRequest(request, on: connection)
            } else {
                connection.cancel()
            }
        }
    }
    
    private func handleFileDataRequest(_ request: IPMSGMessage, on connection: NWConnection) {
        let parts = request.additionalData.split(separator: ":")
        guard parts.count >= 2 else {
            connection.cancel()
            return
        }
        
        // 飞秋: packetNo:fileID:offset(hex)
        // packetNo 可能为十六进制
        let fileKey = "\(parts[0]):\(parts[1])"
        let offset: UInt64 = parts.count >= 3 ? (UInt64(parts[2], radix: 16) ?? 0) : 0
        
        pendingLock.lock()
        let fileURL = pendingFiles[fileKey]
        pendingLock.unlock()
        
        guard let url = fileURL else {
            connection.cancel()
            return
        }
        
        sendFileData(url: url, offset: offset, on: connection)
    }
    
    private func sendFileData(url: URL, offset: UInt64, on connection: NWConnection) {
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
            connection.cancel()
            return
        }
        
        if offset > 0 {
            try? fileHandle.seek(toOffset: offset)
        }
        
        let chunkSize = 64 * 1024  // 64KB chunks
        
        func sendChunk() {
            let data = fileHandle.readData(ofLength: chunkSize)
            
            if data.isEmpty {
                // 文件发送完毕
                try? fileHandle.close()
                connection.cancel()
                return
            }
            
            connection.send(content: data, completion: .contentProcessed { error in
                if error != nil {
                    try? fileHandle.close()
                    connection.cancel()
                    return
                }
                sendChunk()
            })
        }
        
        sendChunk()
    }
    
    // MARK: - 主动接收文件（作为接收方）
    
    /// 从对方下载文件
    /// - Parameters:
    ///   - task: 文件传输任务
    ///   - packetNo: 消息包序号
    ///   - fileID: 文件序号
    ///   - localUser: 本地用户名/主机名
    ///   - saveURL: 保存路径
    ///   - progressHandler: 进度回调
    ///   - completion: 完成回调
    func downloadFile(
        task: FileTransferTask,
        packetNo: UInt32,
        fileID: String,
        localUserName: String,
        localHostName: String,
        saveURL: URL,
        progressHandler: @escaping (UInt64) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(task.remoteIP),
            port: NWEndpoint.Port(rawValue: task.remotePort)!
        )
        
        let connection = NWConnection(to: endpoint, using: .tcp)
        connection.start(queue: queue)
        
        // 1. 发送 GETFILEDATA 请求
        let packetHex = String(packetNo, radix: 16).uppercased()
        let request = IPMSGMessageBuilder()
            .setSender(name: localUserName, host: localHostName)
            .setCommand(.getFileData, options: [.utf8])
            .setAdditionalData("\(packetHex):\(fileID):0:0")
            .build()
        
        guard let reqData = request.encode() else {
            completion(.failure(TCPServiceError.encodingFailed))
            connection.cancel()
            return
        }
        
        connection.send(content: reqData, completion: .contentProcessed { [weak self] error in
            if let error = error {
                completion(.failure(error))
                connection.cancel()
                return
            }
            
            // 2. 接收文件数据流
            self?.receiveFileData(
                on: connection,
                saveURL: saveURL,
                expectedSize: task.fileSize,
                progressHandler: progressHandler,
                completion: completion
            )
        })
    }
    
    private func receiveFileData(
        on connection: NWConnection,
        saveURL: URL,
        expectedSize: UInt64,
        progressHandler: @escaping (UInt64) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // 确保目录存在
        let dir = saveURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        
        // 创建文件
        FileManager.default.createFile(atPath: saveURL.path, contents: nil, attributes: nil)
        guard let fileHandle = try? FileHandle(forWritingTo: saveURL) else {
            completion(.failure(TCPServiceError.fileWriteFailed))
            connection.cancel()
            return
        }
        
        var receivedSize: UInt64 = 0
        var lastProgressUpdate: TimeInterval = 0
        
        func receiveChunk() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { content, _, isComplete, error in
                if let error = error {
                    try? fileHandle.close()
                    completion(.failure(error))
                    connection.cancel()
                    return
                }
                
                if let data = content, !data.isEmpty {
                    fileHandle.write(data)
                    receivedSize += UInt64(data.count)
                    
                    // 节流更新进度（每 100ms 一次）
                    let now = Date().timeIntervalSince1970
                    if now - lastProgressUpdate > 0.1 || receivedSize >= expectedSize {
                        lastProgressUpdate = now
                        progressHandler(receivedSize)
                    }
                }
                
                if isComplete || receivedSize >= expectedSize {
                    try? fileHandle.close()
                    progressHandler(receivedSize)
                    completion(.success(()))
                    connection.cancel()
                } else {
                    receiveChunk()
                }
            }
        }
        
        receiveChunk()
    }
}

// MARK: - 错误类型

enum TCPServiceError: LocalizedError {
    case listenerCreationFailed(Error)
    case sendFailed(Error)
    case receiveFailed(Error)
    case fileWriteFailed
    case encodingFailed
    
    var errorDescription: String? {
        switch self {
        case .listenerCreationFailed(let e): return "TCP 监听器创建失败: \(e.localizedDescription)"
        case .sendFailed(let e): return "TCP 发送失败: \(e.localizedDescription)"
        case .receiveFailed(let e): return "TCP 接收失败: \(e.localizedDescription)"
        case .fileWriteFailed: return "文件写入失败"
        case .encodingFailed: return "请求编码失败"
        }
    }
}

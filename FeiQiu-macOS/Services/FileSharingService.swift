import Foundation
import AppKit

// MARK: - 文件共享服务

/// 管理文件发送和接收的完整流程
class FileSharingService {
    
    static let shared = FileSharingService()
    
    private let tcpService = TCPFileService()
    private let queue = DispatchQueue(label: "com.feiqiu.filesharing", qos: .userInitiated)
    
    // 待发送文件注册表: packetNo_hex -> [fileID: URL]
    private var sendRegistry: [String: [String: URL]] = [:]
    private let registryLock = NSLock()
    
    // 下载中的任务
    private var activeDownloads: [String: FileTransferTask] = [:]
    
    var onTransferProgress: ((FileTransferTask) -> Void)?
    var onTransferComplete: ((FileTransferTask, Result<URL, Error>) -> Void)?
    var onError: ((Error) -> Void)?
    
    private init() {
        tcpService.start()
    }
    
    // MARK: - 发送文件
    
    /// 准备发送文件，返回附件信息字符串（用于 IPMSG 消息附加数据）
    func prepareFileAttachments(fileURLs: [URL], packetNo: UInt32) -> String {
        var attachments: [String] = []
        var fileMap: [String: URL] = [:]
        
        for (index, url) in fileURLs.enumerated() {
            let fileID = String(index + 1)
            let fileName = url.lastPathComponent
            
            // 获取文件属性
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = (attrs?[.size] as? UInt64) ?? 0
            let modDate = (attrs?[.modificationDate] as? Date)
            let fileTime = modDate != nil ? UInt64(modDate!.timeIntervalSince1970) : 0
            let isDir = (attrs?[.type] as? FileAttributeType) == .typeDirectory
            let fileAttr: UInt32 = isDir ? IPMSGFileAttr.dir.rawValue : IPMSGFileAttr.file.rawValue
            
            let attachment = IPMSGFileAttachment(
                fileID: fileID,
                fileName: fileName,
                fileSize: fileSize,
                fileAttr: fileAttr,
                fileTime: fileTime
            )
            
            attachments.append(attachment.encode())
            fileMap[fileID] = url
        }
        
        // 注册到 TCP 服务供对方下载
        let key = String(packetNo, radix: 16).uppercased()
        registryLock.lock()
        sendRegistry[key] = fileMap
        registryLock.unlock()
        
        // 也注册到 TCPFileService
        for (fileID, url) in fileMap {
            tcpService.registerFile(packetNo: packetNo, fileID: fileID, fileURL: url)
        }
        
        // 附件用 \a (0x07) 分隔
        return attachments.joined(separator: "\u{07}")
    }
    
    /// 获取已注册的发送文件路径
    func getRegisteredFile(packetNo: String, fileID: String) -> URL? {
        registryLock.lock()
        defer { registryLock.unlock() }
        return sendRegistry[packetNo]?[fileID]
    }
    
    // MARK: - 下载文件
    
    /// 下载文件
    /// - Parameters:
    ///   - packetNo: 消息包序号
    ///   - fileID: 文件序号
    ///   - fileName: 文件名
    ///   - fileSize: 文件大小
    ///   - remoteIP: 发送者 IP
    ///   - remotePort: 发送者端口
    ///   - localUserName: 本地用户名
    ///   - localHostName: 本地主机名
    ///   - saveDirectory: 保存目录（nil 则弹出保存对话框）
    func downloadFile(
        packetNo: UInt32,
        fileID: String,
        fileName: String,
        fileSize: UInt64,
        remoteIP: String,
        remotePort: UInt16 = 2425,
        localUserName: String,
        localHostName: String,
        saveDirectory: URL? = nil
    ) -> FileTransferTask {
        
        let task = FileTransferTask(
            fileName: fileName,
            fileSize: fileSize,
            direction: .received,
            remoteIP: remoteIP,
            remotePort: remotePort
        )
        
        let taskKey = "\(packetNo):\(fileID)"
        activeDownloads[taskKey] = task
        
        // 确定保存路径
        let saveURL: URL
        if let dir = saveDirectory {
            saveURL = dir.appendingPathComponent(fileName)
        } else {
            // 默认保存到 ~/Downloads/飞秋/
            let downloadsDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Downloads")
                .appendingPathComponent("飞秋")
            try? FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
            saveURL = downloadsDir.appendingPathComponent(fileName)
        }
        
        // 如果文件已存在，追加编号
        var finalSaveURL = saveURL
        var counter = 1
        while FileManager.default.fileExists(atPath: finalSaveURL.path) {
            let name = fileName.components(separatedBy: ".").dropLast().joined(separator: ".")
            let ext = fileName.components(separatedBy: ".").last ?? ""
            finalSaveURL = saveURL.deletingLastPathComponent()
                .appendingPathComponent("\(name)(\(counter)).\(ext)")
            counter += 1
        }
        
        let finalURL = finalSaveURL
        
        // 启动下载
        task.state = .transferring
        
        tcpService.downloadFile(
            task: task,
            packetNo: packetNo,
            fileID: fileID,
            localUserName: localUserName,
            localHostName: localHostName,
            saveURL: finalURL,
            progressHandler: { [weak self, weak task] transferred in
                guard let task = task else { return }
                DispatchQueue.main.async {
                    task.transferredSize = transferred
                    let elapsed = max(Date().timeIntervalSince(task.timestamp), 0.001)
                    task.speed = Double(transferred) / elapsed
                    self?.onTransferProgress?(task)
                }
            },
            completion: { [weak self, weak task] result in
                guard let task = task else { return }
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        task.state = .completed
                        task.transferredSize = task.fileSize
                        self?.onTransferComplete?(task, .success(finalURL))
                        
                        // 发送通知
                        let notification = NSUserNotification()
                        notification.title = "文件接收完成"
                        notification.informativeText = "\(fileName) 已保存到 \(finalURL.deletingLastPathComponent().path)"
                        notification.soundName = NSUserNotificationDefaultSoundName
                        NSUserNotificationCenter.default.deliver(notification)
                        
                    case .failure(let error):
                        task.state = .failed
                        self?.onTransferComplete?(task, .failure(error))
                    }
                    self?.activeDownloads.removeValue(forKey: taskKey)
                }
            }
        )
        
        return task
    }
    
    // MARK: - 选择文件对话框
    
    /// 弹出文件选择对话框
    static func showOpenPanel(allowMultiple: Bool = true) -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = allowMultiple
        panel.title = "选择要发送的文件"
        panel.prompt = "选择"
        
        guard panel.runModal() == .OK else { return [] }
        return panel.urls
    }
    
    /// 弹出保存对话框
    static func showSavePanel(fileName: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = "保存文件"
        panel.nameFieldStringValue = fileName
        panel.canCreateDirectories = true
        panel.prompt = "保存"
        
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
    
    /// 弹出选择文件夹对话框
    static func showFolderPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "选择保存位置"
        panel.prompt = "选择"
        
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}

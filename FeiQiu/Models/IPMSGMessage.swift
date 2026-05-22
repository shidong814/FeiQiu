import Foundation

// MARK: - IPMSG 消息模型

/// IPMSG 协议消息
/// 格式: 版本号:包序号:用户名:主机名:命令字:附加数据
struct IPMSGMessage {
    let version: UInt32           // 协议版本号 (1)
    let packetNo: UInt32          // 包序号（时间戳）
    let senderName: String        // 发送者用户名
    let senderHost: String        // 发送者主机名
    let command: UInt32           // 命令字（含选项标志）
    let additionalData: String    // 附加数据（消息正文等）
    
    // 计算属性
    var pureCommand: UInt32 {
        command & 0x0000FFFF  // 低 16 位为命令字
    }
    
    var options: UInt32 {
        command & 0xFFFF0000  // 高 16 位为选项
    }
    
    var hasOptionSendCheck: Bool {
        (options & IPMSGOpt.sendCheck.rawValue) != 0
    }
    
    var hasOptionFileAttach: Bool {
        (options & IPMSGOpt.fileAttach.rawValue) != 0
    }
    
    var hasOptionUTF8: Bool {
        (options & IPMSGOpt.utf8.rawValue) != 0
    }
    
    // MARK: - 编码（发送）
    
    /// 编码为 IPMSG 协议字符串
    func encode() -> Data? {
        let msg = "\(version):\(packetNo):\(senderName):\(senderHost):\(command):\(additionalData)"
        
        // 优先尝试 UTF-8 编码
        if let data = msg.data(using: .utf8) {
            return data
        }
        // 降级 GBK 编码（兼容旧版飞秋）
        if let gbkEncoding = CFStringEncodings.GB_18030_2000.rawValue,
           let data = msg.data(using: String.Encoding(rawValue: gbkEncoding)) {
            return data
        }
        
        return msg.data(using: .ascii, allowLossyConversion: true)
    }
    
    // MARK: - 解码（接收）
    
    /// 从原始 Data 解码 IPMSG 消息
    static func decode(from data: Data) -> IPMSGMessage? {
        // 尝试多种编码解析
        let encodings: [String.Encoding] = [.utf8, String.Encoding(rawValue: CFStringEncodings.GB_18030_2000.rawValue)]
        
        for encoding in encodings {
            guard let rawString = String(data: data, encoding: encoding) else { continue }
            return parse(rawString)
        }
        
        // 降级 ASCII
        if let rawString = String(data: data, encoding: .ascii) {
            return parse(rawString)
        }
        
        return nil
    }
    
    private static func parse(_ raw: String) -> IPMSGMessage? {
        let parts = raw.split(separator: ":", maxSplits: 5, omittingEmptySubsequences: false)
        guard parts.count >= 6 else { return nil }
        
        guard let version = UInt32(parts[0]),
              let packetNo = UInt32(parts[1]),
              let command = UInt32(parts[4]) else { return nil }
        
        return IPMSGMessage(
            version: version,
            packetNo: packetNo,
            senderName: String(parts[2]),
            senderHost: String(parts[3]),
            command: command,
            additionalData: String(parts[5])
        )
    }
}

// MARK: - 消息构建器

class IPMSGMessageBuilder {
    private var version: UInt32 = 1
    private var senderName: String = ""
    private var senderHost: String = ""
    private var command: UInt32 = 0
    private var additionalData: String = ""
    
    func setSender(name: String, host: String) -> IPMSGMessageBuilder {
        self.senderName = name
        self.senderHost = host
        return self
    }
    
    func setCommand(_ cmd: IPMSGCommand, options: IPMSGOpt = []) -> IPMSGMessageBuilder {
        self.command = cmd.rawValue | options.rawValue
        return self
    }
    
    func setAdditionalData(_ data: String) -> IPMSGMessageBuilder {
        self.additionalData = data
        return self
    }
    
    func build() -> IPMSGMessage {
        let packetNo = UInt32(Date().timeIntervalSince1970)
        return IPMSGMessage(
            version: version,
            packetNo: packetNo,
            senderName: senderName,
            senderHost: senderHost,
            command: command,
            additionalData: additionalData
        )
    }
}

// MARK: - 附件文件信息

/// IPMSG 文件附件信息
/// 格式: 文件序号:文件名:文件大小:文件属性:文件时间
struct IPMSGFileAttachment {
    let fileID: String       // 文件序号（十六进制）
    let fileName: String     // 文件名
    let fileSize: UInt64     // 文件大小（十六进制）
    let fileAttr: UInt32     // 文件属性
    let fileTime: UInt64     // 文件时间
    
    var isDirectory: Bool {
        fileAttr == IPMSGFileAttr.dir.rawValue
    }
    
    /// 从附件字符串解析
    static func parse(from string: String) -> IPMSGFileAttachment? {
        let parts = string.split(separator: ":")
        guard parts.count >= 5 else { return nil }
        
        guard let fileSize = UInt64(parts[2], radix: 16),
              let fileAttr = UInt32(parts[3]),
              let fileTime = UInt64(parts[4], radix: 16) else { return nil }
        
        return IPMSGFileAttachment(
            fileID: String(parts[0]),
            fileName: String(parts[1]),
            fileSize: fileSize,
            fileAttr: fileAttr,
            fileTime: fileTime
        )
    }
    
    /// 编码为附件字符串
    func encode() -> String {
        let sizeHex = String(fileSize, radix: 16).uppercased()
        let timeHex = String(fileTime, radix: 16).uppercased()
        return "\(fileID):\(fileName):\(sizeHex):\(fileAttr):\(timeHex)"
    }
}

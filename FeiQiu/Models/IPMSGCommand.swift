import Foundation

// MARK: - IPMSG 命令字定义
// 参考: https://ipmsg.org/protocol.html

/// IPMSG 命令字
struct IPMSGCommand: RawRepresentable {
    let rawValue: UInt32
    
    static let noOperation   = IPMSGCommand(rawValue: 0x00000000)
    static let brEntry       = IPMSGCommand(rawValue: 0x00000001)  // 上线广播
    static let brExit        = IPMSGCommand(rawValue: 0x00000002)  // 下线通知
    static let ansEntry      = IPMSGCommand(rawValue: 0x00000003)  // 应答上线
    static let brAbsence     = IPMSGCommand(rawValue: 0x00000004)  // 状态变更
    static let brIsGetlist   = IPMSGCommand(rawValue: 0x00000018)  // 请求获取在线列表
    static let okGetlist     = IPMSGCommand(rawValue: 0x00000019)  // 允许获取在线列表
    static let getList       = IPMSGCommand(rawValue: 0x0000001a)  // 获取在线列表
    static let ansList       = IPMSGCommand(rawValue: 0x0000001b)  // 应答在线列表
    static let brIsGetlist2  = IPMSGCommand(rawValue: 0x0000001c)  // 请求获取在线列表2
    
    static let sendMsg       = IPMSGCommand(rawValue: 0x00000020)  // 发送消息
    static let recvMsg       = IPMSGCommand(rawValue: 0x00000021)  // 消息接收确认
    static let readMsg       = IPMSGCommand(rawValue: 0x00000030)  // 已读通知
    static let deleteMsg     = IPMSGCommand(rawValue: 0x00000031)  // 删除通知
    
    static let getInfo       = IPMSGCommand(rawValue: 0x00000040)  // 获取版本信息
    static let sendInfo      = IPMSGCommand(rawValue: 0x00000041)  // 应答版本信息
    
    static let getFileData   = IPMSGCommand(rawValue: 0x00000060)  // 请求文件数据
    static let releaseFiles  = IPMSGCommand(rawValue: 0x00000061)  // 释放文件
    static let dirFiles      = IPMSGCommand(rawValue: 0x00000062)  // 文件夹文件列表
    static let dirFilesData  = IPMSGCommand(rawValue: 0x00000063)  // 文件夹文件数据
    static let dirFilesOpt   = IPMSGCommand(rawValue: 0x00000064)  // 文件夹选项
    static let dirFileList   = IPMSGCommand(rawValue: 0x00000065)  // 文件夹文件列表
    static let dirFileListR  = IPMSGCommand(rawValue: 0x00000066)  // 文件夹文件列表应答
    
    static let getFileDir    = IPMSGCommand(rawValue: 0x00000070)  // 请求目录
    static let dirList       = IPMSGCommand(rawValue: 0x00000071)  // 目录列表
    static let dirListR      = IPMSGCommand(rawValue: 0x00000072)  // 目录列表应答
}

// MARK: - 消息选项标志位（命令字高 16 位 OR）
struct IPMSGOpt: OptionSet {
    let rawValue: UInt32
    
    static let sendCheck    = IPMSGOpt(rawValue: 0x00000010)  // 需要确认
    static let secret       = IPMSGOpt(rawValue: 0x00000020)  // 密文/封装消息
    static let readCheck    = IPMSGOpt(rawValue: 0x00000040)  // 已读确认
    static let broadcast    = IPMSGOpt(rawValue: 0x00000100)  // 广播消息
    static let multicast    = IPMSGOpt(rawValue: 0x00000200)  // 多播消息
    static let newPassword  = IPMSGOpt(rawValue: 0x00000400)  // 新密码
    static let fileAttach   = IPMSGOpt(rawValue: 0x00100000)  // 附件文件
    static let encrypt      = IPMSGOpt(rawValue: 0x00200000)  // 加密
    static let utf8         = IPMSGOpt(rawValue: 0x00400000)  // UTF-8编码
    static let noAddList    = IPMSGOpt(rawValue: 0x00800000)  // 不添加到列表
    static let autoclose    = IPMSGOpt(rawValue: 0x01000000)  // 自动关闭
}

// MARK: - 文件类型
struct IPMSGFileAttr: RawRepresentable {
    let rawValue: UInt32
    
    static let file   = IPMSGFileAttr(rawValue: 0x00000001)  // 普通文件
    static let dir    = IPMSGFileAttr(rawValue: 0x00000002)  // 目录
    static let drive  = IPMSGFileAttr(rawValue: 0x00000003)  // 驱动器
}

// MARK: - 文件传输命令
struct IPMSGFileCommand: RawRepresentable {
    let rawValue: UInt32
    
    static let dirFile      = IPMSGFileCommand(rawValue: 0x00000001)  // 目录文件
    static let retrDir      = IPMSGFileCommand(rawValue: 0x00000002)  // 检索目录
    static let homeDir      = IPMSGFileCommand(rawValue: 0x00000003)  // 主目录
    static let dir          = IPMSGFileCommand(rawValue: 0x00000004)  // 目录
    static let dirRetr      = IPMSGFileCommand(rawValue: 0x00000005)  // 目录检索
    static let dirInfo      = IPMSGFileCommand(rawValue: 0x00000030)  // 目录信息
    static let dirInfoData  = IPMSGFileCommand(rawValue: 0x00000031)  // 目录信息数据
}

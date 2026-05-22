import XCTest
@testable import FeiQiu

/// IPMSG 协议消息编解码测试
final class IPMSGMessageTests: XCTestCase {
    
    // MARK: - 编码测试
    
    func testEncodeBasicMessage() {
        let message = IPMSGMessage(
            version: 1,
            packetNo: 1234567890,
            senderName: "张三",
            senderHost: "iPhone-Zhang",
            command: IPMSGCommand.sendMsg.rawValue | IPMSGOpt.utf8.rawValue,
            additionalData: "你好世界"
        )
        
        let data = message.encode()
        XCTAssertNotNil(data)
        
        let str = String(data: data!, encoding: .utf8)!
        XCTAssertTrue(str.contains("1:1234567890:张三:iPhone-Zhang:"))
        XCTAssertTrue(str.contains(":你好世界"))
    }
    
    // MARK: - 解码测试
    
    func testDecodeBasicMessage() {
        let raw = "1:1234567890:zhangsan:iPhone:32:Hello World"
        let data = raw.data(using: .utf8)!
        
        let message = IPMSGMessage.decode(from: data)
        
        XCTAssertNotNil(message)
        XCTAssertEqual(message?.version, 1)
        XCTAssertEqual(message?.packetNo, 1234567890)
        XCTAssertEqual(message?.senderName, "zhangsan")
        XCTAssertEqual(message?.senderHost, "iPhone")
        XCTAssertEqual(message?.command, 32)
        XCTAssertEqual(message?.additionalData, "Hello World")
        XCTAssertEqual(message?.pureCommand, IPMSGCommand.sendMsg.rawValue)
    }
    
    func testDecodeBREntryMessage() {
        // 模拟 Windows 飞秋发来的上线广播
        let raw = "1:9876543:WinUser:DESKTOP-PC:1:WinUser\u{00}研发部"
        let data = raw.data(using: .utf8)!
        
        let message = IPMSGMessage.decode(from: data)
        XCTAssertNotNil(message)
        XCTAssertEqual(message?.pureCommand, IPMSGCommand.brEntry.rawValue)
    }
    
    func testDecodeMessageWithColonInContent() {
        // 消息内容包含冒号
        let raw = "1:12345:user:host:32:URL: https://example.com"
        let data = raw.data(using: .utf8)!
        
        let message = IPMSGMessage.decode(from: data)
        XCTAssertNotNil(message)
        XCTAssertEqual(message?.additionalData, "URL: https://example.com")
    }
    
    // MARK: - 命令字测试
    
    func testCommandOptions() {
        let cmd = IPMSGCommand.sendMsg.rawValue | IPMSGOpt.sendCheck.rawValue | IPMSGOpt.fileAttach.rawValue
        
        let message = IPMSGMessage(
            version: 1,
            packetNo: 1,
            senderName: "a",
            senderHost: "b",
            command: cmd,
            additionalData: ""
        )
        
        XCTAssertEqual(message.pureCommand, IPMSGCommand.sendMsg.rawValue)
        XCTAssertTrue(message.hasOptionSendCheck)
        XCTAssertTrue(message.hasOptionFileAttach)
        XCTAssertFalse(message.hasOptionUTF8)
    }
    
    // MARK: - 文件附件测试
    
    func testParseFileAttachment() {
        let attachStr = "1:test.txt:400:1:5F8A2C00"
        
        let attachment = IPMSGFileAttachment.parse(from: attachStr)
        
        XCTAssertNotNil(attachment)
        XCTAssertEqual(attachment?.fileID, "1")
        XCTAssertEqual(attachment?.fileName, "test.txt")
        XCTAssertEqual(attachment?.fileSize, 0x400)
        XCTAssertEqual(attachment?.fileAttr, 1)
        XCTAssertFalse(attachment!.isDirectory)
    }
    
    func testEncodeFileAttachment() {
        let attachment = IPMSGFileAttachment(
            fileID: "1",
            fileName: "report.pdf",
            fileSize: 1024,
            fileAttr: 1,
            fileTime: 0x5F8A2C00
        )
        
        let encoded = attachment.encode()
        XCTAssertEqual(encoded, "1:report.pdf:400:1:5F8A2C00")
    }
    
    // MARK: - Builder 测试
    
    func testMessageBuilder() {
        let message = IPMSGMessageBuilder()
            .setSender(name: "Alice", host: "iPhone")
            .setCommand(.sendMsg, options: [.sendCheck, .utf8])
            .setAdditionalData("Hello")
            .build()
        
        XCTAssertEqual(message.senderName, "Alice")
        XCTAssertEqual(message.senderHost, "iPhone")
        XCTAssertEqual(message.pureCommand, IPMSGCommand.sendMsg.rawValue)
        XCTAssertTrue(message.hasOptionSendCheck)
        XCTAssertTrue(message.hasOptionUTF8)
        XCTAssertEqual(message.additionalData, "Hello")
    }
}

import SwiftUI

// MARK: - macOS 聊天界面

struct ChatView: View {
    @ObservedObject var user: LANUser
    @EnvironmentObject var manager: FeiQiuManager
    
    @State private var messageText: String = ""
    @FocusState private var isInputFocused: Bool
    
    var messages: [ChatMessage] {
        manager.chatMessages(for: user)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶栏 - 用户信息
            chatHeader
            
            Divider()
            
            // 消息列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(messages) { msg in
                            MessageBubble(message: msg, user: user)
                                .id(msg.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // 输入区域
            inputArea
        }
        .onAppear {
            markAllAsRead()
        }
    }
    
    // MARK: - 聊天顶栏
    
    private var chatHeader: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(user.name.prefix(1)))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 1) {
                Text(user.displayName)
                    .font(.system(size: 14, weight: .medium))
                HStack(spacing: 4) {
                    Circle().fill(Color(user.status.tintColor)).frame(width: 6, height: 6)
                    Text(user.status.localizedString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(user.ipAddress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 操作按钮
            Button {
                // TODO: 发送文件
            } label: {
                Image(systemName: "paperclip")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("发送文件")
            
            Button {
                // 打开传输窗口
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.network") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down.circle")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("文件传输")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - 输入区域
    
    private var inputArea: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack(spacing: 12) {
                Button { /* TODO: 发送文件 */ } label: {
                    Image(systemName: "folder")
                }
                .help("发送文件")
                
                Button { /* TODO: 发送图片 */ } label: {
                    Image(systemName: "photo")
                }
                .help("发送图片")
                
                Button { /* TODO: 截图 */ } label: {
                    Image(systemName: "scissors")
                }
                .help("截图")
                
                Spacer()
                
                Text("\(messageText.count) 字")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            
            // 文本输入框
            TextEditor(text: $messageText)
                .font(.system(size: 14))
                .frame(minHeight: 60, maxHeight: 120)
                .padding(.horizontal, 8)
                .scrollContentBackground(.hidden)
                .focused($isInputFocused)
            
            // 发送按钮
            HStack {
                Spacer()
                Button("发送") {
                    sendMessage()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Button("关闭") {
                    isInputFocused = false
                }
                .keyboardShortcut(.escape)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    // MARK: - 方法
    
    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        manager.sendText(trimmed, to: user)
        messageText = ""
    }
    
    private func markAllAsRead() {
        for msg in messages where msg.direction == .received {
            msg.isRead = true
        }
    }
}

// MARK: - macOS 消息气泡

struct MessageBubble: View {
    let message: ChatMessage
    let user: LANUser
    
    private var isSent: Bool { message.direction == .sent }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 收到的消息: 左侧头像
            if !isSent {
                avatarView
            }
            
            VStack(alignment: isSent ? .trailing : .leading, spacing: 3) {
                // 发送者名（仅收到的消息显示）
                if !isSent {
                    Text(user.name)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                // 消息气泡
                Text(message.content)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isSent ? Color.orange : Color(nsColor: .controlBackgroundColor))
                    .foregroundColor(isSent ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .textSelection(.enabled)
                
                // 附件
                if let attachments = message.attachments, !attachments.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(attachments, id: \.fileID) { att in
                            FileAttachmentRow(attachment: att, isSent: isSent)
                        }
                    }
                }
                
                // 时间 + 状态
                HStack(spacing: 4) {
                    Text(message.timestamp, style: .time)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    if isSent {
                        statusIcon
                    }
                }
            }
            
            // 发出的消息: 右侧头像
            if isSent {
                avatarView
            }
        }
        .frame(maxWidth: .infinity, alignment: isSent ? .trailing : .leading)
    }
    
    private var avatarView: some View {
        Circle()
            .fill(isSent ? Color.blue : Color.orange)
            .frame(width: 28, height: 28)
            .overlay(
                Text(String((isSent ? "我" : user.name).prefix(1)))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
            )
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        if message.isRead {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundColor(.blue)
        } else if message.isConfirmed {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        } else {
            Image(systemName: "circle")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 文件附件行

struct FileAttachmentRow: View {
    let attachment: IPMSGFileAttachment
    let isSent: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: attachment.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundColor(.orange)
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 1) {
                Text(attachment.fileName)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.fileSize), countStyle: .file))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !isSent {
                Button {
                    // TODO: 下载文件
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.plain)
                .help("下载文件")
            }
        }
        .padding(6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .frame(maxWidth: 250)
    }
}

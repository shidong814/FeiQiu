import SwiftUI

// MARK: - 聊天界面

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
            // 消息列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // 输入栏
            inputBar
        }
        .navigationTitle(user.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        // 发送文件（占位）
                    } label: {
                        Label("发送文件", systemImage: "doc")
                    }
                    Button {
                        // 发送图片（占位）
                    } label: {
                        Label("发送图片", systemImage: "photo")
                    }
                } label: {
                    Image(systemName: "plus.circle")
                }
            }
        }
        .onAppear {
            markAllAsRead()
        }
    }
    
    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("输入消息...", text: $messageText, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .focused($isInputFocused)
            
            Button {
                sendMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(messageText.isEmpty ? .gray : .white)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(messageText.isEmpty ? Color.gray.opacity(0.3) : .orange)
                    )
            }
            .disabled(messageText.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 0.5)
        }
    }
    
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

// MARK: - 消息气泡

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.direction == .sent { Spacer(minLength: 60) }
            
            VStack(alignment: message.direction == .sent ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(bubbleColor)
                    .foregroundColor(textColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // 附件
                if let attachments = message.attachments, !attachments.isEmpty {
                    ForEach(attachments, id: \.fileID) { att in
                        FileAttachmentRow(attachment: att)
                    }
                }
                
                // 时间 + 状态
                HStack(spacing: 4) {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if message.direction == .sent {
                        if message.isRead {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        } else if message.isConfirmed {
                            Image(systemName: "checkmark.circle")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Image(systemName: "circle")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            if message.direction == .received { Spacer(minLength: 60) }
        }
    }
    
    private var bubbleColor: Color {
        message.direction == .sent ? .orange : Color(.systemGray5)
    }
    
    private var textColor: Color {
        message.direction == .sent ? .white : .primary
    }
}

// MARK: - 文件附件行

struct FileAttachmentRow: View {
    let attachment: IPMSGFileAttachment
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: attachment.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.fileName)
                    .font(.caption)
                    .lineLimit(1)
                Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.fileSize), countStyle: .file))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                // TODO: 下载文件
            } label: {
                Image(systemName: "arrow.down.circle")
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

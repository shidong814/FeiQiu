import SwiftUI

// MARK: - macOS 主窗口（三栏布局）

struct MainWindow: View {
    @EnvironmentObject var manager: FeiQiuManager
    @State private var selectedUser: LANUser?
    @State private var showTransferWindow = false
    
    var body: some View {
        NavigationSplitView {
            // 左侧: 用户列表
            SidebarView(selectedUser: $selectedUser)
        } detail: {
            // 右侧: 聊天界面
            if let user = selectedUser {
                ChatView(user: user)
            } else {
                EmptyChatView()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    manager.refreshUserList()
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .help("刷新用户列表")
                
                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.network") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("网络", systemImage: "network")
                }
                .help("网络设置")
            }
        }
    }
}

// MARK: - 侧边栏用户列表

struct SidebarView: View {
    @EnvironmentObject var manager: FeiQiuManager
    @Binding var selectedUser: LANUser?
    @State private var searchText = ""
    
    var filteredUsers: [LANUser] {
        if searchText.isEmpty {
            return manager.users
        }
        return manager.users.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.ipAddress.contains(searchText) ||
            $0.groupName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // 按分组聚合
    var groupedUsers: [(String, [LANUser])] {
        let groups = Dictionary(grouping: filteredUsers) { $0.groupName.isEmpty ? "未分组" : $0.groupName }
        return groups.sorted { $0.key < $1.key }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索框
            SearchField(text: $searchText, placeholder: "搜索用户...")
                .padding(8)
            
            // 用户列表
            List(selection: $selectedUser) {
                ForEach(groupedUsers, id: \.0) { groupName, users in
                    Section(groupName) {
                        ForEach(users) { user in
                            UserRow(user: user)
                                .tag(user)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            
            // 底部状态栏
            HStack {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 8, height: 8)
                Text(manager.localIPAddress.isEmpty ? "未连接" : manager.localIPAddress)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(manager.users.count) 人在线")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }
    
    private var connectionColor: Color {
        switch manager.connectionState {
        case .connected: return .green
        case .connecting: return .yellow
        case .disconnected: return .gray
        case .failed: return .red
        }
    }
}

// MARK: - macOS 风格搜索框

struct SearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    
    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.bezelStyle = .roundRect
        field.focusRingType = .default
        return field
    }
    
    func updateNSView(_ nsView: NSSearchField, context: Context) {
        nsView.stringValue = text
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: SearchField
        
        init(_ parent: SearchField) { self.parent = parent }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }
    }
}

// MARK: - macOS 用户行

struct UserRow: View {
    @ObservedObject var user: LANUser
    @EnvironmentObject var manager: FeiQiuManager
    
    var body: some View {
        HStack(spacing: 10) {
            // 头像
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(avatarGradient)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(user.name.prefix(1)))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    )
                
                // 状态指示灯
                Circle()
                    .fill(Color(user.status.tintColor))
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color(nsColor: .controlBackgroundColor), lineWidth: 1.5))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                
                Text(user.ipAddress)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 未读数
            let unreadCount = manager.chatMessages(for: user)
                .filter { $0.direction == .received && !$0.isRead }
                .count
            
            if unreadCount > 0 {
                Text("\(unreadCount)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }
    
    private var avatarGradient: LinearGradient {
        let colors: [Color] = [.orange, .pink]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - 空聊天界面

struct EmptyChatView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("选择用户开始聊天")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("从左侧选择一个在线用户")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

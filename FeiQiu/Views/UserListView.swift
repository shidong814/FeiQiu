import SwiftUI

// MARK: - 用户列表界面

struct UserListView: View {
    @EnvironmentObject var manager: FeiQiuManager
    
    var body: some View {
        Group {
            if manager.users.isEmpty {
                emptyState
            } else {
                userList
            }
        }
        .navigationTitle("局域网用户")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                connectionStatus
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    manager.refreshUserList()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }
    
    private var connectionStatus: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)
            Text(manager.localIPAddress)
                .font(.caption2)
                .foregroundColor(.secondary)
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
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("没有发现局域网用户")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("请确认网络连接，对方已开启飞秋")
                .font(.caption)
                .foregroundColor(.secondary)
            Button("刷新") {
                manager.refreshUserList()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
    }
    
    private var userList: some View {
        List {
            ForEach(manager.users) { user in
                NavigationLink {
                    ChatView(user: user)
                } label: {
                    UserRow(user: user)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            manager.refreshUserList()
        }
    }
}

// MARK: - 用户行

struct UserRow: View {
    @ObservedObject var user: LANUser
    @EnvironmentObject var manager: FeiQiuManager
    
    var body: some View {
        HStack(spacing: 12) {
            // 头像 + 状态
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(LinearGradient(
                        colors: [.orange, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(user.name.prefix(1)))
                            .font(.headline)
                            .foregroundColor(.white)
                    )
                
                Circle()
                    .fill(Color(user.status.tintColor))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle().stroke(Color(.systemBackground), lineWidth: 2)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.headline)
                
                HStack(spacing: 4) {
                    Image(systemName: "network")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(user.ipAddress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 未读消息数
            let unreadCount = manager.chatMessages(for: user)
                .filter { $0.direction == .received && !$0.isRead }
                .count
            
            if unreadCount > 0 {
                Text("\(unreadCount)")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

import SwiftUI

// MARK: - 设置界面

struct SettingsView: View {
    @EnvironmentObject var manager: FeiQiuManager
    
    var body: some View {
        Form {
            Section("个人信息") {
                HStack {
                    Text("昵称")
                    Spacer()
                    TextField("您的昵称", text: $manager.userName)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("分组")
                    Spacer()
                    TextField("可选", text: $manager.groupName)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("连接信息") {
                HStack {
                    Text("本机 IP")
                    Spacer()
                    Text(manager.localIPAddress.isEmpty ? "未知" : manager.localIPAddress)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("协议端口")
                    Spacer()
                    Text("2425 (UDP/TCP)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("协议版本")
                    Spacer()
                    Text("IPMSG v1 (飞秋兼容)")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("操作") {
                Button {
                    manager.refreshUserList()
                } label: {
                    Label("重新广播上线", systemImage: "antenna.radiowaves.left.and.right")
                }
                
                Button(role: .destructive) {
                    manager.stop()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        manager.start()
                    }
                } label: {
                    Label("重启服务", systemImage: "arrow.clockwise.circle")
                }
            }
            
            Section("关于") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("0.1.0 (Beta)").foregroundColor(.secondary)
                }
                
                Link(destination: URL(string: "https://ipmsg.org/")!) {
                    HStack {
                        Text("IPMSG 协议")
                        Spacer()
                        Image(systemName: "link")
                    }
                }
            }
        }
        .navigationTitle("设置")
    }
}

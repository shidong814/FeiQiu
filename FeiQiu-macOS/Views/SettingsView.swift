import SwiftUI

// MARK: - macOS 设置界面

struct SettingsView: View {
    @EnvironmentObject var manager: FeiQiuManager
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("通用", systemImage: "gear") }
            
            NetworkSettingsView()
                .tabItem { Label("网络", systemImage: "network") }
            
            AboutSettingsView()
                .tabItem { Label("关于", systemImage: "info.circle") }
        }
        .frame(width: 450, height: 320)
    }
}

// MARK: - 通用设置

struct GeneralSettingsView: View {
    @EnvironmentObject var manager: FeiQiuManager
    
    var body: some View {
        Form {
            Section("个人信息") {
                TextField("昵称", text: $manager.userName)
                    .textFieldStyle(.roundedBorder)
                
                TextField("分组", text: $manager.groupName)
                    .textFieldStyle(.roundedBorder)
            }
            
            Section("启动") {
                Toggle("开机自动启动", isOn: .constant(false))
                Toggle("启动时最小化到菜单栏", isOn: .constant(false))
            }
        }
        .padding(20)
    }
}

// MARK: - 网络设置

struct NetworkSettingsView: View {
    @EnvironmentObject var manager: FeiQiuManager
    
    var body: some View {
        Form {
            Section("连接信息") {
                HStack {
                    Text("本机 IP")
                    Spacer()
                    Text(manager.localIPAddress.isEmpty ? "未连接" : manager.localIPAddress)
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
                    Text("IPMSG v1")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("操作") {
                Button("重新广播上线") {
                    manager.refreshUserList()
                }
                
                Button("重启服务") {
                    manager.stop()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        manager.start()
                    }
                }
            }
        }
        .padding(20)
    }
}

// MARK: - 关于

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("飞秋")
                .font(.system(size: 24, weight: .bold))
            
            Text("macOS 版 v0.1.0 (Beta)")
                .foregroundColor(.secondary)
            
            Text("兼容 IPMSG / 飞鸽传书协议")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
                .frame(width: 200)
            
            Link("IPMSG 协议规范", destination: URL(string: "https://ipmsg.org/")!)
            
            Text("与 Windows 飞秋、飞鸽传书互通")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

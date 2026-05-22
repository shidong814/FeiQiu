import SwiftUI

@main
struct FeiQiuApp: App {
    @StateObject private var manager = FeiQiuManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(manager)
                .onAppear {
                    manager.start()
                }
                .onDisappear {
                    manager.stop()
                }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationView {
                UserListView()
            }
            .tabItem {
                Label("用户", systemImage: "person.2.fill")
            }
            
            NavigationView {
                TransferListView()
            }
            .tabItem {
                Label("传输", systemImage: "arrow.up.arrow.down.circle.fill")
            }
            
            NavigationView {
                SettingsView()
            }
            .tabItem {
                Label("设置", systemImage: "gear")
            }
        }
        .tint(.orange)
    }
}

import SwiftUI

@main
struct FeiQiuApp: App {
    @StateObject private var manager = FeiQiuManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // 主窗口 - 用户列表 + 聊天
        WindowGroup {
            MainWindow()
                .environmentObject(manager)
                .frame(minWidth: 800, minHeight: 500)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 900, height: 600)
        
        // 设置窗口
        Settings {
            SettingsView()
                .environmentObject(manager)
                .frame(width: 450, height: 350)
        }
        
        // 文件传输窗口
        Window("文件传输", id: "transfers") {
            TransferListView()
                .environmentObject(manager)
                .frame(minWidth: 500, minHeight: 300)
        }
    }
}

// MARK: - App Delegate（菜单栏状态图标）

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 菜单栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bubble.left.and.bubble.right", accessibilityDescription: "飞秋")
            button.image?.size = NSSize(width: 18, height: 18)
        }
        
        let menu = NSMenu()
        menu.addItem(withTitle: "打开飞秋", action: #selector(showMainWindow), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "刷新用户列表", action: #selector(refreshUsers), keyEquivalent: "r")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出飞秋", action: #selector(quitApp), keyEquivalent: "q")
        
        statusItem.menu = menu
        
        // 启动服务
        FeiQiuManager.shared.start()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        FeiQiuManager.shared.stop()
    }
    
    @objc func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.isVisible }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc func refreshUsers() {
        FeiQiuManager.shared.refreshUserList()
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

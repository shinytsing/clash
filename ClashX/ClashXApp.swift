import SwiftUI

@main
struct ClashXApp: App {
    @StateObject private var menuBarController = MenuBarController()
    @StateObject private var configManager = ConfigManager()
    @StateObject private var proxyManager = ProxyManager()
    @StateObject private var nodeManager = NodeManager()
    
    var body: some Scene {
        // 主窗口场景
        WindowGroup {
            ContentView()
                .environmentObject(configManager)
                .environmentObject(proxyManager)
                .environmentObject(nodeManager)
                .frame(width: 800, height: 600)
        }
        .commands {
            // 移除不需要的菜单项
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .undoRedo) { }
            CommandGroup(replacing: .pasteboard) { }
        }
        
        // 菜单栏额外设置 - 只在 macOS 13.0+ 支持
        if #available(macOS 13.0, *) {
            MenuBarExtra("ClashX", systemImage: "network") {
                MenuBarView()
                    .environmentObject(configManager)
                    .environmentObject(proxyManager)
                    .environmentObject(nodeManager)
            }
            .menuBarExtraStyle(.menu)
        }
    }
}

// 菜单栏视图
struct MenuBarView: View {
    @EnvironmentObject var configManager: ConfigManager
    @EnvironmentObject var proxyManager: ProxyManager
    @EnvironmentObject var nodeManager: NodeManager
    // openWindow 只在 macOS 13.0+ 可用
    @available(macOS 13.0, *)
    private var openWindow: OpenWindowAction? {
        return nil // 暂时使用 nil，实际使用时需要正确注入
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 代理状态
            VStack {
                HStack {
                    Circle()
                        .fill(proxyManager.isRunning ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(proxyManager.isRunning ? "代理已启用" : "代理已停用")
                        .font(.system(size: 12))
                    Spacer()
                    Text(proxyManager.currentMode.rawValue)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                
                if proxyManager.isRunning {
                    HStack {
                        Image(systemName: "arrow.up")
                            .foregroundColor(.blue)
                        Text(proxyManager.uploadSpeed)
                        Image(systemName: "arrow.down")
                            .foregroundColor(.green)
                        Text(proxyManager.downloadSpeed)
                        Spacer()
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                }
            }
            
            Divider()
            
            // 代理控制
            VStack {
                Button(action: {
                    Task {
                        await proxyManager.toggleProxy()
                    }
                }) {
                    HStack {
                        Image(systemName: proxyManager.isRunning ? "stop.circle" : "play.circle")
                        Text(proxyManager.isRunning ? "停止代理" : "启动代理")
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                
                // 模式切换
                Menu("模式: \(proxyManager.currentMode.rawValue)") {
                    ForEach(ProxyMode.allCases, id: \.self) { mode in
                        Button(mode.rawValue) {
                            Task {
                                await proxyManager.setMode(mode)
                            }
                        }
                    }
                }
                .menuStyle(.borderlessButton)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
            
            Divider()
            
            // 节点选择
            if !nodeManager.nodes.isEmpty {
                Menu("节点选择") {
                    ForEach(nodeManager.nodes, id: \.name) { node in
                        Button(action: {
                            Task {
                                await nodeManager.selectNode(node)
                            }
                        }) {
                            HStack {
                                Text(node.name)
                                Spacer()
                                if let delay = node.delay {
                                    Text("\(delay)ms")
                                        .foregroundColor(delay < 200 ? .green : delay < 500 ? .orange : .red)
                                }
                                if nodeManager.selectedNode?.name == node.name {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                .menuStyle(.borderlessButton)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                
                Button("测试延迟") {
                    Task {
                        await nodeManager.testAllNodesDelay()
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                
                Divider()
            }
            
            // 配置管理
            VStack {
                Button("配置管理") {
                    // 显示主窗口的逻辑
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                
                Button("更新配置") {
                    Task {
                        await configManager.updateSubscription()
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
            
            Divider()
            
            // 应用控制
            Button("退出 ClashX") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .frame(width: 220)
    }
}

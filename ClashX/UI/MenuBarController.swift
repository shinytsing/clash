import SwiftUI
import Cocoa

/// 菜单栏控制器
/// 负责管理菜单栏图标和状态显示
class MenuBarController: NSObject, ObservableObject {
    // MARK: - 属性
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    
    @Published var isMenuVisible = false
    
    // MARK: - 初始化
    override init() {
        super.init()
        setupMenuBar()
    }
    
    // MARK: - 菜单栏设置
    
    private func setupMenuBar() {
        // 创建状态栏项
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // 设置图标
            if let image = NSImage(systemSymbolName: "network", accessibilityDescription: "ClashX") {
                image.size = NSSize(width: 16, height: 16)
                button.image = image
            } else {
                button.title = "ClashX"
            }
            
            // 设置点击事件
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // 创建弹出窗口
        setupPopover()
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 400)
        popover?.behavior = .transient
        popover?.delegate = self
        
        // 设置内容视图
        let contentView = MenuBarContentView()
        popover?.contentViewController = NSHostingController(rootView: contentView)
    }
    
    // MARK: - 事件处理
    
    @objc private func statusItemClicked() {
        guard let button = statusItem?.button else { return }
        
        let event = NSApp.currentEvent!
        
        if event.type == .rightMouseUp {
            // 右键点击显示上下文菜单
            showContextMenu()
        } else {
            // 左键点击切换弹出窗口
            togglePopover()
        }
    }
    
    private func togglePopover() {
        guard let button = statusItem?.button,
              let popover = popover else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // 激活应用以获得焦点
            NSApp.activate(ignoringOtherApps: true)
        }
        
        isMenuVisible = popover.isShown
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        
        // 添加菜单项
        menu.addItem(NSMenuItem(title: "显示主窗口", action: #selector(showMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "偏好设置...", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出 ClashX", action: #selector(quitApp), keyEquivalent: "q"))
        
        // 设置目标
        for item in menu.items {
            item.target = self
        }
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }
    
    // MARK: - 菜单动作
    
    @objc private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        // 这里应该显示主窗口
    }
    
    @objc private func showPreferences() {
        NSApp.activate(ignoringOtherApps: true)
        // 这里应该显示偏好设置窗口
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    // MARK: - 状态更新
    
    /// 更新菜单栏图标状态
    func updateStatus(isRunning: Bool) {
        guard let button = statusItem?.button else { return }
        
        DispatchQueue.main.async {
            if let image = NSImage(systemSymbolName: isRunning ? "network" : "network.slash", 
                                 accessibilityDescription: isRunning ? "代理运行中" : "代理已停止") {
                image.size = NSSize(width: 16, height: 16)
                button.image = image
            }
            
            // 更新工具提示
            button.toolTip = isRunning ? "ClashX - 代理运行中" : "ClashX - 代理已停止"
        }
    }
    
    // MARK: - 清理
    
    deinit {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }
}

// MARK: - NSPopoverDelegate

extension MenuBarController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        isMenuVisible = false
    }
    
    func popoverDidShow(_ notification: Notification) {
        isMenuVisible = true
    }
}

// MARK: - 菜单栏内容视图

struct MenuBarContentView: View {
    @StateObject private var proxyManager = ProxyManager()
    @StateObject private var nodeManager = NodeManager()
    @StateObject private var configManager = ConfigManager()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 头部状态
            HeaderStatusView()
                .environmentObject(proxyManager)
            
            Divider()
            
            // 代理控制
            ProxyControlView()
                .environmentObject(proxyManager)
            
            Divider()
            
            // 节点选择
            NodeSelectionView()
                .environmentObject(nodeManager)
            
            Divider()
            
            // 底部操作
            BottomActionsView()
                .environmentObject(configManager)
        }
        .frame(width: 280)
        .onAppear {
            Task {
                await nodeManager.loadNodes()
            }
        }
    }
}

// MARK: - 子视图组件

struct HeaderStatusView: View {
    @EnvironmentObject var proxyManager: ProxyManager
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(proxyManager.isRunning ? .green : .red)
                    .frame(width: 10, height: 10)
                Text(proxyManager.isRunning ? "代理运行中" : "代理已停止")
                    .font(.headline)
                Spacer()
                Text(proxyManager.currentMode.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2))
                    .cornerRadius(4)
            }
            
            if proxyManager.isRunning {
                HStack {
                    VStack(alignment: .leading) {
                        Text("上传")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Image(systemName: "arrow.up")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(proxyManager.uploadSpeed)
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("下载")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Text(proxyManager.downloadSpeed)
                                .font(.system(.caption, design: .monospaced))
                            Image(systemName: "arrow.down")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

struct ProxyControlView: View {
    @EnvironmentObject var proxyManager: ProxyManager
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: {
                Task {
                    await proxyManager.toggleProxy()
                }
            }) {
                HStack {
                    Image(systemName: proxyManager.isRunning ? "stop.circle.fill" : "play.circle.fill")
                    Text(proxyManager.isRunning ? "停止代理" : "启动代理")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
            // 模式选择
            HStack {
                Text("模式:")
                    .foregroundColor(.secondary)
                Spacer()
                Picker("", selection: .constant(proxyManager.currentMode)) {
                    ForEach(ProxyMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
            }
        }
        .padding()
    }
}

struct NodeSelectionView: View {
    @EnvironmentObject var nodeManager: NodeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("节点选择")
                    .font(.headline)
                Spacer()
                Button("测试") {
                    Task {
                        await nodeManager.testAllNodesDelay()
                    }
                }
                .disabled(nodeManager.isTesting)
                .font(.caption)
            }
            
            if nodeManager.nodes.isEmpty {
                Text("暂无节点")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical)
            } else {
                LazyVStack(spacing: 4) {
                    ForEach(nodeManager.nodes.prefix(5), id: \.name) { node in
                        NodeRowView(node: node)
                    }
                    
                    if nodeManager.nodes.count > 5 {
                        Text("还有 \(nodeManager.nodes.count - 5) 个节点...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
        .padding()
    }
}

struct NodeRowView: View {
    let node: ProxyNode
    @EnvironmentObject var nodeManager: NodeManager
    
    var body: some View {
        Button(action: {
            Task {
                await nodeManager.selectNode(node)
            }
        }) {
            HStack {
                Circle()
                    .fill(nodeManager.selectedNode?.name == node.name ? Color.accentColor : Color.clear)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(Color.secondary, lineWidth: 1)
                    )
                
                Text(node.name)
                    .font(.caption)
                
                Spacer()
                
                if let delay = node.delay {
                    Text("\(delay)ms")
                        .font(.caption2)
                        .foregroundColor(delay < 200 ? .green : delay < 500 ? .orange : .red)
                } else {
                    Text("-")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct BottomActionsView: View {
    @EnvironmentObject var configManager: ConfigManager
    
    var body: some View {
        VStack(spacing: 8) {
            Button("配置管理") {
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.plain)
            
            Button("更新配置") {
                Task {
                    await configManager.updateSubscription()
                }
            }
            .buttonStyle(.plain)
            .disabled(configManager.isUpdating)
            
            Divider()
            
            Button("退出 ClashX") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}
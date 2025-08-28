import SwiftUI
import AppKit
import Combine

/// 菜单栏控制器
/// 负责管理菜单栏图标、状态显示和快捷操作
class MenuBarController: ObservableObject {
    // MARK: - 属性
    @Published var isVisible = true
    @Published var statusItemImage: NSImage?
    
    private var statusItem: NSStatusItem?
    private let proxyManager = ProxyManager()
    private let nodeManager = NodeManager()
    private let configManager = ConfigManager()
    
    // MARK: - 初始化
    init() {
        setupStatusItem()
        setupBindings()
    }
    
    // MARK: - 状态栏设置
    
    private func setupStatusItem() {
        // 创建状态栏项目
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let statusItem = statusItem else { return }
        
        // 设置初始图标
        updateStatusIcon()
        
        // 设置点击行为 - 使用 SwiftUI 菜单
        if let button = statusItem.button {
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    @objc private func statusItemClicked() {
        // 这里可以处理点击事件，但主要逻辑在 SwiftUI 中
        print("状态栏图标被点击")
    }
    
    private func setupBindings() {
        // 监听代理状态变化
        proxyManager.$isRunning.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateStatusIcon()
                self?.updateStatusTitle()
            }
        }
        .store(in: &cancellables)
        
        // 监听上传下载速度
        proxyManager.$uploadSpeed.combineLatest(proxyManager.$downloadSpeed)
            .sink { [weak self] _, _ in
                DispatchQueue.main.async {
                    self?.updateStatusTitle()
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 图标更新
    
    private func updateStatusIcon() {
        guard let statusItem = statusItem else { return }
        
        let iconName = proxyManager.isRunning ? "wifi" : "wifi.slash"
        let image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        
        // 设置图标大小
        image?.size = NSSize(width: 18, height: 18)
        
        // 根据状态设置颜色
        if proxyManager.isRunning {
            image?.isTemplate = true
        } else {
            image?.isTemplate = true
        }
        
        statusItem.button?.image = image
        statusItemImage = image
    }
    
    private func updateStatusTitle() {
        guard let statusItem = statusItem else { return }
        
        var title = ""
        
        if proxyManager.isRunning {
            // 显示上传下载速度
            let upload = proxyManager.uploadSpeed
            let download = proxyManager.downloadSpeed
            
            // 如果速度为0，不显示速度信息
            if upload != "0 B/s" || download != "0 B/s" {
                title = "↑\(upload) ↓\(download)"
            }
        }
        
        statusItem.button?.title = title
    }
    
    // MARK: - 菜单项操作
    
    /// 切换代理状态
    func toggleProxy() {
        Task {
            await proxyManager.toggleProxy()
        }
    }
    
    /// 切换代理模式
    func switchMode(_ mode: ProxyMode) {
        Task {
            await proxyManager.setMode(mode)
        }
    }
    
    /// 选择节点
    func selectNode(_ node: ProxyNode) {
        Task {
            await nodeManager.selectNode(node)
        }
    }
    
    /// 测试所有节点延迟
    func testAllNodes() {
        Task {
            await nodeManager.testAllNodesDelay()
        }
    }
    
    /// 更新配置
    func updateConfig() {
        Task {
            await configManager.updateSubscription()
        }
    }
    
    /// 打开主窗口
    func openMainWindow() {
        // 通过通知或其他方式打开主窗口
        NotificationCenter.default.post(name: .openMainWindow, object: nil)
    }
    
    /// 退出应用
    func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - 菜单栏可见性
    
    func showStatusItem() {
        statusItem?.isVisible = true
        isVisible = true
    }
    
    func hideStatusItem() {
        statusItem?.isVisible = false
        isVisible = false
    }
    
    // MARK: - 清理
    
    deinit {
        statusItem = nil
    }
}

// MARK: - 通知扩展

extension Notification.Name {
    static let openMainWindow = Notification.Name("openMainWindow")
}

// MARK: - 菜单栏额外功能

extension MenuBarController {
    /// 显示快速设置菜单
    func showQuickSettings() {
        // 这里可以实现一个快速设置的弹出菜单
        // 包含常用的代理模式切换、节点选择等
    }
    
    /// 显示网络状态信息
    func showNetworkStatus() {
        let alert = NSAlert()
        alert.messageText = "网络状态"
        
        let stats = proxyManager.getProxyStats()
        alert.informativeText = """
        代理状态: \(proxyManager.isRunning ? "运行中" : "已停止")
        当前模式: \(proxyManager.currentMode.rawValue)
        上传流量: \(stats.totalUpload)
        下载流量: \(stats.totalDownload)
        运行时间: \(stats.uptime)
        """
        
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
    
    /// 复制代理信息到剪贴板
    func copyProxyInfo() {
        let proxyInfo = """
        HTTP 代理: 127.0.0.1:\(ClashCore.shared.httpPort)
        SOCKS 代理: 127.0.0.1:\(ClashCore.shared.socksPort)
        """
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(proxyInfo, forType: .string)
        
        // 显示提示
        showTemporaryMessage("代理信息已复制到剪贴板")
    }
    
    /// 显示临时消息
    private func showTemporaryMessage(_ message: String) {
        // 在状态栏显示临时消息
        let originalTitle = statusItem?.button?.title
        statusItem?.button?.title = message
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.statusItem?.button?.title = originalTitle
        }
    }
}

// MARK: - 菜单构建辅助

extension MenuBarController {
    /// 构建代理模式菜单项
    func buildModeMenuItems() -> [NSMenuItem] {
        return ProxyMode.allCases.map { mode in
            let item = NSMenuItem(
                title: mode.rawValue,
                action: #selector(modeMenuItemClicked(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = ProxyMode.allCases.firstIndex(of: mode) ?? 0
            item.state = proxyManager.currentMode == mode ? .on : .off
            return item
        }
    }
    
    @objc private func modeMenuItemClicked(_ sender: NSMenuItem) {
        let mode = ProxyMode.allCases[sender.tag]
        switchMode(mode)
    }
    
    /// 构建节点选择菜单项
    func buildNodeMenuItems() -> [NSMenuItem] {
        let nodes = nodeManager.nodes.prefix(20) // 限制显示数量
        
        return nodes.map { node in
            let item = NSMenuItem(
                title: formatNodeTitle(node),
                action: #selector(nodeMenuItemClicked(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = node
            item.state = nodeManager.selectedNode?.name == node.name ? .on : .off
            return item
        }
    }
    
    @objc private func nodeMenuItemClicked(_ sender: NSMenuItem) {
        guard let node = sender.representedObject as? ProxyNode else { return }
        selectNode(node)
    }
    
    /// 格式化节点标题
    private func formatNodeTitle(_ node: ProxyNode) -> String {
        var title = node.name
        
        if let delay = node.delay {
            title += " (\(delay)ms)"
        }
        
        return title
    }
}

// MARK: - 系统集成

extension MenuBarController {
    /// 设置开机自启动
    func setLoginItem(enabled: Bool) {
        let bundleIdentifier = Bundle.main.bundleIdentifier!
        
        if enabled {
            // 添加到登录项
            let script = """
            tell application "System Events"
                make login item at end with properties {path:"\(Bundle.main.bundlePath)", hidden:false}
            end tell
            """
            
            runAppleScript(script)
        } else {
            // 从登录项移除
            let script = """
            tell application "System Events"
                delete login item "\(Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "ClashX")"
            end tell
            """
            
            runAppleScript(script)
        }
    }
    
    private func runAppleScript(_ script: String) {
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            print("AppleScript 执行失败: \(error)")
        }
    }
    
    /// 检查是否已设置为开机自启动
    func isLoginItemEnabled() -> Bool {
        // 检查登录项中是否包含当前应用
        let script = """
        tell application "System Events"
            get the name of every login item
        end tell
        """
        
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        let result = appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            print("检查登录项失败: \(error)")
            return false
        }
        
        // 简化的检查逻辑
        return false
    }
}

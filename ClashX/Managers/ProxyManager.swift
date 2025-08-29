import Foundation
import Combine
import SystemConfiguration
import UserNotifications

/// 代理管理器
/// 负责代理的启停控制、模式切换和系统代理设置
class ProxyManager: ObservableObject {
    // MARK: - 属性
    @Published var isRunning = false
    @Published var currentMode: ProxyMode = .rule
    @Published var uploadSpeed = "0 B/s"
    @Published var downloadSpeed = "0 B/s"
    @Published var isSystemProxyEnabled = false
    
    private var cancellables = Set<AnyCancellable>()
    private let networkManager = NetworkManager.shared
    
    // 系统代理设置
    private var originalProxySettings: SystemProxySettings?
    
    // MARK: - 初始化
    init() {
        setupBindings()
        loadSettings()
    }
    
    // MARK: - 设置绑定
    
    private func setupBindings() {
        // 绑定网络管理器的速度信息
        networkManager.$uploadSpeed
            .receive(on: DispatchQueue.main)
            .assign(to: \.uploadSpeed, on: self)
            .store(in: &cancellables)
        
        networkManager.$downloadSpeed
            .receive(on: DispatchQueue.main)
            .assign(to: \.downloadSpeed, on: self)
            .store(in: &cancellables)
        
        // 监听 Clash 核心状态
        ClashCore.shared.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRunning in
                self?.isRunning = isRunning
                if isRunning {
                    self?.networkManager.startTrafficMonitoring()
                } else {
                    self?.networkManager.stopTrafficMonitoring()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 代理控制
    
    /// 切换代理状态
    func toggleProxy() async {
        if isRunning {
            await stopProxy()
        } else {
            await startProxy()
        }
    }
    
    /// 启动代理
    func startProxy() async {
        guard !isRunning else { return }
        
        do {
            // 获取当前配置路径
            guard let configPath = getConfigPath() else {
                throw ClashError.configNotFound
            }
            
            // 启动 Clash 核心
            try await ClashCore.shared.start(configPath: configPath)
            
            // 设置系统代理
            if isSystemProxyEnabled {
                try setSystemProxy(enabled: true)
            }
            
            // 发送通知
            sendNotification(title: "ClashX", message: "代理已启动")
            
        } catch {
            print("启动代理失败: \(error)")
            sendNotification(title: "ClashX", message: "代理启动失败: \(error.localizedDescription)")
        }
    }
    
    /// 停止代理
    func stopProxy() async {
        guard isRunning else { return }
        
        // 停止 Clash 核心
        ClashCore.shared.stop()
        
        // 恢复系统代理设置
        if isSystemProxyEnabled {
            try? setSystemProxy(enabled: false)
        }
        
        // 发送通知
        sendNotification(title: "ClashX", message: "代理已停止")
    }
    
    // MARK: - 模式切换
    
    /// 设置代理模式
    func setMode(_ mode: ProxyMode) async {
        guard isRunning else {
            currentMode = mode
            saveSettings()
            return
        }
        
        do {
            try await ClashCore.shared.patch("/configs", json: ["mode": mode.clashMode])
            
            await MainActor.run {
                currentMode = mode
                saveSettings()
            }
            
            print("代理模式已切换到: \(mode.rawValue)")
        } catch {
            print("切换代理模式失败: \(error)")
        }
    }
    
    // MARK: - 系统代理设置
    
    /// 设置系统代理
    func setSystemProxy(enabled: Bool) throws {
        if enabled {
            // 保存原始设置
            originalProxySettings = SystemProxyHelper.getCurrentProxySettings()
            
            // 启用 ClashX 代理
            try SystemProxyHelper.enableClashProxy()
            
        } else {
            // 禁用系统代理
            try SystemProxyHelper.disableSystemProxy()
            originalProxySettings = nil
        }
        
        isSystemProxyEnabled = enabled
        saveSettings()
    }
    
    /// 检查系统代理状态
    func checkSystemProxyStatus() {
        isSystemProxyEnabled = SystemProxyHelper.isClashProxyEnabled()
    }
    
    // MARK: - 设置持久化
    
    private func saveSettings() {
        UserDefaults.standard.set(currentMode.rawValue, forKey: "proxy_mode")
        UserDefaults.standard.set(isSystemProxyEnabled, forKey: "system_proxy_enabled")
    }
    
    private func loadSettings() {
        if let modeString = UserDefaults.standard.string(forKey: "proxy_mode"),
           let mode = ProxyMode.allCases.first(where: { $0.rawValue == modeString }) {
            currentMode = mode
        }
        
        isSystemProxyEnabled = UserDefaults.standard.bool(forKey: "system_proxy_enabled")
    }
    
    // MARK: - 通知
    
    private func sendNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - PAC 文件管理 (可选功能)
    
    /// 生成 PAC 文件
    private func generatePACFile() -> String {
        let pacContent = """
        function FindProxyForURL(url, host) {
            // 本地地址直连
            if (isInNet(host, "127.0.0.0", "255.0.0.0") ||
                isInNet(host, "10.0.0.0", "255.0.0.0") ||
                isInNet(host, "172.16.0.0", "255.240.0.0") ||
                isInNet(host, "192.168.0.0", "255.255.0.0")) {
                return "DIRECT";
            }
            
            // 中国大陆域名直连
            if (shExpMatch(host, "*.cn") ||
                shExpMatch(host, "*.com.cn") ||
                shExpMatch(host, "*.baidu.com") ||
                shExpMatch(host, "*.qq.com") ||
                shExpMatch(host, "*.taobao.com")) {
                return "DIRECT";
            }
            
            // 其他走代理
            return "PROXY 127.0.0.1:\(ClashCore.shared.httpPort)";
        }
        """
        
        return pacContent
    }
    
    /// 启用 PAC 模式
    func enablePACMode() throws {
        let pacContent = generatePACFile()
        let pacURL = URL(fileURLWithPath: "/tmp/clash.pac")
        
        try pacContent.write(to: pacURL, atomically: true, encoding: .utf8)
        
        let script = """
        tell application "System Events"
            tell current location of network preferences
                set AutoProxyURL to "file:///tmp/clash.pac"
                set AutoProxyEnabled to true
            end tell
        end tell
        """
        
        // 暂时注释掉 PAC 模式，因为需要额外的权限
        // try runAppleScript(script)
        print("PAC 模式暂未实现")
    }
    
    // MARK: - 辅助方法
    
    private func getConfigPath() -> String? {
        // 获取当前配置文件路径
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let configsDir = appSupport.appendingPathComponent("ClashX/configs")
        
        // 优先使用 default.yaml
        let defaultConfigPath = configsDir.appendingPathComponent("default.yaml")
        if FileManager.default.fileExists(atPath: defaultConfigPath.path) {
            return defaultConfigPath.path
        }
        
        // 如果没有默认配置，查找任何 .yaml 文件
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: configsDir.path) {
            for file in contents where file.hasSuffix(".yaml") || file.hasSuffix(".yml") {
                let configPath = configsDir.appendingPathComponent(file)
                if FileManager.default.fileExists(atPath: configPath.path) {
                    return configPath.path
                }
            }
        }
        
        return nil
    }
    
    // MARK: - 清理
    
    deinit {
        // 停止代理并恢复系统设置
        Task {
            await stopProxy()
        }
    }
}

// MARK: - 扩展

extension ProxyManager {
    /// 获取代理统计信息
    func getProxyStats() -> (totalUpload: String, totalDownload: String, uptime: String) {
        let totalUpload = formatBytes(Double(networkManager.totalUpload))
        let totalDownload = formatBytes(Double(networkManager.totalDownload))
        
        // 这里需要记录启动时间来计算运行时间
        let uptime = "运行中" // 简化实现
        
        return (totalUpload, totalDownload, uptime)
    }
    
    /// 格式化字节数
    private func formatBytes(_ bytes: Double) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = bytes
        var unitIndex = 0
        
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        
        if unitIndex == 0 {
            return String(format: "%.0f %@", value, units[unitIndex])
        } else {
            return String(format: "%.1f %@", value, units[unitIndex])
        }
    }
}

// MARK: - 通知权限请求

import UserNotifications

extension ProxyManager {
    /// 请求通知权限
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("通知权限已授予")
            } else if let error = error {
                print("通知权限请求失败: \(error)")
            }
        }
    }
}

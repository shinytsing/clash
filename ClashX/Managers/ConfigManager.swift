import Foundation
import Combine

/// 配置管理器
/// 负责管理 Clash 配置文件的加载、保存、更新和切换
class ConfigManager: ObservableObject {
    // MARK: - 属性
    @Published var configs: [ClashConfig] = []
    @Published var currentConfig: ClashConfig?
    @Published var isUpdating = false
    @Published var lastUpdateTime: Date?
    
    private let userDefaults = UserDefaults.standard
    private let configsKey = "clash_configs"
    private let currentConfigKey = "current_config_id"
    private let fileManager = FileManager.default
    
    // 配置文件存储路径
    private var configsDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("ClashX/configs")
    }
    
    // MARK: - 初始化
    init() {
        createConfigsDirectory()
        loadConfigs()
        createDefaultConfigIfNeeded()
    }
    
    // MARK: - 目录管理
    
    private func createConfigsDirectory() {
        if !fileManager.fileExists(atPath: configsDirectory.path) {
            try? fileManager.createDirectory(at: configsDirectory, withIntermediateDirectories: true)
        }
    }
    
    /// 创建默认配置文件（如果不存在）
    private func createDefaultConfigIfNeeded() {
        let defaultConfigPath = configsDirectory.appendingPathComponent("default.yaml")
        
        // 如果默认配置文件不存在，创建一个
        if !fileManager.fileExists(atPath: defaultConfigPath.path) {
            let defaultConfigContent = createDefaultConfigContent()
            try? defaultConfigContent.data(using: .utf8)?.write(to: defaultConfigPath)
            
            // 创建配置记录
            let config = ClashConfig(
                id: UUID(),
                name: "默认配置",
                subscriptionURL: nil,
                isActive: true,
                lastUpdate: Date()
            )
            
            configs.append(config)
            currentConfig = config
            saveConfigs()
        }
        
        // 如果没有当前配置，设置第一个为当前配置
        if currentConfig == nil && !configs.isEmpty {
            currentConfig = configs.first
        }
    }
    
    /// 创建默认配置文件内容
    private func createDefaultConfigContent() -> String {
        return """
port: 7890
socks-port: 7891
allow-lan: false
mode: rule
log-level: info
external-controller: 127.0.0.1:9090
secret: ""

dns:
  enable: true
  nameserver:
    - 223.5.5.5
    - 114.114.114.114

proxies: []

proxy-groups:
  - name: "PROXY"
    type: select
    proxies:
      - DIRECT

rules:
  - MATCH,DIRECT
"""
    }
    
    // MARK: - 配置加载和保存
    
    /// 加载配置列表
    func loadConfigs() {
        // 从 UserDefaults 加载配置列表
        if let data = userDefaults.data(forKey: configsKey),
           let decodedConfigs = try? JSONDecoder().decode([ClashConfig].self, from: data) {
            configs = decodedConfigs
        }
        
        // 加载当前配置
        if let currentConfigId = userDefaults.string(forKey: currentConfigKey),
           let uuid = UUID(uuidString: currentConfigId) {
            currentConfig = configs.first { $0.id == uuid }
        }
        
        // 如果没有配置，创建一个默认配置
        if configs.isEmpty {
            createDefaultConfig()
        }
    }
    
    /// 保存配置列表
    private func saveConfigs() {
        if let data = try? JSONEncoder().encode(configs) {
            userDefaults.set(data, forKey: configsKey)
        }
        
        if let currentConfig = currentConfig {
            userDefaults.set(currentConfig.id.uuidString, forKey: currentConfigKey)
        }
    }
    
    /// 创建默认配置
    private func createDefaultConfig() {
        let defaultConfig = ClashConfig(
            name: "默认配置",
            subscriptionURL: nil,
            isActive: true,
            lastUpdate: Date()
        )
        
        configs.append(defaultConfig)
        currentConfig = defaultConfig
        saveConfigs()
        
        // 创建默认配置文件
        createDefaultConfigFile(for: defaultConfig)
    }
    
    /// 创建默认配置文件内容
    private func createDefaultConfigFile(for config: ClashConfig) {
        let defaultConfigContent = """
        port: 7890
        socks-port: 7891
        allow-lan: false
        mode: rule
        log-level: info
        external-controller: 127.0.0.1:9090
        secret: ""
        
        dns:
          enable: true
          nameserver:
            - 223.5.5.5
            - 114.114.114.114
        
        proxies: []
        
        proxy-groups:
          - name: "PROXY"
            type: select
            proxies: ["DIRECT"]
        
        rules:
          - MATCH,PROXY
        """
        
        let configPath = getConfigFilePath(for: config)
        try? defaultConfigContent.write(to: configPath, atomically: true, encoding: .utf8)
    }
    
    // MARK: - 配置文件路径管理
    
    /// 获取配置文件路径
    private func getConfigFilePath(for config: ClashConfig) -> URL {
        return configsDirectory.appendingPathComponent("\(config.id.uuidString).yaml")
    }
    
    /// 获取当前配置文件路径
    var currentConfigPath: String? {
        guard let currentConfig = currentConfig else { return nil }
        return getConfigFilePath(for: currentConfig).path
    }
    
    // MARK: - 配置管理操作
    
    /// 添加新配置
    func addConfig(name: String, subscriptionURL: String?) async {
        let newConfig = ClashConfig(
            name: name,
            subscriptionURL: subscriptionURL,
            isActive: false,
            lastUpdate: subscriptionURL != nil ? nil : Date()
        )
        
        await MainActor.run {
            configs.append(newConfig)
            saveConfigs()
        }
        
        // 如果是订阅配置，立即更新
        if subscriptionURL != nil {
            await updateConfig(newConfig)
        } else {
            // 创建空配置文件
            createDefaultConfigFile(for: newConfig)
        }
    }
    
    /// 删除配置
    func deleteConfigs(at offsets: IndexSet) {
        let configsToDelete = offsets.map { configs[$0] }
        
        // 删除配置文件
        for config in configsToDelete {
            let configPath = getConfigFilePath(for: config)
            try? fileManager.removeItem(at: configPath)
        }
        
        // 从列表中移除
        configs.remove(atOffsets: offsets)
        
        // 如果删除的是当前配置，切换到第一个可用配置
        if let currentConfig = currentConfig,
           configsToDelete.contains(where: { $0.id == currentConfig.id }) {
            self.currentConfig = configs.first
        }
        
        saveConfigs()
    }
    
    /// 切换到指定配置
    func switchToConfig(_ config: ClashConfig) async {
        guard config.id != currentConfig?.id else { return }
        
        await MainActor.run {
            // 更新旧配置状态
            if let oldConfigIndex = configs.firstIndex(where: { $0.id == currentConfig?.id }) {
                configs[oldConfigIndex] = ClashConfig(
                    id: configs[oldConfigIndex].id,
                    name: configs[oldConfigIndex].name,
                    subscriptionURL: configs[oldConfigIndex].subscriptionURL,
                    isActive: false,
                    lastUpdate: configs[oldConfigIndex].lastUpdate,
                    localPath: configs[oldConfigIndex].localPath
                )
            }
            
            // 更新新配置状态
            if let newConfigIndex = configs.firstIndex(where: { $0.id == config.id }) {
                configs[newConfigIndex] = ClashConfig(
                    id: config.id,
                    name: config.name,
                    subscriptionURL: config.subscriptionURL,
                    isActive: true,
                    lastUpdate: config.lastUpdate,
                    localPath: config.localPath
                )
                currentConfig = configs[newConfigIndex]
            }
            
            saveConfigs()
        }
        
        // 重启 Clash 核心使用新配置
        if let configPath = currentConfigPath {
            do {
                try await ClashCore.shared.restart(configPath: configPath)
            } catch {
                print("切换配置失败: \(error)")
            }
        }
    }
    
    // MARK: - 订阅更新
    
    /// 更新订阅配置
    func updateSubscription() async {
        guard let currentConfig = currentConfig,
              let _ = currentConfig.subscriptionURL else {
            print("当前配置不是订阅配置")
            return
        }
        
        await updateConfig(currentConfig)
    }
    
    /// 更新指定配置
    private func updateConfig(_ config: ClashConfig) async {
        guard let subscriptionURL = config.subscriptionURL,
              let url = URL(string: subscriptionURL) else {
            print("无效的订阅URL")
            return
        }
        
        await MainActor.run {
            isUpdating = true
        }
        
        do {
            // 下载配置文件
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  200...299 ~= httpResponse.statusCode else {
                throw ClashError.networkError("下载失败: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            }
            
            // 验证配置文件格式
            guard let configString = String(data: data, encoding: .utf8),
                  isValidClashConfig(configString) else {
                throw ClashError.parseError("无效的配置文件格式")
            }
            
            // 保存配置文件
            let configPath = getConfigFilePath(for: config)
            try configString.write(to: configPath, atomically: true, encoding: .utf8)
            
            // 更新配置信息
            await MainActor.run {
                if let configIndex = configs.firstIndex(where: { $0.id == config.id }) {
                    configs[configIndex] = ClashConfig(
                        id: config.id,
                        name: config.name,
                        subscriptionURL: config.subscriptionURL,
                        isActive: config.isActive,
                        lastUpdate: Date(),
                        localPath: config.localPath
                    )
                    
                    if currentConfig?.id == config.id {
                        currentConfig = configs[configIndex]
                    }
                }
                
                lastUpdateTime = Date()
                saveConfigs()
            }
            
            // 如果是当前配置，重启 Clash 核心
            if config.id == currentConfig?.id {
                try await ClashCore.shared.restart(configPath: configPath.path)
            }
            
            print("配置更新成功: \(config.name)")
            
        } catch {
            print("更新配置失败: \(error)")
        }
        
        await MainActor.run {
            isUpdating = false
        }
    }
    
    /// 验证配置文件格式
    private func isValidClashConfig(_ configString: String) -> Bool {
        // 基本的 YAML 格式检查
        let requiredFields = ["port", "socks-port", "mode"]
        return requiredFields.allSatisfy { configString.contains("\($0):") }
    }
    
    // MARK: - 配置解析
    
    /// 解析当前配置文件
    func parseCurrentConfig() throws -> ClashConfiguration {
        guard let configPath = currentConfigPath else {
            throw ClashError.configNotFound
        }
        
        let configData = try Data(contentsOf: URL(fileURLWithPath: configPath))
        return try parseConfigData(configData)
    }
    
    /// 解析配置数据
    private func parseConfigData(_ data: Data) throws -> ClashConfiguration {
        guard let yamlString = String(data: data, encoding: .utf8) else {
            throw ClashError.parseError("无法读取配置文件内容")
        }
        
        do {
            return try YAMLParser.parseClashConfig(yamlString)
        } catch {
            throw ClashError.parseError("配置文件解析失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 导入导出
    
    /// 导入配置文件
    func importConfig(from url: URL, name: String) async throws {
        let data = try Data(contentsOf: url)
        
        // 验证配置文件
        guard let configString = String(data: data, encoding: .utf8),
              isValidClashConfig(configString) else {
            throw ClashError.parseError("无效的配置文件")
        }
        
        // 创建新配置
        let newConfig = ClashConfig(
            name: name,
            subscriptionURL: nil,
            isActive: false,
            lastUpdate: Date()
        )
        
        // 保存配置文件
        let configPath = getConfigFilePath(for: newConfig)
        try configString.write(to: configPath, atomically: true, encoding: .utf8)
        
        // 添加到配置列表
        await MainActor.run {
            configs.append(newConfig)
            saveConfigs()
        }
    }
    
    /// 导出配置文件
    func exportConfig(_ config: ClashConfig, to url: URL) throws {
        let sourcePath = getConfigFilePath(for: config)
        try fileManager.copyItem(at: sourcePath, to: url)
    }
    
    // MARK: - 自动更新
    
    /// 启动自动更新定时器
    func startAutoUpdate(interval: TimeInterval = 6 * 3600) { // 默认6小时
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task {
                await self?.updateAllSubscriptions()
            }
        }
    }
    
    /// 更新所有订阅配置
    private func updateAllSubscriptions() async {
        let subscriptionConfigs = configs.filter { $0.subscriptionURL != nil }
        
        for config in subscriptionConfigs {
            await updateConfig(config)
            // 在配置之间等待一段时间，避免同时发起太多请求
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        }
    }
}

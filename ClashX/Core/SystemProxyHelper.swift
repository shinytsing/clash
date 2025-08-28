import Foundation
import SystemConfiguration

/// 系统代理设置帮助工具
/// 使用 SystemConfiguration 框架管理 macOS 系统代理设置
class SystemProxyHelper {
    
    // MARK: - 错误定义
    enum ProxyError: LocalizedError {
        case authorizationFailed
        case configurationFailed(String)
        case networkServiceNotFound
        
        var errorDescription: String? {
            switch self {
            case .authorizationFailed:
                return "需要管理员权限来修改网络设置"
            case .configurationFailed(let message):
                return "配置失败: \(message)"
            case .networkServiceNotFound:
                return "未找到网络服务"
            }
        }
    }
    
    // MARK: - 代理设置
    
    /// 获取当前系统代理设置
    static func getCurrentProxySettings() -> SystemProxySettings? {
        guard let dynamicStore = SCDynamicStoreCreate(nil, "ClashX" as CFString, nil, nil) else {
            return nil
        }
        
        guard let proxies = SCDynamicStoreCopyProxies(dynamicStore) as? [String: Any] else {
            return nil
        }
        
        var settings = SystemProxySettings()
        
        // HTTP 代理
        settings.httpEnabled = proxies[kSCPropNetProxiesHTTPEnable as String] as? Bool ?? false
        settings.httpProxy = proxies[kSCPropNetProxiesHTTPProxy as String] as? String ?? ""
        settings.httpPort = proxies[kSCPropNetProxiesHTTPPort as String] as? Int ?? 0
        
        // HTTPS 代理
        settings.httpsEnabled = proxies[kSCPropNetProxiesHTTPSEnable as String] as? Bool ?? false
        settings.httpsProxy = proxies[kSCPropNetProxiesHTTPSProxy as String] as? String ?? ""
        settings.httpsPort = proxies[kSCPropNetProxiesHTTPSPort as String] as? Int ?? 0
        
        // SOCKS 代理
        settings.socksEnabled = proxies[kSCPropNetProxiesSOCKSEnable as String] as? Bool ?? false
        settings.socksProxy = proxies[kSCPropNetProxiesSOCKSProxy as String] as? String ?? ""
        settings.socksPort = proxies[kSCPropNetProxiesSOCKSPort as String] as? Int ?? 0
        
        // 异常列表
        if let exceptions = proxies[kSCPropNetProxiesExceptionsList as String] as? [String] {
            settings.exceptionsList = exceptions
        }
        
        settings.excludeSimpleHostnames = proxies[kSCPropNetProxiesExcludeSimpleHostnames as String] as? Bool ?? false
        
        return settings
    }
    
    /// 设置系统代理
    static func setSystemProxy(
        httpProxy: String? = nil,
        httpPort: Int? = nil,
        httpsProxy: String? = nil,
        httpsPort: Int? = nil,
        socksProxy: String? = nil,
        socksPort: Int? = nil,
        enabled: Bool
    ) throws {
        
        // 获取系统配置存储
        guard let dynamicStore = SCDynamicStoreCreate(nil, "ClashX" as CFString, nil, nil) else {
            throw ProxyError.configurationFailed("无法创建动态存储")
        }
        
        // 获取网络服务
        guard let networkServices = getNetworkServices() else {
            throw ProxyError.networkServiceNotFound
        }
        
        // 为每个网络服务设置代理
        for serviceID in networkServices {
            try setProxyForService(
                serviceID: serviceID,
                httpProxy: httpProxy,
                httpPort: httpPort,
                httpsProxy: httpsProxy,
                httpsPort: httpsPort,
                socksProxy: socksProxy,
                socksPort: socksPort,
                enabled: enabled
            )
        }
    }
    
    /// 启用系统代理（使用 ClashX 默认设置）
    static func enableClashProxy() throws {
        try setSystemProxy(
            httpProxy: "127.0.0.1",
            httpPort: 7890,
            httpsProxy: "127.0.0.1",
            httpsPort: 7890,
            socksProxy: "127.0.0.1",
            socksPort: 7891,
            enabled: true
        )
    }
    
    /// 禁用系统代理
    static func disableSystemProxy() throws {
        try setSystemProxy(enabled: false)
    }
    
    // MARK: - 私有方法
    
    /// 获取网络服务列表
    private static func getNetworkServices() -> [String]? {
        guard let prefs = SCPreferencesCreate(nil, "ClashX" as CFString, nil) else {
            return nil
        }
        
        guard let networkSet = SCNetworkSetCopyCurrent(prefs) else {
            return nil
        }
        
        guard let services = SCNetworkSetCopyServices(networkSet) as? [SCNetworkService] else {
            return nil
        }
        
        var serviceIDs: [String] = []
        
        for service in services {
            if let serviceID = SCNetworkServiceGetServiceID(service) {
                serviceIDs.append(serviceID as String)
            }
        }
        
        return serviceIDs
    }
    
    /// 为指定网络服务设置代理
    private static func setProxyForService(
        serviceID: String,
        httpProxy: String? = nil,
        httpPort: Int? = nil,
        httpsProxy: String? = nil,
        httpsPort: Int? = nil,
        socksProxy: String? = nil,
        socksPort: Int? = nil,
        enabled: Bool
    ) throws {
        
        guard let prefs = SCPreferencesCreate(nil, "ClashX" as CFString, nil) else {
            throw ProxyError.configurationFailed("无法创建偏好设置")
        }
        
        // 锁定偏好设置以进行修改
        guard SCPreferencesLock(prefs, true) else {
            throw ProxyError.authorizationFailed
        }
        
        defer {
            SCPreferencesUnlock(prefs)
        }
        
        // 获取网络服务
        guard let service = SCNetworkServiceCopy(prefs, serviceID as CFString) else {
            throw ProxyError.networkServiceNotFound
        }
        
        // 获取协议配置
        guard let protocol = SCNetworkServiceCopyProtocol(service, kSCNetworkProtocolTypeProxies) else {
            throw ProxyError.configurationFailed("无法获取代理协议")
        }
        
        // 获取当前配置
        guard let currentConfig = SCNetworkProtocolGetConfiguration(protocol) as? [String: Any] else {
            throw ProxyError.configurationFailed("无法获取当前配置")
        }
        
        var newConfig = currentConfig
        
        if enabled {
            // 设置 HTTP 代理
            if let httpProxy = httpProxy, let httpPort = httpPort {
                newConfig[kSCPropNetProxiesHTTPEnable as String] = true
                newConfig[kSCPropNetProxiesHTTPProxy as String] = httpProxy
                newConfig[kSCPropNetProxiesHTTPPort as String] = httpPort
            }
            
            // 设置 HTTPS 代理
            if let httpsProxy = httpsProxy, let httpsPort = httpsPort {
                newConfig[kSCPropNetProxiesHTTPSEnable as String] = true
                newConfig[kSCPropNetProxiesHTTPSProxy as String] = httpsProxy
                newConfig[kSCPropNetProxiesHTTPSPort as String] = httpsPort
            }
            
            // 设置 SOCKS 代理
            if let socksProxy = socksProxy, let socksPort = socksPort {
                newConfig[kSCPropNetProxiesSOCKSEnable as String] = true
                newConfig[kSCPropNetProxiesSOCKSProxy as String] = socksProxy
                newConfig[kSCPropNetProxiesSOCKSPort as String] = socksPort
            }
            
            // 设置例外列表
            newConfig[kSCPropNetProxiesExceptionsList as String] = [
                "127.0.0.1",
                "localhost",
                "*.local",
                "timestamp.apple.com"
            ]
            
            newConfig[kSCPropNetProxiesExcludeSimpleHostnames as String] = true
            
        } else {
            // 禁用所有代理
            newConfig[kSCPropNetProxiesHTTPEnable as String] = false
            newConfig[kSCPropNetProxiesHTTPSEnable as String] = false
            newConfig[kSCPropNetProxiesSOCKSEnable as String] = false
        }
        
        // 应用新配置
        guard SCNetworkProtocolSetConfiguration(protocol, newConfig as CFDictionary) else {
            throw ProxyError.configurationFailed("无法设置新配置")
        }
        
        // 提交更改
        guard SCPreferencesCommitChanges(prefs) else {
            throw ProxyError.configurationFailed("无法提交更改")
        }
        
        // 应用更改
        guard SCPreferencesApplyChanges(prefs) else {
            throw ProxyError.configurationFailed("无法应用更改")
        }
    }
}

// MARK: - 便利方法

extension SystemProxyHelper {
    
    /// 检查系统代理是否已启用
    static func isSystemProxyEnabled() -> Bool {
        guard let settings = getCurrentProxySettings() else { return false }
        return settings.httpEnabled || settings.httpsEnabled || settings.socksEnabled
    }
    
    /// 检查是否为 ClashX 代理设置
    static func isClashProxyEnabled() -> Bool {
        guard let settings = getCurrentProxySettings() else { return false }
        
        return (settings.httpEnabled && settings.httpProxy == "127.0.0.1" && settings.httpPort == 7890) ||
               (settings.httpsEnabled && settings.httpsProxy == "127.0.0.1" && settings.httpsPort == 7890) ||
               (settings.socksEnabled && settings.socksProxy == "127.0.0.1" && settings.socksPort == 7891)
    }
    
    /// 获取代理状态描述
    static func getProxyStatusDescription() -> String {
        guard let settings = getCurrentProxySettings() else {
            return "无法获取代理设置"
        }
        
        var descriptions: [String] = []
        
        if settings.httpEnabled {
            descriptions.append("HTTP: \(settings.httpProxy):\(settings.httpPort)")
        }
        
        if settings.httpsEnabled {
            descriptions.append("HTTPS: \(settings.httpsProxy):\(settings.httpsPort)")
        }
        
        if settings.socksEnabled {
            descriptions.append("SOCKS: \(settings.socksProxy):\(settings.socksPort)")
        }
        
        return descriptions.isEmpty ? "代理已禁用" : descriptions.joined(separator: ", ")
    }
}

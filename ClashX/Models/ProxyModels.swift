import Foundation

// MARK: - 代理模式
enum ProxyMode: String, CaseIterable, Codable {
    case global = "全局"
    case rule = "规则"
    case direct = "直连"
    
    var clashMode: String {
        switch self {
        case .global: return "global"
        case .rule: return "rule"
        case .direct: return "direct"
        }
    }
}

// MARK: - 代理节点
struct ProxyNode: Codable, Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let server: String
    let port: Int
    let password: String?
    let cipher: String?
    let alpn: [String]?
    let skipCertVerify: Bool?
    var delay: Int?
    
    enum CodingKeys: String, CodingKey {
        case name, type, server, port, password, cipher, alpn
        case skipCertVerify = "skip-cert-verify"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        server = try container.decode(String.self, forKey: .server)
        port = try container.decode(Int.self, forKey: .port)
        password = try container.decodeIfPresent(String.self, forKey: .password)
        cipher = try container.decodeIfPresent(String.self, forKey: .cipher)
        alpn = try container.decodeIfPresent([String].self, forKey: .alpn)
        skipCertVerify = try container.decodeIfPresent(Bool.self, forKey: .skipCertVerify)
        delay = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(server, forKey: .server)
        try container.encode(port, forKey: .port)
        try container.encodeIfPresent(password, forKey: .password)
        try container.encodeIfPresent(cipher, forKey: .cipher)
        try container.encodeIfPresent(alpn, forKey: .alpn)
        try container.encodeIfPresent(skipCertVerify, forKey: .skipCertVerify)
    }
}

// MARK: - 代理组
struct ProxyGroup: Codable {
    let name: String
    let type: String
    let proxies: [String]
    let url: String?
    let interval: Int?
    
    enum CodingKeys: String, CodingKey {
        case name, type, proxies, url, interval
    }
}

// MARK: - DNS 配置
struct DNSConfig: Codable {
    let enable: Bool
    let ipv6: Bool
    let nameserver: [String]
    let fallback: [String]
    let fallbackFilter: FallbackFilter?
    
    enum CodingKeys: String, CodingKey {
        case enable, ipv6, nameserver, fallback
        case fallbackFilter = "fallback-filter"
    }
}

struct FallbackFilter: Codable {
    let geoip: Bool
    let ipcidr: [String]?
    let domain: [String]?
}

// MARK: - Clash 配置
struct ClashConfiguration: Codable {
    let port: Int
    let socksPort: Int
    let allowLan: Bool
    let mode: String
    let logLevel: String
    let externalController: String
    let secret: String
    let dns: DNSConfig?
    let proxies: [ProxyNode]
    let proxyGroups: [ProxyGroup]
    let rules: [String]
    
    enum CodingKeys: String, CodingKey {
        case port
        case socksPort = "socks-port"
        case allowLan = "allow-lan"
        case mode
        case logLevel = "log-level"
        case externalController = "external-controller"
        case secret, dns, proxies
        case proxyGroups = "proxy-groups"
        case rules
    }
}

// MARK: - 用户配置
struct ClashConfig: Codable, Identifiable {
    let id: UUID
    let name: String
    let subscriptionURL: String?
    let isActive: Bool
    let lastUpdate: Date?
    let localPath: String?
    
    init(id: UUID = UUID(), name: String, subscriptionURL: String? = nil, isActive: Bool = false, lastUpdate: Date? = nil, localPath: String? = nil) {
        self.id = id
        self.name = name
        self.subscriptionURL = subscriptionURL
        self.isActive = isActive
        self.lastUpdate = lastUpdate
        self.localPath = localPath
    }
}

// MARK: - API 响应模型
struct ClashAPIResponse<T: Codable>: Codable {
    let data: T?
    let message: String?
}

struct ProxyDelayResponse: Codable {
    let delay: Int
}

struct ProxiesResponse: Codable {
    let proxies: [String: ProxyInfo]
}

struct ProxyInfo: Codable {
    let type: String
    let now: String?
    let all: [String]?
    let history: [DelayHistory]?
}

struct DelayHistory: Codable {
    let time: String
    let delay: Int
}

struct TrafficInfo: Codable {
    let up: Int
    let down: Int
}

// SystemProxySettings 已在 SystemProxyHelper.swift 中定义

// MARK: - 错误定义
enum ClashError: LocalizedError {
    case configNotFound
    case invalidURL
    case networkError(String)
    case parseError(String)
    case apiError(String)
    case systemProxyError(String)
    
    var errorDescription: String? {
        switch self {
        case .configNotFound:
            return "配置文件未找到"
        case .invalidURL:
            return "无效的URL"
        case .networkError(let message):
            return "网络错误: \(message)"
        case .parseError(let message):
            return "解析错误: \(message)"
        case .apiError(let message):
            return "API错误: \(message)"
        case .systemProxyError(let message):
            return "系统代理设置错误: \(message)"
        }
    }
}

// MARK: - 应用状态
struct AppState {
    var isProxyRunning: Bool = false
    var currentMode: ProxyMode = .rule
    var selectedNode: ProxyNode?
    var currentConfig: ClashConfig?
    var uploadSpeed: String = "0 B/s"
    var downloadSpeed: String = "0 B/s"
    var isSystemProxyEnabled: Bool = false
}

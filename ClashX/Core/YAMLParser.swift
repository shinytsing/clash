import Foundation

/// 简化的 YAML 解析器
/// 用于解析 Clash 配置文件
class YAMLParser {
    
    /// 解析 YAML 字符串为字典
    static func parse(_ yamlString: String) throws -> [String: Any] {
        var result: [String: Any] = [:]
        let lines = yamlString.components(separatedBy: .newlines)
        
        var currentSection: String?
        var currentArray: [Any] = []
        var isInArray = false
        var arrayKey: String?
        var indentLevel = 0
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // 跳过空行和注释
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }
            
            let currentIndent = getIndentLevel(line)
            
            // 处理数组结束
            if isInArray && (currentIndent <= indentLevel || !trimmedLine.hasPrefix("-")) {
                if let key = arrayKey {
                    result[key] = currentArray
                }
                currentArray = []
                isInArray = false
                arrayKey = nil
            }
            
            // 处理键值对
            if let colonIndex = trimmedLine.firstIndex(of: ":") {
                let key = String(trimmedLine[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let valueString = String(trimmedLine[trimmedLine.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                
                if valueString.isEmpty {
                    // 这可能是一个节或数组的开始
                    currentSection = key
                    indentLevel = currentIndent
                } else {
                    // 直接的键值对
                    result[key] = parseValue(valueString)
                }
            }
            // 处理数组项
            else if trimmedLine.hasPrefix("-") {
                if !isInArray {
                    isInArray = true
                    arrayKey = currentSection
                    indentLevel = currentIndent
                }
                
                let itemString = String(trimmedLine.dropFirst()).trimmingCharacters(in: .whitespaces)
                if itemString.contains(":") {
                    // 数组中的对象
                    let item = try parseObjectFromLine(itemString)
                    currentArray.append(item)
                } else {
                    // 简单数组项
                    currentArray.append(parseValue(itemString))
                }
            }
        }
        
        // 处理最后的数组
        if isInArray, let key = arrayKey {
            result[key] = currentArray
        }
        
        return result
    }
    
    /// 解析 Clash 配置对象
    static func parseClashConfig(_ yamlString: String) throws -> ClashConfiguration {
        let dict = try parse(yamlString)
        
        // 提取基本配置
        let port = dict["port"] as? Int ?? 7890
        let socksPort = dict["socks-port"] as? Int ?? 7891
        let allowLan = dict["allow-lan"] as? Bool ?? false
        let mode = dict["mode"] as? String ?? "rule"
        let logLevel = dict["log-level"] as? String ?? "info"
        let externalController = dict["external-controller"] as? String ?? "127.0.0.1:9090"
        let secret = dict["secret"] as? String ?? ""
        
        // 解析 DNS 配置
        var dnsConfig: DNSConfig?
        if let dnsDict = dict["dns"] as? [String: Any] {
            dnsConfig = try parseDNSConfig(dnsDict)
        }
        
        // 解析代理节点
        var proxies: [ProxyNode] = []
        if let proxiesArray = dict["proxies"] as? [[String: Any]] {
            proxies = try proxiesArray.compactMap { try parseProxyNode($0) }
        }
        
        // 解析代理组
        var proxyGroups: [ProxyGroup] = []
        if let groupsArray = dict["proxy-groups"] as? [[String: Any]] {
            proxyGroups = try groupsArray.compactMap { try parseProxyGroup($0) }
        }
        
        // 解析规则
        var rules: [String] = []
        if let rulesArray = dict["rules"] as? [String] {
            rules = rulesArray
        }
        
        return ClashConfiguration(
            port: port,
            socksPort: socksPort,
            allowLan: allowLan,
            mode: mode,
            logLevel: logLevel,
            externalController: externalController,
            secret: secret,
            dns: dnsConfig,
            proxies: proxies,
            proxyGroups: proxyGroups,
            rules: rules
        )
    }
    
    // MARK: - 私有方法
    
    private static func getIndentLevel(_ line: String) -> Int {
        var count = 0
        for char in line {
            if char == " " {
                count += 1
            } else if char == "\t" {
                count += 4 // 制表符相当于4个空格
            } else {
                break
            }
        }
        return count
    }
    
    private static func parseValue(_ valueString: String) -> Any {
        let trimmed = valueString.trimmingCharacters(in: .whitespaces)
        
        // 布尔值
        if trimmed.lowercased() == "true" {
            return true
        } else if trimmed.lowercased() == "false" {
            return false
        }
        
        // 数字
        if let intValue = Int(trimmed) {
            return intValue
        }
        if let doubleValue = Double(trimmed) {
            return doubleValue
        }
        
        // 字符串（移除引号）
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
           (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            return String(trimmed.dropFirst().dropLast())
        }
        
        return trimmed
    }
    
    private static func parseObjectFromLine(_ line: String) throws -> [String: Any] {
        var result: [String: Any] = [:]
        
        // 简单的键值对解析
        if let colonIndex = line.firstIndex(of: ":") {
            let key = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            result[key] = parseValue(value)
        }
        
        return result
    }
    
    private static func parseDNSConfig(_ dict: [String: Any]) throws -> DNSConfig {
        let enable = dict["enable"] as? Bool ?? true
        let ipv6 = dict["ipv6"] as? Bool ?? false
        let nameserver = dict["nameserver"] as? [String] ?? []
        let fallback = dict["fallback"] as? [String] ?? []
        
        var fallbackFilter: FallbackFilter?
        if let filterDict = dict["fallback-filter"] as? [String: Any] {
            let geoip = filterDict["geoip"] as? Bool ?? false
            let ipcidr = filterDict["ipcidr"] as? [String]
            let domain = filterDict["domain"] as? [String]
            
            fallbackFilter = FallbackFilter(geoip: geoip, ipcidr: ipcidr, domain: domain)
        }
        
        return DNSConfig(
            enable: enable,
            ipv6: ipv6,
            nameserver: nameserver,
            fallback: fallback,
            fallbackFilter: fallbackFilter
        )
    }
    
    private static func parseProxyNode(_ dict: [String: Any]) throws -> ProxyNode? {
        guard let name = dict["name"] as? String,
              let type = dict["type"] as? String,
              let server = dict["server"] as? String,
              let port = dict["port"] as? Int else {
            return nil
        }
        
        let password = dict["password"] as? String
        let cipher = dict["cipher"] as? String
        let alpn = dict["alpn"] as? [String]
        let skipCertVerify = dict["skip-cert-verify"] as? Bool
        
        // 创建一个临时的 ProxyNode
        // 注意：这里需要手动创建，因为我们的 ProxyNode 有复杂的初始化逻辑
        return ProxyNode(
            name: name,
            type: type,
            server: server,
            port: port,
            password: password,
            cipher: cipher,
            alpn: alpn,
            skipCertVerify: skipCertVerify
        )
    }
    
    private static func parseProxyGroup(_ dict: [String: Any]) throws -> ProxyGroup? {
        guard let name = dict["name"] as? String,
              let type = dict["type"] as? String,
              let proxies = dict["proxies"] as? [String] else {
            return nil
        }
        
        let url = dict["url"] as? String
        let interval = dict["interval"] as? Int
        
        return ProxyGroup(
            name: name,
            type: type,
            proxies: proxies,
            url: url,
            interval: interval
        )
    }
}

// MARK: - 扩展 ProxyNode 支持简单初始化

extension ProxyNode {
    init(name: String, type: String, server: String, port: Int, password: String?, cipher: String?, alpn: [String]?, skipCertVerify: Bool?) {
        self.name = name
        self.type = type
        self.server = server
        self.port = port
        self.password = password
        self.cipher = cipher
        self.alpn = alpn
        self.skipCertVerify = skipCertVerify
        self.delay = nil
    }
}

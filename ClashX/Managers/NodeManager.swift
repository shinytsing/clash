import Foundation
import Combine

/// 节点管理器
/// 负责代理节点的管理、选择、延迟测试和策略组管理
class NodeManager: ObservableObject {
    // MARK: - 属性
    @Published var nodes: [ProxyNode] = []
    @Published var selectedNode: ProxyNode?
    @Published var proxyGroups: [ProxyGroup] = []
    @Published var isTesting = false
    
    private var cancellables = Set<AnyCancellable>()
    private let networkManager = NetworkManager.shared
    // 移除直接依赖，使用注入的方式或简化实现
    
    // MARK: - 初始化
    init() {
        setupBindings()
    }
    
    // MARK: - 设置绑定
    
    private func setupBindings() {
        // 暂时简化：移除配置变化监听
        // 后续可以通过通知中心或其他方式实现
    }
    
    // MARK: - 节点加载
    
    /// 加载节点列表
    func loadNodes() async {
        guard await ClashCore.shared.isRunning else {
            // 如果 Clash 核心未运行，从配置文件加载
            await loadNodesFromConfig()
            return
        }
        
        do {
            // 从 API 获取代理信息
            let proxiesResponse = try await ClashCore.shared.get("/proxies", responseType: ProxiesResponse.self)
            
            var newNodes: [ProxyNode] = []
            var newGroups: [ProxyGroup] = []
            
            for (name, proxyInfo) in proxiesResponse.proxies {
                if proxyInfo.type == "Selector" || proxyInfo.type == "URLTest" || proxyInfo.type == "Fallback" {
                    // 这是一个策略组
                    let group = ProxyGroup(
                        name: name,
                        type: proxyInfo.type,
                        proxies: proxyInfo.all ?? [],
                        url: nil,
                        interval: nil
                    )
                    newGroups.append(group)
                } else if proxyInfo.type != "Direct" && proxyInfo.type != "Reject" {
                    // 这是一个代理节点
                    // 由于 API 返回的信息有限，创建简化的节点对象
                    var node = ProxyNode(
                        name: name,
                        type: proxyInfo.type,
                        server: "unknown",
                        port: 0,
                        password: nil,
                        cipher: nil,
                        alpn: nil,
                        skipCertVerify: nil
                    )
                    
                    // 如果有历史延迟数据，取最新的
                    if let history = proxyInfo.history, let latest = history.last {
                        node.delay = latest.delay
                    }
                    
                    newNodes.append(node)
                }
            }
            
            await MainActor.run {
                self.nodes = newNodes
                self.proxyGroups = newGroups
                
                // 更新选中的节点
                if let selected = selectedNode {
                    selectedNode = nodes.first { $0.name == selected.name }
                }
            }
            
        } catch {
            print("从 API 加载节点失败: \(error)")
            await loadNodesFromConfig()
        }
    }
    
    /// 从配置文件加载节点
    private func loadNodesFromConfig() async {
        // 简化实现：创建一些示例节点
        let sampleNodes = [
            ProxyNode(name: "香港-01", type: "ss", server: "hk1.example.com", port: 443, password: nil, cipher: nil, alpn: nil, skipCertVerify: nil),
            ProxyNode(name: "美国-01", type: "ss", server: "us1.example.com", port: 443, password: nil, cipher: nil, alpn: nil, skipCertVerify: nil),
            ProxyNode(name: "日本-01", type: "ss", server: "jp1.example.com", port: 443, password: nil, cipher: nil, alpn: nil, skipCertVerify: nil)
        ]
        
        await MainActor.run {
            self.nodes = sampleNodes
            self.proxyGroups = []
            
            // 如果没有选中节点，默认选择第一个
            if selectedNode == nil && !nodes.isEmpty {
                selectedNode = nodes.first
            }
        }
    }
    
    // MARK: - 节点选择
    
    /// 选择节点
    func selectNode(_ node: ProxyNode) async {
        guard await ClashCore.shared.isRunning else {
            await MainActor.run {
                selectedNode = node
            }
            return
        }
        
        do {
            // 通过 API 设置代理节点
            // 需要找到包含此节点的策略组
            let groupName = findGroupContainingNode(node.name)
            
            if let group = groupName {
                try await ClashCore.shared.put("/proxies/\(group)", body: ["name": node.name])
                
                await MainActor.run {
                    selectedNode = node
                }
                
                print("已选择节点: \(node.name)")
            } else {
                print("未找到包含节点 \(node.name) 的策略组")
            }
            
        } catch {
            print("选择节点失败: \(error)")
        }
    }
    
    /// 查找包含指定节点的策略组
    private func findGroupContainingNode(_ nodeName: String) -> String? {
        for group in proxyGroups {
            if group.proxies.contains(nodeName) {
                return group.name
            }
        }
        return nil
    }
    
    // MARK: - 延迟测试
    
    /// 测试所有节点延迟
    func testAllNodesDelay() async {
        guard !isTesting else { return }
        
        await MainActor.run {
            isTesting = true
        }
        
        // 获取所有需要测试的节点名称
        let nodeNames = nodes.map { $0.name }
        
        // 批量测试延迟
        let delayResults = await networkManager.testMultipleNodesDelay(nodeNames: nodeNames)
        
        // 更新节点延迟信息
        await MainActor.run {
            for i in 0..<nodes.count {
                if let delay = delayResults[nodes[i].name] {
                    nodes[i].delay = delay
                }
            }
            
            isTesting = false
        }
    }
    
    /// 测试单个节点延迟
    func testNodeDelay(_ node: ProxyNode) async {
        guard let delay = await networkManager.testNodeDelay(nodeName: node.name) else {
            return
        }
        
        await MainActor.run {
            if let index = nodes.firstIndex(where: { $0.name == node.name }) {
                nodes[index].delay = delay
            }
        }
    }
    
    // MARK: - 节点筛选和排序
    
    /// 获取快速节点 (延迟 < 300ms)
    func getFastNodes() -> [ProxyNode] {
        return nodes.filter { node in
            guard let delay = node.delay else { return false }
            return delay < 300
        }
    }
    
    /// 获取按延迟排序的节点
    func getNodesSortedByDelay() -> [ProxyNode] {
        return nodes.sorted { node1, node2 in
            guard let delay1 = node1.delay, let delay2 = node2.delay else {
                return node1.delay != nil
            }
            return delay1 < delay2
        }
    }
    
    /// 按地区筛选节点
    func getNodesByRegion() -> [String: [ProxyNode]] {
        var regionNodes: [String: [ProxyNode]] = [:]
        
        for node in nodes {
            let region = extractRegionFromNodeName(node.name)
            if regionNodes[region] == nil {
                regionNodes[region] = []
            }
            regionNodes[region]?.append(node)
        }
        
        return regionNodes
    }
    
    /// 从节点名称提取地区信息
    private func extractRegionFromNodeName(_ name: String) -> String {
        // 定义地区关键词映射
        let regionKeywords: [String: String] = [
            "香港": "香港",
            "HongKong": "香港",
            "HK": "香港",
            "台湾": "台湾",
            "Taiwan": "台湾",
            "TW": "台湾",
            "日本": "日本",
            "Japan": "日本",
            "JP": "日本",
            "韩国": "韩国",
            "Korea": "韩国",
            "KR": "韩国",
            "新加坡": "新加坡",
            "Singapore": "新加坡",
            "SG": "新加坡",
            "美国": "美国",
            "UnitedStates": "美国",
            "US": "美国",
            "英国": "英国",
            "UnitedKingdom": "英国",
            "UK": "英国",
            "德国": "德国",
            "Germany": "德国",
            "DE": "德国",
            "法国": "法国",
            "France": "法国",
            "FR": "法国",
            "荷兰": "荷兰",
            "Netherlands": "荷兰",
            "NL": "荷兰",
            "澳大利亚": "澳大利亚",
            "Australia": "澳大利亚",
            "AU": "澳大利亚"
        ]
        
        let upperName = name.uppercased()
        
        for (keyword, region) in regionKeywords {
            if upperName.contains(keyword.uppercased()) {
                return region
            }
        }
        
        return "其他"
    }
    
    // MARK: - 策略组管理
    
    /// 获取指定策略组的当前选中节点
    func getCurrentNodeForGroup(_ groupName: String) async -> String? {
        guard await ClashCore.shared.isRunning else { return nil }
        
        do {
            let proxyInfo = try await ClashCore.shared.get("/proxies/\(groupName)", responseType: ProxyInfo.self)
            return proxyInfo.now
        } catch {
            print("获取策略组 \(groupName) 当前节点失败: \(error)")
            return nil
        }
    }
    
    /// 设置策略组的节点
    func setNodeForGroup(_ groupName: String, nodeName: String) async {
        guard await ClashCore.shared.isRunning else { return }
        
        do {
            try await ClashCore.shared.put("/proxies/\(groupName)", body: ["name": nodeName])
            print("已为策略组 \(groupName) 设置节点: \(nodeName)")
        } catch {
            print("设置策略组节点失败: \(error)")
        }
    }
    
    // MARK: - 自动选择最优节点
    
    /// 自动选择延迟最低的节点
    func selectFastestNode() async {
        guard !nodes.isEmpty else { return }
        
        // 先测试所有节点延迟
        await testAllNodesDelay()
        
        // 找到延迟最低的节点
        let fastestNode = nodes.min { node1, node2 in
            guard let delay1 = node1.delay, let delay2 = node2.delay else {
                return node1.delay != nil
            }
            return delay1 < delay2
        }
        
        if let fastest = fastestNode {
            await selectNode(fastest)
        }
    }
    
    /// 自动选择指定地区的最优节点
    func selectBestNodeInRegion(_ region: String) async {
        let regionNodes = getNodesByRegion()[region] ?? []
        guard !regionNodes.isEmpty else { return }
        
        // 测试该地区节点的延迟
        let nodeNames = regionNodes.map { $0.name }
        let delayResults = await networkManager.testMultipleNodesDelay(nodeNames: nodeNames)
        
        // 更新延迟信息
        await MainActor.run {
            for i in 0..<nodes.count {
                if let delay = delayResults[nodes[i].name] {
                    nodes[i].delay = delay
                }
            }
        }
        
        // 选择该地区延迟最低的节点
        let bestNode = regionNodes.min { node1, node2 in
            guard let delay1 = delayResults[node1.name],
                  let delay2 = delayResults[node2.name] else {
                return delayResults[node1.name] != nil
            }
            return delay1 < delay2
        }
        
        if let best = bestNode {
            await selectNode(best)
        }
    }
    
    // MARK: - 节点健康检查
    
    /// 检查节点健康状态
    func checkNodesHealth() async {
        let unhealthyNodes = nodes.filter { node in
            guard let delay = node.delay else { return true }
            return delay > 1000 // 延迟超过1秒视为不健康
        }
        
        if !unhealthyNodes.isEmpty {
            print("发现 \(unhealthyNodes.count) 个不健康的节点")
            
            // 如果当前选中的节点不健康，自动切换到健康节点
            if let current = selectedNode,
               unhealthyNodes.contains(where: { $0.name == current.name }) {
                await selectFastestNode()
            }
        }
    }
    
    /// 启动定期健康检查
    func startPeriodicHealthCheck(interval: TimeInterval = 300) { // 默认5分钟
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task {
                await self?.checkNodesHealth()
            }
        }
    }
}

// MARK: - 统计信息扩展

extension NodeManager {
    /// 获取节点统计信息
    func getNodeStatistics() -> (total: Int, available: Int, fastNodes: Int, averageDelay: Double) {
        let total = nodes.count
        let available = nodes.filter { $0.delay != nil }.count
        let fastNodes = getFastNodes().count
        
        let delays = nodes.compactMap { $0.delay }
        let averageDelay = delays.isEmpty ? 0 : Double(delays.reduce(0, +)) / Double(delays.count)
        
        return (total, available, fastNodes, averageDelay)
    }
    
    /// 获取地区分布统计
    func getRegionDistribution() -> [String: Int] {
        let regionNodes = getNodesByRegion()
        return regionNodes.mapValues { $0.count }
    }
}

import Foundation
import Network

/// 网络管理器
/// 负责网络请求、连接监测和流量统计
class NetworkManager: ObservableObject {
    // MARK: - 单例
    static let shared = NetworkManager()
    
    // MARK: - 属性
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var trafficTimer: Timer?
    
    @Published var isConnected = false
    @Published var connectionType: NWInterface.InterfaceType?
    @Published var uploadSpeed: String = "0 B/s"
    @Published var downloadSpeed: String = "0 B/s"
    @Published var totalUpload: Int64 = 0
    @Published var totalDownload: Int64 = 0
    
    private var lastUpload: Int64 = 0
    private var lastDownload: Int64 = 0
    private var lastTrafficTime = Date()
    
    // MARK: - 初始化
    private init() {
        setupNetworkMonitoring()
    }
    
    // MARK: - 网络监控
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
            }
        }
        
        monitor.start(queue: monitorQueue)
    }
    
    // MARK: - 流量统计
    
    /// 开始流量监控
    func startTrafficMonitoring() {
        stopTrafficMonitoring()
        
        trafficTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task {
                await self?.updateTrafficInfo()
            }
        }
    }
    
    /// 停止流量监控
    func stopTrafficMonitoring() {
        trafficTimer?.invalidate()
        trafficTimer = nil
    }
    
    /// 更新流量信息
    private func updateTrafficInfo() async {
        do {
            let traffic = try await ClashCore.shared.get("/traffic", responseType: TrafficInfo.self)
            
            await MainActor.run {
                let currentTime = Date()
                let timeDiff = currentTime.timeIntervalSince(self.lastTrafficTime)
                
                if timeDiff > 0 {
                    let uploadDiff = max(0, traffic.up - self.lastUpload)
                    let downloadDiff = max(0, traffic.down - self.lastDownload)
                    
                    let uploadSpeedValue = Double(uploadDiff) / timeDiff
                    let downloadSpeedValue = Double(downloadDiff) / timeDiff
                    
                    self.uploadSpeed = self.formatBytes(uploadSpeedValue) + "/s"
                    self.downloadSpeed = self.formatBytes(downloadSpeedValue) + "/s"
                }
                
                self.lastUpload = traffic.up
                self.lastDownload = traffic.down
                self.totalUpload = traffic.up
                self.totalDownload = traffic.down
                self.lastTrafficTime = currentTime
            }
        } catch {
            print("获取流量信息失败: \(error)")
        }
    }
    
    // MARK: - 网络请求
    
    /// 下载文件
    func downloadFile(from url: URL, to destinationURL: URL, progress: @escaping (Double) -> Void) async throws {
        let (asyncBytes, response) = try await URLSession.shared.bytes(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw ClashError.networkError("下载失败")
        }
        
        let expectedBytes = httpResponse.expectedContentLength
        var downloadedBytes: Int64 = 0
        
        let fileHandle = try FileHandle(forWritingTo: destinationURL)
        defer { fileHandle.closeFile() }
        
        for try await byte in asyncBytes {
            let data = Data([byte])
            fileHandle.write(data)
            downloadedBytes += 1
            
            if expectedBytes > 0 {
                let progressValue = Double(downloadedBytes) / Double(expectedBytes)
                await MainActor.run {
                    progress(progressValue)
                }
            }
        }
    }
    
    /// 检查网络连通性
    func checkConnectivity(to host: String = "www.google.com", timeout: TimeInterval = 5) async -> Bool {
        guard let url = URL(string: "http://\(host)") else { return false }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    /// 测试节点延迟
    func testNodeDelay(nodeName: String) async -> Int? {
        do {
            let delayResponse = try await ClashCore.shared.get(
                "/proxies/\(nodeName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? nodeName)/delay?timeout=5000&url=http://www.gstatic.com/generate_204",
                responseType: ProxyDelayResponse.self
            )
            return delayResponse.delay
        } catch {
            print("测试节点 \(nodeName) 延迟失败: \(error)")
            return nil
        }
    }
    
    /// 批量测试节点延迟
    func testMultipleNodesDelay(nodeNames: [String]) async -> [String: Int] {
        var results: [String: Int] = [:]
        
        // 使用 TaskGroup 并发测试
        await withTaskGroup(of: (String, Int?).self) { group in
            for nodeName in nodeNames {
                group.addTask {
                    let delay = await self.testNodeDelay(nodeName: nodeName)
                    return (nodeName, delay)
                }
            }
            
            for await (nodeName, delay) in group {
                if let delay = delay {
                    results[nodeName] = delay
                }
            }
        }
        
        return results
    }
    
    // MARK: - 工具方法
    
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
    
    /// 获取网络类型描述
    var connectionDescription: String {
        guard isConnected else { return "未连接" }
        
        switch connectionType {
        case .wifi:
            return "Wi-Fi"
        case .cellular:
            return "蜂窝网络"
        case .wiredEthernet:
            return "以太网"
        case .loopback:
            return "本地回环"
        case .other:
            return "其他"
        case .none:
            return "未知"
        @unknown default:
            return "未知"
        }
    }
    
    // MARK: - 清理
    
    deinit {
        stopTrafficMonitoring()
        monitor.cancel()
    }
}

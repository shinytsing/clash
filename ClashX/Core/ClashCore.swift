import Foundation
import Network
import AppKit

/// Clash 核心管理类  
/// 负责与 Clash 二进制进程通信和生命周期管理
class ClashCore: ObservableObject {
    // MARK: - 单例
    static let shared = ClashCore()
    
    // MARK: - 属性
    private var clashProcess: Process?
    private let clashExecutableName = "clash-darwin"
    private let configDirectory: URL
    private let logsDirectory: URL
    private let executablePath: URL
    
    @Published var isRunning = false
    @Published var apiPort: Int = 9090
    @Published var httpPort: Int = 7890
    @Published var socksPort: Int = 7891
    
    // API 基础 URL
    var baseURL: String {
        "http://127.0.0.1:\(apiPort)"
    }
    
    // MARK: - 初始化
    private init() {
        // 创建应用支持目录
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("ClashX")
        
        configDirectory = appDirectory.appendingPathComponent("configs")
        logsDirectory = appDirectory.appendingPathComponent("logs")
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        
        // Clash 可执行文件路径 (将包含在 app bundle 中)
        executablePath = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources")
            .appendingPathComponent(clashExecutableName)
        
        // 设置通知监听
        setupNotifications()
    }
    
    // MARK: - 生命周期管理
    
    /// 启动 Clash 核心
    func start(configPath: String) async throws {
        guard !isRunning else { return }
        
        // 检查可执行文件是否存在
        guard FileManager.default.fileExists(atPath: executablePath.path) else {
            throw ClashError.apiError("Clash 可执行文件不存在: \(executablePath.path)")
        }
        
        // 创建进程
        let process = Process()
        process.executableURL = executablePath
        process.arguments = [
            "-d", configDirectory.path,
            "-f", configPath,
            "-ext-ctl", "127.0.0.1:\(apiPort)"
        ]
        
        // 设置工作目录
        process.currentDirectoryURL = configDirectory
        
        // 重定向输出到日志文件
        let logFile = logsDirectory.appendingPathComponent("clash.log")
        let logHandle = try FileHandle(forWritingTo: logFile)
        process.standardOutput = logHandle
        process.standardError = logHandle
        
        // 设置进程终止回调
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.clashProcess = nil
            }
        }
        
        do {
            try process.run()
            self.clashProcess = process
            
            // 等待 API 服务可用
            try await waitForAPI()
            
            await MainActor.run {
                self.isRunning = true
            }
            
            print("Clash 核心启动成功")
        } catch {
            throw ClashError.apiError("启动 Clash 失败: \(error.localizedDescription)")
        }
    }
    
    /// 停止 Clash 核心
    func stop() {
        guard let process = clashProcess, isRunning else { return }
        
        process.terminate()
        
        // 等待进程结束
        DispatchQueue.global().async {
            process.waitUntilExit()
        }
        
        clashProcess = nil
        isRunning = false
        
        print("Clash 核心已停止")
    }
    
    /// 重启 Clash 核心
    func restart(configPath: String) async throws {
        stop()
        
        // 等待一段时间确保进程完全结束
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        
        try await start(configPath: configPath)
    }
    
    // MARK: - API 通信
    
    /// 等待 API 服务可用
    private func waitForAPI(timeout: TimeInterval = 10) async throws {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            do {
                let url = URL(string: "\(baseURL)/")!
                let (_, response) = try await URLSession.shared.data(from: url)
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    return
                }
            } catch {
                // 继续等待
            }
            
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        }
        
        throw ClashError.apiError("API 服务启动超时")
    }
    
    /// 发送 GET 请求
    func get<T: Codable>(_ endpoint: String, responseType: T.Type) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw ClashError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClashError.networkError("无效的响应")
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw ClashError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            return try decoder.decode(T.self, from: data)
        } catch let decodingError as DecodingError {
            throw ClashError.parseError("解码失败: \(decodingError.localizedDescription)")
        } catch {
            throw ClashError.networkError(error.localizedDescription)
        }
    }
    
    /// 发送 PUT 请求
    func put<T: Codable>(_ endpoint: String, body: T) async throws {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw ClashError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            request.httpBody = try encoder.encode(body)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClashError.networkError("无效的响应")
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw ClashError.apiError("HTTP \(httpResponse.statusCode)")
            }
        } catch let encodingError as EncodingError {
            throw ClashError.parseError("编码失败: \(encodingError.localizedDescription)")
        } catch {
            throw ClashError.networkError(error.localizedDescription)
        }
    }
    
    /// 发送 PATCH 请求
    func patch(_ endpoint: String, json: [String: Any]) async throws {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw ClashError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClashError.networkError("无效的响应")
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw ClashError.apiError("HTTP \(httpResponse.statusCode)")
            }
        } catch {
            throw ClashError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - 配置管理
    
    /// 获取配置目录路径
    var configDirectoryPath: String {
        configDirectory.path
    }
    
    /// 获取日志目录路径
    var logsDirectoryPath: String {
        logsDirectory.path
    }
    
    /// 复制 Clash 可执行文件到应用包
    static func bundleClashExecutable() {
        // 这个方法应该在构建脚本中调用，将 Clash 二进制文件复制到应用包中
        // 或者在首次运行时从网络下载
        print("需要将 Clash 可执行文件添加到应用包中")
    }
    
    // MARK: - 通知处理
    
    private func setupNotifications() {
        // 监听应用退出通知
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stop()
        }
    }
    
    deinit {
        stop()
        NotificationCenter.default.removeObserver(self)
    }
}

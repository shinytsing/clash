# ClashX macOS 部署指南

## 🚀 部署前准备

### 系统要求
- **操作系统**: macOS 11.0 (Big Sur) 或更高版本
- **开发工具**: Xcode 14.0 或更高版本
- **架构支持**: Intel x64 和 Apple Silicon (M1/M2)

### 权限需求
- **网络访问权限**: 用于代理连接和配置更新
- **系统偏好设置权限**: 用于管理网络代理设置
- **文件系统访问**: 用于配置文件管理

## 📦 生产环境部署

### 1. 获取真实的 Clash 核心

当前项目使用模拟的 Clash 核心，生产环境需要替换为真实版本：

```bash
# 方案一：从 GitHub Releases 下载（如果可用）
# 注意：Clash 官方已停止维护，建议使用分叉版本

# 方案二：使用 Clash Meta 或其他分叉版本
curl -L -o clash-meta.gz "https://github.com/MetaCubeX/Clash.Meta/releases/download/v1.15.1/clash.meta-darwin-amd64-v1.15.1.gz"
gunzip clash-meta.gz
mv clash.meta ClashX/Resources/clash-darwin
chmod +x ClashX/Resources/clash-darwin

# 方案三：自行编译
# git clone https://github.com/MetaCubeX/Clash.Meta.git
# cd Clash.Meta && make darwin && cp bin/clash.meta ../ClashX/Resources/clash-darwin
```

### 2. 配置代码签名

在 Xcode 中配置代码签名：

1. 打开 `ClashX.xcodeproj`
2. 选择 ClashX target
3. 在 "Signing & Capabilities" 中：
   - 选择开发团队
   - 配置 Bundle Identifier
   - 确保启用自动签名

### 3. 配置 Entitlements

确保 `ClashX.entitlements` 包含必要权限：

```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>
<key>com.apple.security.automation.apple-events</key>
<true/>
```

### 4. 构建发布版本

```bash
# 使用 xcodebuild 构建
xcodebuild -project ClashX.xcodeproj \
           -scheme ClashX \
           -configuration Release \
           -archivePath ClashX.xcarchive \
           archive

# 导出应用
xcodebuild -exportArchive \
           -archivePath ClashX.xcarchive \
           -exportPath ./build \
           -exportOptionsPlist exportOptions.plist
```

### 5. 公证和分发

对于外部分发，需要进行公证：

```bash
# 上传公证
xcrun notarytool submit ClashX.app --keychain-profile "notarytool" --wait

# 装订公证票据
xcrun stapler staple ClashX.app

# 验证公证
xcrun stapler validate ClashX.app
```

## 🔧 配置管理

### 默认配置

创建合适的默认配置文件：

```yaml
# ClashX/Resources/default-config.yaml
port: 7890
socks-port: 7891
allow-lan: false
mode: rule
log-level: info
external-controller: 127.0.0.1:9090

dns:
  enable: true
  nameserver:
    - 223.5.5.5
    - 114.114.114.114

proxies:
  - name: "DIRECT"
    type: direct

proxy-groups:
  - name: "PROXY"
    type: select
    proxies: ["DIRECT"]

rules:
  - MATCH,PROXY
```

### 订阅配置示例

```yaml
# 示例订阅配置格式
subscription-userinfo: upload=0; download=0; total=10737418240; expire=1699776000
proxies:
  - name: "HK-1"
    type: trojan
    server: example.com
    port: 443
    password: your-password
    
proxy-groups:
  - name: "Auto"
    type: url-test
    proxies: ["HK-1"]
    url: 'http://www.gstatic.com/generate_204'
    interval: 300
```

## 🛡️ 安全配置

### 网络安全

1. **HTTPS 强制**: 所有网络请求使用 HTTPS
2. **证书验证**: 启用 SSL/TLS 证书验证
3. **DNS 安全**: 使用安全的 DNS 服务器

### 权限控制

1. **最小权限原则**: 仅请求必要权限
2. **沙盒兼容**: 确保应用沙盒兼容性
3. **密钥管理**: 使用 Keychain 存储敏感信息

### 数据保护

```swift
// 示例：安全存储配置
func saveSecureConfig(_ config: String, for key: String) {
    let data = config.data(using: .utf8)!
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecValueData as String: data
    ]
    SecItemAdd(query as CFDictionary, nil)
}
```

## 📊 监控和日志

### 日志配置

配置不同级别的日志：

```swift
enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}

func log(_ message: String, level: LogLevel = .info) {
    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    print("[\(timestamp)] [\(level.rawValue)] \(message)")
}
```

### 性能监控

```swift
// 监控内存使用
func getMemoryUsage() -> UInt64 {
    var taskInfo = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
    
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    
    return kerr == KERN_SUCCESS ? taskInfo.resident_size : 0
}
```

## 🔄 自动更新

### 更新检查

实现自动更新检查：

```swift
struct UpdateChecker {
    func checkForUpdates() async -> UpdateInfo? {
        let url = URL(string: "https://api.github.com/repos/your-repo/releases/latest")!
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            
            if isNewerVersion(release.tagName) {
                return UpdateInfo(version: release.tagName, downloadURL: release.assets.first?.downloadURL)
            }
        } catch {
            print("更新检查失败: \(error)")
        }
        
        return nil
    }
}
```

### 更新下载

```swift
func downloadUpdate(from url: URL) async throws {
    let (data, _) = try await URLSession.shared.data(from: url)
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("ClashX-Update.dmg")
    try data.write(to: tempURL)
    
    // 验证下载文件
    // 提示用户安装
}
```

## 📱 用户体验优化

### 启动优化

```swift
@main
struct ClashXApp: App {
    init() {
        // 预加载关键组件
        _ = ClashCore.shared
        _ = ConfigManager()
        
        // 设置全局配置
        setupGlobalConfiguration()
    }
}
```

### 内存优化

```swift
class MemoryManager {
    func cleanupUnusedResources() {
        // 清理图片缓存
        NSApp.clearIconCache()
        
        // 清理日志文件
        cleanupOldLogs()
        
        // 强制垃圾回收
        autoreleasepool {
            // 执行内存清理操作
        }
    }
}
```

## 🐛 故障排除

### 常见问题解决

1. **代理无法启动**
   ```bash
   # 检查端口占用
   lsof -i :7890
   lsof -i :7891
   
   # 检查配置文件
   ./ClashX/Resources/clash-darwin -t -f config.yaml
   ```

2. **系统代理设置失败**
   ```bash
   # 检查权限
   sudo dscl . -read /Users/$USER AuthenticationAuthority
   
   # 重置网络设置
   sudo networksetup -setautoproxyurl "Wi-Fi" ""
   ```

3. **应用崩溃**
   ```bash
   # 查看崩溃日志
   cat ~/Library/Logs/DiagnosticReports/ClashX*
   
   # 清理应用数据
   rm -rf ~/Library/Application\ Support/ClashX/
   ```

### 调试技巧

```swift
#if DEBUG
func debugPrint(_ message: String) {
    print("[DEBUG] \(message)")
}
#else
func debugPrint(_ message: String) {
    // 生产环境不输出调试信息
}
#endif
```

## 📞 支持和维护

### 用户反馈收集

```swift
func collectFeedback() {
    let systemInfo = [
        "macOS版本": ProcessInfo.processInfo.operatingSystemVersionString,
        "应用版本": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知",
        "架构": ProcessInfo.processInfo.machineArchitecture
    ]
    
    // 发送到反馈服务
}
```

### 远程诊断

```swift
func generateDiagnosticReport() -> String {
    var report = "ClashX 诊断报告\n"
    report += "生成时间: \(Date())\n"
    report += "系统信息: \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
    report += "内存使用: \(getMemoryUsage()) bytes\n"
    report += "代理状态: \(ProxyManager.shared.isRunning ? "运行中" : "已停止")\n"
    
    return report
}
```

## 🎯 总结

这个部署指南涵盖了从开发到生产环境的完整部署流程。遵循这些步骤可以确保 ClashX 应用的稳定运行和安全性。

记住在生产环境中：
- ✅ 使用真实的 Clash 核心
- ✅ 配置正确的代码签名
- ✅ 启用所有安全功能
- ✅ 进行充分的测试
- ✅ 准备用户支持文档

祝您部署成功！🚀

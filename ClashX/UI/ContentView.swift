import SwiftUI

struct ContentView: View {
    @EnvironmentObject var configManager: ConfigManager
    @EnvironmentObject var proxyManager: ProxyManager
    @EnvironmentObject var nodeManager: NodeManager
    @State private var selectedTab: SidebarItem = .dashboard
    @State private var searchText = ""
    
    var body: some View {
        mainNavigationView
    }
    
    private var mainNavigationView: some View {
        NavigationView {
            sidebarView
            detailView
        }
        .environmentObject(configManager)
        .environmentObject(proxyManager)
        .environmentObject(nodeManager)
        .onAppear(perform: initializeData)
    }
    
    private var sidebarView: some View {
        SidebarView(selectedTab: $selectedTab)
            .frame(minWidth: 200, idealWidth: 220, maxWidth: 250)
    }
    
    private var detailView: some View {
        contentSwitcher
            // 暂时移除 toolbar 以避免兼容性问题
    }
    
    @ViewBuilder
    private var contentSwitcher: some View {
        switch selectedTab {
        case .dashboard:
            DashboardView()
        case .proxies:
            ProxiesView(searchText: $searchText)
        case .configs:
            ConfigsView()
        case .logs:
            LogsView()
        case .settings:
            SettingsView()
        }
    }
    
    private var toolbarContent: some View {
        HStack {
            navigationTitle
            Spacer()
            if selectedTab == .proxies {
                proxiesToolbar
            }
            if selectedTab == .configs {
                configsToolbar
            }
        }
    }
    
    private var navigationTitle: some View {
        HStack {
            Text(selectedTab.title)
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
        }
    }
    
    private var proxiesToolbar: some View {
        HStack {
            TextField("搜索节点", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 200)
            
            Button("测试延迟") {
                Task {
                    await nodeManager.testAllNodesDelay()
                }
            }
            .disabled(nodeManager.isTesting)
        }
    }
    
    private var configsToolbar: some View {
        Button("更新订阅") {
            Task {
                await configManager.updateSubscription()
            }
        }
        .disabled(configManager.isUpdating)
    }
    
    private func initializeData() {
        Task {
            await configManager.loadConfigs()
            await nodeManager.loadNodes()
        }
    }
}

// 侧边栏视图
struct SidebarView: View {
    @Binding var selectedTab: SidebarItem
    @EnvironmentObject var proxyManager: ProxyManager
    
    var body: some View {
        List(SidebarItem.allCases, id: \.self) { item in
            Button(action: {
                selectedTab = item
            }) {
                HStack {
                    Image(systemName: item.icon)
                        .foregroundColor(item == selectedTab ? Color.accentColor : Color.secondary)
                    Text(item.title)
                        .foregroundColor(item == selectedTab ? Color.accentColor : Color.primary)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("ClashX")
        // .navigationBarTitleDisplayMode(.large) - macOS 不可用
        // 暂时移除 toolbar 以避免兼容性问题
    }
}

// 仪表板视图
struct DashboardView: View {
    @EnvironmentObject var proxyManager: ProxyManager
    @EnvironmentObject var nodeManager: NodeManager
    @EnvironmentObject var configManager: ConfigManager
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // 代理状态卡片
                ProxyStatusCard()
                
                // 快速操作卡片
                QuickActionsCard()
                
                // 节点状态卡片
                NodeStatusCard()
                
                // 配置信息卡片
                ConfigInfoCard()
            }
            .padding()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// 代理状态卡片
struct ProxyStatusCard: View {
    @EnvironmentObject var proxyManager: ProxyManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "network")
                    .foregroundColor(Color.accentColor)
                Text("代理状态")
                    .font(.headline)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(proxyManager.isRunning ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                        Text(proxyManager.isRunning ? "运行中" : "已停止")
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                    
                    Text("模式: \(proxyManager.currentMode.rawValue)")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    Task {
                        await proxyManager.toggleProxy()
                    }
                }) {
                    HStack {
                        Image(systemName: proxyManager.isRunning ? "stop.circle.fill" : "play.circle.fill")
                        Text(proxyManager.isRunning ? "停止" : "启动")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(proxyManager.isRunning ? Color.red : Color.green)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            if proxyManager.isRunning {
                Divider()
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("上传")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Image(systemName: "arrow.up")
                                .foregroundColor(.blue)
                            Text(proxyManager.uploadSpeed)
                                .font(.system(.title3, design: .monospaced))
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("下载")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Text(proxyManager.downloadSpeed)
                                .font(.system(.title3, design: .monospaced))
                            Image(systemName: "arrow.down")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// 快速操作卡片
struct QuickActionsCard: View {
    @EnvironmentObject var proxyManager: ProxyManager
    @EnvironmentObject var configManager: ConfigManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(Color.accentColor)
                Text("快速操作")
                    .font(.headline)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                // 模式切换按钮
                ForEach(ProxyMode.allCases, id: \.self) { mode in
                    Button(action: {
                        Task {
                            await proxyManager.setMode(mode)
                        }
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: mode.icon)
                                .font(.title2)
                                .foregroundColor(proxyManager.currentMode == mode ? .white : Color.accentColor)
                            Text(mode.rawValue)
                                .font(.caption)
                                .foregroundColor(proxyManager.currentMode == mode ? .white : .primary)
                        }
                        .frame(height: 60)
                        .frame(maxWidth: .infinity)
                        .background(proxyManager.currentMode == mode ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.accentColor, lineWidth: proxyManager.currentMode == mode ? 0 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// 节点状态卡片
struct NodeStatusCard: View {
    @EnvironmentObject var nodeManager: NodeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(Color.accentColor)
                Text("节点状态")
                    .font(.headline)
                Spacer()
                
                Button("测试延迟") {
                    Task {
                        await nodeManager.testAllNodesDelay()
                    }
                }
                .disabled(nodeManager.isTesting)
            }
            
            if let selectedNode = nodeManager.selectedNode {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("当前节点")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(selectedNode.name)
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    if let delay = selectedNode.delay {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("延迟")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(delay)ms")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(delay < 200 ? .green : delay < 500 ? .orange : .red)
                        }
                    }
                }
            } else {
                Text("未选择节点")
                    .foregroundColor(.secondary)
            }
            
            if !nodeManager.nodes.isEmpty {
                Divider()
                
                HStack {
                    Text("总节点数: \(nodeManager.nodes.count)")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    let availableNodes = nodeManager.nodes.filter { $0.delay != nil && $0.delay! < 1000 }
                    Text("可用: \(availableNodes.count)")
                        .foregroundColor(.green)
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// 配置信息卡片
struct ConfigInfoCard: View {
    @EnvironmentObject var configManager: ConfigManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(Color.accentColor)
                Text("配置信息")
                    .font(.headline)
                Spacer()
                
                Button("更新订阅") {
                    Task {
                        await configManager.updateSubscription()
                    }
                }
                .disabled(configManager.isUpdating)
            }
            
            if let currentConfig = configManager.currentConfig {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("当前配置:")
                            .foregroundColor(.secondary)
                        Text(currentConfig.name)
                            .fontWeight(.medium)
                    }
                    
                    if let lastUpdate = configManager.lastUpdateTime {
                        HStack {
                            Text("最后更新:")
                                .foregroundColor(.secondary)
                            Text(lastUpdate, style: .relative)
                                .fontWeight(.medium)
                        }
                    }
                }
            } else {
                Text("未加载配置")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// 代理节点视图
struct ProxiesView: View {
    @Binding var searchText: String
    @EnvironmentObject var nodeManager: NodeManager
    @State private var sortOption: NodeSortOption = .name
    @State private var showingFastNodesOnly = false
    
    var filteredNodes: [ProxyNode] {
        var nodes = nodeManager.nodes
        
        // 搜索过滤
        if !searchText.isEmpty {
            nodes = nodes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        // 快速节点过滤
        if showingFastNodesOnly {
            nodes = nodes.filter { $0.delay != nil && $0.delay! < 300 }
        }
        
        // 排序
        switch sortOption {
        case .name:
            nodes.sort { $0.name < $1.name }
        case .delay:
            nodes.sort { 
                guard let delay1 = $0.delay, let delay2 = $1.delay else {
                    return $0.delay != nil
                }
                return delay1 < delay2
            }
        }
        
        return nodes
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 过滤器工具栏
            HStack {
                Picker("排序", selection: $sortOption) {
                    ForEach(NodeSortOption.allCases, id: \.self) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
                
                Spacer()
                
                Toggle("仅显示快速节点", isOn: $showingFastNodesOnly)
                
                Text("共 \(filteredNodes.count) 个节点")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 节点列表
            List(filteredNodes, id: \.name) { node in
                DetailedNodeRowView(node: node)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .listStyle(PlainListStyle())
        }
    }
}

// 节点行视图（详细版本）
struct DetailedNodeRowView: View {
    let node: ProxyNode
    @EnvironmentObject var nodeManager: NodeManager
    
    var body: some View {
        HStack(spacing: 12) {
            // 节点选择按钮
            Button(action: {
                Task {
                    await nodeManager.selectNode(node)
                }
            }) {
                Circle()
                    .fill(nodeManager.selectedNode?.name == node.name ? Color.accentColor : Color.clear)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(Color.secondary, lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .opacity(nodeManager.selectedNode?.name == node.name ? 1 : 0)
                    )
            }
            .buttonStyle(.plain)
            
            // 节点信息
            VStack(alignment: .leading, spacing: 4) {
                Text(node.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Text(node.type.uppercased())
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text(node.server)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(":\(node.port)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 延迟信息
            if let delay = node.delay {
                Text("\(delay)ms")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(delay < 200 ? .green : delay < 500 ? .orange : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (delay < 200 ? Color.green : delay < 500 ? Color.orange : Color.red)
                            .opacity(0.1)
                    )
                    .cornerRadius(6)
            } else {
                Text("未测试")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            Task {
                await nodeManager.selectNode(node)
            }
        }
    }
}

// 配置管理视图
struct ConfigsView: View {
    @EnvironmentObject var configManager: ConfigManager
    @State private var showingAddConfig = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 配置列表
            List {
                ForEach(configManager.configs, id: \.id) { config in
                    ConfigRowView(config: config)
                }
                .onDelete(perform: deleteConfigs)
            }
            .listStyle(PlainListStyle())
            
            // 添加配置按钮
            HStack {
                Spacer()
                Button("添加配置") {
                    showingAddConfig = true
                }
                .buttonStyle(DefaultButtonStyle())
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .sheet(isPresented: $showingAddConfig) {
            AddConfigView()
        }
    }
    
    func deleteConfigs(offsets: IndexSet) {
        configManager.deleteConfigs(at: offsets)
    }
}

// 配置行视图
struct ConfigRowView: View {
    let config: ClashConfig
    @EnvironmentObject var configManager: ConfigManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(config.name)
                    .font(.headline)
                
                if let url = config.subscriptionURL {
                    Text(url)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if let lastUpdate = config.lastUpdate {
                    Text("最后更新: \(lastUpdate, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if configManager.currentConfig?.id == config.id {
                    Text("当前使用")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                
                Button("切换") {
                    Task {
                        await configManager.switchToConfig(config)
                    }
                }
                .disabled(configManager.currentConfig?.id == config.id)
            }
        }
        .padding(.vertical, 4)
    }
}

// 添加配置视图
struct AddConfigView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var configManager: ConfigManager
    @State private var configName = ""
    @State private var subscriptionURL = ""
    @State private var configType: ConfigType = .subscription
    
    var body: some View {
        NavigationView {
            Form {
                Group {
                    Text("配置信息")
                        .font(.headline)
                        .padding(.top)
                    
                    TextField("配置名称", text: $configName)
                    
                    Picker("配置类型", selection: $configType) {
                        ForEach(ConfigType.allCases, id: \.self) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                if configType == .subscription {
                    Group {
                        Text("订阅链接")
                            .font(.headline)
                            .padding(.top)
                        
                        TextField("https://example.com/config.yaml", text: $subscriptionURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
            }
            .navigationTitle("添加配置")
            // .navigationBarTitleDisplayMode(.inline) - macOS 不可用
            // 暂时移除 toolbar 以避免兼容性问题
            HStack {
                Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                }
                Spacer()
                Button("添加") {
                    Task {
                        await addConfig()
                    }
                }
                .disabled(configName.isEmpty || (configType == .subscription && subscriptionURL.isEmpty))
            }
            .padding()
        }
        .frame(width: 500, height: 300)
    }
    
    func addConfig() async {
        await configManager.addConfig(name: configName, subscriptionURL: configType == .subscription ? subscriptionURL : nil)
        presentationMode.wrappedValue.dismiss()
    }
}

// 日志视图
struct LogsView: View {
    @State private var logs: [String] = []
    @State private var autoScroll = true
    
    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                Toggle("自动滚动", isOn: $autoScroll)
                
                Spacer()
                
                Button("清空日志") {
                    logs.removeAll()
                }
                
                Button("刷新") {
                    loadLogs()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 日志内容
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(logs.enumerated()), id: \.offset) { index, log in
                            Text(log)
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal)
                                .padding(.vertical, 1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(index % 2 == 0 ? Color.clear : Color.secondary.opacity(0.05))
                                .id(index)
                        }
                    }
                }
                .onChange(of: logs.count) { _ in
                    if autoScroll && !logs.isEmpty {
                        withAnimation {
                            proxy.scrollTo(logs.count - 1, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .onAppear {
            loadLogs()
        }
    }
    
    func loadLogs() {
        // 这里应该从 Clash 核心获取日志
        // 临时使用模拟数据
        logs = [
            "2024-01-15 10:30:00 [INFO] Clash started",
            "2024-01-15 10:30:01 [INFO] HTTP proxy listening at 127.0.0.1:7890",
            "2024-01-15 10:30:01 [INFO] SOCKS proxy listening at 127.0.0.1:7891",
            "2024-01-15 10:30:01 [INFO] RESTful API listening at 127.0.0.1:9090",
            "2024-01-15 10:30:05 [INFO] [TCP] www.google.com:443 --> Proxy",
            "2024-01-15 10:30:06 [INFO] [TCP] github.com:443 --> Proxy",
        ]
    }
}

// 设置视图
struct SettingsView: View {
    @EnvironmentObject var configManager: ConfigManager
    @EnvironmentObject var proxyManager: ProxyManager
    @State private var launchAtLogin = false
    @State private var autoUpdateConfigs = true
    @State private var updateInterval = 6.0
    @State private var showNotifications = true
    
    var body: some View {
        Form {
            Group {
                Text("代理设置")
                    .font(.headline)
                    .padding(.top)
                
                HStack {
                    Text("HTTP 端口")
                    Spacer()
                    TextField("7890", text: .constant("7890"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 100)
                }
                
                HStack {
                    Text("SOCKS 端口")
                    Spacer()
                    TextField("7891", text: .constant("7891"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 100)
                }
                
                HStack {
                    Text("API 端口")
                    Spacer()
                    TextField("9090", text: .constant("9090"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 100)
                }
            }
            
            Group {
                Text("应用设置")
                    .font(.headline)
                    .padding(.top)
                
                Toggle("开机自启动", isOn: $launchAtLogin)
                
                Toggle("显示通知", isOn: $showNotifications)
            }
            
            Group {
                Text("配置更新")
                    .font(.headline)
                    .padding(.top)
                
                Toggle("自动更新配置", isOn: $autoUpdateConfigs)
                
                if autoUpdateConfigs {
                    HStack {
                        Text("更新间隔")
                        Spacer()
                        HStack {
                            Slider(value: $updateInterval, in: 1...24, step: 1) {
                                Text("小时")
                            }
                            .frame(width: 200)
                            
                            Text("\(Int(updateInterval)) 小时")
                                .frame(width: 60, alignment: .leading)
                        }
                    }
                }
            }
            
            Group {
                Text("关于")
                    .font(.headline)
                    .padding(.top)
                
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text("1")
                }
                
                Button("检查更新") {
                    // TODO: 实现更新检查
                }
            }
        }
        // .formStyle(.grouped) - 仅在 macOS 13+ 可用
        .frame(maxWidth: 600)
    }
}

// 辅助枚举和结构体
enum SidebarItem: String, CaseIterable {
    case dashboard = "dashboard"
    case proxies = "proxies"
    case configs = "configs"
    case logs = "logs"
    case settings = "settings"
    
    var title: String {
        switch self {
        case .dashboard: return "仪表板"
        case .proxies: return "代理节点"
        case .configs: return "配置管理"
        case .logs: return "日志"
        case .settings: return "设置"
        }
    }
    
    var icon: String {
        switch self {
        case .dashboard: return "gauge"
        case .proxies: return "globe"
        case .configs: return "doc.text"
        case .logs: return "terminal"
        case .settings: return "gearshape"
        }
    }
}

enum NodeSortOption: String, CaseIterable {
    case name = "name"
    case delay = "delay"
    
    var title: String {
        switch self {
        case .name: return "名称"
        case .delay: return "延迟"
        }
    }
}

enum ConfigType: String, CaseIterable {
    case subscription = "subscription"
    case local = "local"
    
    var title: String {
        switch self {
        case .subscription: return "订阅"
        case .local: return "本地"
        }
    }
}

// 扩展
extension ProxyMode {
    var icon: String {
        switch self {
        case .global: return "globe"
        case .rule: return "list.bullet"
        case .direct: return "arrow.right"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ConfigManager())
        .environmentObject(ProxyManager())
        .environmentObject(NodeManager())
}

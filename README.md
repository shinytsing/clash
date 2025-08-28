# ClashX for macOS

一款专为 macOS 设计的现代化 Clash 客户端，提供直观的图形界面和强大的代理管理功能。

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS%2011.0+-orange.svg)
![Swift](https://img.shields.io/badge/Swift-5.0+-red.svg)

## ✨ 特性

### 🚀 核心功能
- **一键启停代理** - 快速启用/停用系统代理
- **智能模式切换** - 支持全局、规则、直连三种模式
- **订阅管理** - 支持订阅链接自动更新配置
- **节点管理** - 可视化节点列表，支持延迟测试
- **流量监控** - 实时显示上传下载速度和流量统计

### 🎨 用户体验
- **原生 macOS 设计** - 遵循苹果设计规范，支持深色模式
- **菜单栏集成** - 便捷的菜单栏控制，一键访问常用功能
- **现代化界面** - 使用 SwiftUI 构建的现代化用户界面
- **系统集成** - 自动管理系统代理设置，无需手动配置

### ⚡ 高级功能
- **自动延迟测试** - 定期测试节点延迟，自动选择最优节点
- **配置热切换** - 无需重启即可切换配置文件
- **智能分流** - 基于规则的智能流量分发
- **开机自启** - 支持开机自动启动

## 📋 系统要求

- macOS 11.0 (Big Sur) 或更高版本
- 支持 Intel 和 Apple Silicon (M1/M2) 芯片

## 🚀 快速开始

### 方法一：使用 Xcode 构建

1. **克隆项目**
   ```bash
   git clone https://github.com/your-username/clashx-macos.git
   cd clashx-macos
   ```

2. **安装依赖**
   - 确保安装了 Xcode 14.0 或更高版本
   - 打开 `ClashX.xcodeproj`

3. **添加 Clash 核心**
   - 下载 Clash 核心二进制文件 (clash-darwin)
   - 将其重命名为 `clash-darwin` 并放置在项目的 Resources 目录中

4. **构建运行**
   - 在 Xcode 中选择目标设备并运行项目
   - 或使用命令行：`xcodebuild -project ClashX.xcodeproj -scheme ClashX build`

### 方法二：使用预编译版本

1. 从 [Releases](https://github.com/your-username/clashx-macos/releases) 页面下载最新版本
2. 解压并拖拽到应用程序文件夹
3. 首次运行时，可能需要在系统偏好设置中允许运行

## 📖 使用指南

### 首次配置

1. **启动应用**
   - 启动后会在菜单栏显示网络图标
   - 点击图标打开快捷菜单

2. **添加配置**
   - 点击"配置管理"打开主窗口
   - 点击"添加配置"按钮
   - 输入订阅链接或导入本地配置文件

3. **启动代理**
   - 在菜单栏或主窗口中点击"启动代理"
   - 选择合适的代理模式
   - 系统代理将自动配置

### 配置文件格式

支持标准的 Clash 配置格式（YAML），示例配置：

```yaml
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
  - name: "节点1"
    type: trojan
    server: example.com
    port: 443
    password: password

proxy-groups:
  - name: "PROXY"
    type: select
    proxies: ["节点1"]

rules:
  - MATCH,PROXY
```

### 订阅链接

应用支持以下格式的订阅链接：
- 标准 Clash 订阅链接
- YAML 格式配置文件链接

## ⚙️ 配置选项

### 代理模式
- **全局模式** - 所有流量都通过代理
- **规则模式** - 根据规则智能分流（推荐）
- **直连模式** - 所有流量直连，不使用代理

### 自动化设置
- **开机自启动** - 系统启动时自动运行
- **自动更新订阅** - 定期更新订阅配置
- **自动选择节点** - 基于延迟自动选择最优节点

## 🔧 故障排除

### 常见问题

**Q: 应用无法启动代理**
A: 检查以下项目：
- 确保配置文件格式正确
- 检查网络连接
- 查看应用日志获取详细错误信息

**Q: 无法访问某些网站**
A: 尝试以下解决方案：
- 切换到全局模式
- 更新订阅配置
- 手动选择其他节点

**Q: 系统代理设置失效**
A: 
- 检查应用是否有系统偏好设置权限
- 手动重置网络代理设置
- 重启应用

### 日志查看

在主窗口的"日志"选项卡中可以查看详细的运行日志，有助于诊断问题。

## 🛠️ 开发

### 项目结构

```
ClashX/
├── ClashXApp.swift           # 应用入口
├── Core/
│   └── ClashCore.swift       # Clash 核心管理
├── Managers/
│   ├── ConfigManager.swift   # 配置管理
│   ├── ProxyManager.swift    # 代理管理
│   ├── NodeManager.swift     # 节点管理
│   └── NetworkManager.swift  # 网络管理
├── Models/
│   └── ProxyModels.swift     # 数据模型
├── UI/
│   ├── ContentView.swift     # 主界面
│   └── MenuBarController.swift # 菜单栏控制
└── Resources/
    └── clash-darwin          # Clash 核心二进制
```

### 技术栈

- **语言**: Swift 5.0+
- **框架**: SwiftUI + AppKit
- **架构**: MVVM
- **网络**: URLSession + Combine
- **存储**: UserDefaults + FileManager

### 贡献指南

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 开启 Pull Request

## 📄 许可证

本项目基于 MIT 许可证开源 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

- [Clash](https://github.com/Dreamacro/clash) - 强大的代理核心
- [ClashX](https://github.com/yichengchen/clashX) - 原始 ClashX 项目的灵感来源
- Apple - 提供优秀的开发工具和框架

## 🔗 相关链接

- [Clash 文档](https://clash.gitbook.io/doc/)
- [Clash 规则集](https://github.com/Loyalsoldier/clash-rules)
- [macOS 开发指南](https://developer.apple.com/macos/)

## 📧 支持

如果你有任何问题或建议，欢迎：
- 提交 [Issue](https://github.com/your-username/clashx-macos/issues)
- 发起 [Discussion](https://github.com/your-username/clashx-macos/discussions)
- 发邮件至 your-email@example.com

---

⭐ 如果这个项目对你有帮助，请给它一个 Star！

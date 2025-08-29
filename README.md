# ClashX - macOS 代理客户端

一个功能完整的 macOS 代理客户端，基于 SwiftUI 构建，支持多种代理协议。

## 🎉 项目状态

✅ **已完全修复并可运行** - 从损坏的项目文件修复到完整可用的应用程序

## ✨ 功能特性

- 🖥️ **现代化 SwiftUI 界面** - 原生 macOS 体验
- 🌐 **多协议支持** - Trojan、Shadowsocks、VMess 等
- ⚙️ **配置管理** - 支持本地配置和订阅更新
- 📊 **流量监控** - 实时网络流量统计
- 🔧 **系统代理** - 自动配置 macOS 系统代理设置
- 🎯 **规则引擎** - 智能分流和广告拦截
- 📱 **菜单栏集成** - 便捷的状态栏控制

## 🛠️ 修复内容

### 核心修复
- ✅ 修复损坏的 Xcode 项目文件 (`project.pbxproj`)
- ✅ 解决 SwiftUI macOS 版本兼容性问题
- ✅ 修复 `NavigationSplitView`、`@ToolbarContentBuilder` 等新 API 兼容性
- ✅ 解决 `SystemConfiguration` 框架使用问题
- ✅ 修复并发和主线程调用问题

### 功能完善
- ✅ 完整的配置管理系统
- ✅ 真实代理配置集成
- ✅ 网络权限配置优化
- ✅ 完整的 UI 界面实现

## 📁 项目结构

```
ClashX/
├── ClashXApp.swift          # 应用程序入口
├── Core/                    # 核心功能模块
│   ├── ClashCore.swift      # Clash 核心管理
│   ├── SystemProxyHelper.swift # 系统代理设置
│   └── YAMLParser.swift     # 配置解析
├── Managers/                # 管理器类
│   ├── ConfigManager.swift  # 配置管理
│   ├── NetworkManager.swift # 网络管理
│   ├── NodeManager.swift    # 节点管理
│   └── ProxyManager.swift   # 代理管理
├── Models/                  # 数据模型
│   └── ProxyModels.swift    # 代理相关模型
├── UI/                      # 用户界面
│   ├── ContentView.swift    # 主界面
│   └── MenuBarController.swift # 菜单栏控制
└── Resources/               # 资源文件
    ├── clash-darwin         # Clash 核心二进制
    └── default-config.yaml  # 默认配置
```

## 🚀 构建和运行

### 环境要求
- macOS 12.0+
- Xcode 14.0+
- Swift 5.7+

### 构建步骤

1. **克隆仓库**
   ```bash
   git clone git@github.com:shinytsing/clash.git
   cd clash
   ```

2. **打开项目**
   ```bash
   open ClashX.xcodeproj
   ```

3. **编译运行**
   - 在 Xcode 中选择目标设备
   - 按 `Cmd+R` 编译运行

### 配置设置

1. 启动应用程序
2. 在配置页面导入你的代理配置
3. 或者将配置文件放在 `~/Library/Application Support/ClashX/configs/`
4. 点击"启动代理"开始使用

## 📖 使用说明

### 界面导航
- **仪表盘** - 查看连接状态和流量统计
- **代理** - 管理代理节点和测试延迟
- **配置** - 管理配置文件和订阅
- **日志** - 查看运行日志
- **设置** - 应用程序设置

### 代理模式
- **规则模式** - 根据规则自动分流
- **全局模式** - 所有流量通过代理
- **直连模式** - 不使用代理

## 🔧 故障排除

### 常见问题

1. **编译失败**
   - 确保 Xcode 版本符合要求
   - 清理构建缓存 (`Cmd+Shift+K`)

2. **代理无法启动**
   - 检查配置文件格式是否正确
   - 确保代理服务器地址可访问

3. **权限问题**
   - 应用程序已配置必要的网络权限
   - 首次运行可能需要授权

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

本项目基于 MIT 许可证开源。

## 📞 支持

如有问题，请通过以下方式联系：
- 提交 GitHub Issue
- 发送邮件反馈

---

**注意**: 本项目仅供学习和研究使用，请遵守当地法律法规。
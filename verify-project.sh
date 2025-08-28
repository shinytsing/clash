#!/bin/bash

# ClashX 项目验证脚本
# 检查项目结构和文件完整性

set -e

PROJECT_ROOT=$(pwd)
echo "🔍 验证 ClashX 项目结构..."

# 检查主要目录结构
echo "📁 检查目录结构:"
EXPECTED_DIRS=(
    "ClashX"
    "ClashX/Core"
    "ClashX/Managers"
    "ClashX/Models"
    "ClashX/UI"
    "ClashX/Resources"
    "ClashX/Preview Content"
    "ClashX/Assets.xcassets"
)

for dir in "${EXPECTED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "✅ $dir"
    else
        echo "❌ $dir (缺失)"
    fi
done

echo ""
echo "📄 检查核心源文件:"
EXPECTED_FILES=(
    "ClashX/ClashXApp.swift"
    "ClashX/Core/ClashCore.swift"
    "ClashX/Core/YAMLParser.swift"
    "ClashX/Core/SystemProxyHelper.swift"
    "ClashX/Managers/ConfigManager.swift"
    "ClashX/Managers/ProxyManager.swift"
    "ClashX/Managers/NodeManager.swift"
    "ClashX/Managers/NetworkManager.swift"
    "ClashX/Models/ProxyModels.swift"
    "ClashX/UI/ContentView.swift"
    "ClashX/UI/MenuBarController.swift"
    "ClashX/ClashX.entitlements"
)

for file in "${EXPECTED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file (缺失)"
    fi
done

echo ""
echo "🔧 检查配置文件:"
CONFIG_FILES=(
    "ClashX.xcodeproj/project.pbxproj"
    "sample-config.yaml"
    "ClashX/Resources/default-config.yaml"
    "README.md"
    "build.sh"
)

for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file (缺失)"
    fi
done

echo ""
echo "📊 统计信息:"
echo "Swift 文件数量: $(find ClashX -name "*.swift" | wc -l | tr -d ' ')"
echo "总行数: $(find ClashX -name "*.swift" -exec wc -l {} + | tail -1 | awk '{print $1}')"

echo ""
echo "🔍 检查语法错误 (简单检查):"
find ClashX -name "*.swift" -exec echo "检查 {}" \; -exec swift -parse {} > /dev/null 2>&1 \; -exec echo "✅ {} 语法正确" \; || echo "❌ {} 存在语法错误"

echo ""
echo "✅ 项目验证完成!"
echo ""
echo "💡 下一步:"
echo "1. 运行构建脚本: ./build.sh"
echo "2. 使用 Xcode 打开项目: open ClashX.xcodeproj"
echo "3. 构建并运行应用"

#!/bin/bash
#
# FeiQiu 自动构建 + DMG 打包脚本
# 用法: ./scripts/build.sh
#

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

cd "$PROJECT_DIR"

echo "🛠️  FeiQiu macOS 构建脚本"
echo "========================="
echo "项目目录: $PROJECT_DIR"
echo ""

# 检查依赖
if ! command -v xcodegen &> /dev/null; then
    echo "❌ 未安装 XcodeGen，请运行: brew install xcodegen"
    exit 1
fi

if ! command -v xcodebuild &> /dev/null; then
    echo "❌ 未找到 xcodebuild，请安装 Xcode"
    exit 1
fi

# 1. 生成 Xcode 项目
echo "📦 步骤 1/4: 生成 Xcode 项目..."
xcodegen generate
echo "   ✓ 完成"
echo ""

# 2. 清理之前的构建
echo "🧹 步骤 2/4: 清理旧构建..."
rm -rf build
xcodebuild clean -project FeiQiu.xcodeproj -scheme FeiQiu -configuration Release > /dev/null
echo "   ✓ 完成"
echo ""

# 3. 编译 Release 版本
echo "🔨 步骤 3/4: 编译 Release 版本..."
xcodebuild build \
    -project FeiQiu.xcodeproj \
    -scheme FeiQiu \
    -configuration Release \
    -derivedDataPath build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    | xcpretty 2>/dev/null || xcodebuild build \
    -project FeiQiu.xcodeproj \
    -scheme FeiQiu \
    -configuration Release \
    -derivedDataPath build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO
echo "   ✓ 完成"
echo ""

APP_PATH="build/Build/Products/Release/FeiQiu.app"
if [ ! -d "$APP_PATH" ]; then
    echo "❌ 找不到编译产物: $APP_PATH"
    exit 1
fi

# 4. 打包 DMG
echo "📀 步骤 4/4: 打包 DMG..."
DMG_DIR="build/dmg"
mkdir -p "$DMG_DIR"
cp -R "$APP_PATH" "$DMG_DIR/"
ln -sf /Applications "$DMG_DIR/Applications"

DMG_NAME="FeiQiu-$(date +%Y%m%d).dmg"
rm -f "$DMG_NAME"

hdiutil create -volname "飞秋 FeiQiu" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    "$DMG_NAME"

echo "   ✓ 完成"
echo ""
echo "🎉 构建成功！"
echo ""
echo "应用位置: $PROJECT_DIR/$APP_PATH"
echo "DMG 位置: $PROJECT_DIR/$DMG_NAME"
echo ""
echo "可以打开 DMG 安装："
echo "  open '$DMG_NAME'"

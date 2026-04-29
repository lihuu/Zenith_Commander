#!/bin/bash

# ==============================================================================
# Zenith Commander - Custom Archive 脚本
# 功能: 生成 Archive 归档并导出 App (类似 Xcode Organizer -> Custom -> Copy App)
# ==============================================================================

# --- 1. 配置区域 (与 build-dmg.sh 保持一致) ---

# [输入] 你的 App 名称 (不带 .app 后缀)
APP_NAME="Zenith Commander"

# [输入] Xcode 项目路径
PROJECT_DIR="."
PROJECT_NAME="Zenith Commander.xcodeproj"

# [输入] Scheme 名称 (通常与 App 名称相同)
SCHEME_NAME="Zenith Commander"

# [输入] 构建配置
CONFIGURATION="Release"

# [输入] Archive 输出目录
ARCHIVE_DIR="./build"

# [输入] 导出目录 (导出的 .app 将放在这里)
EXPORT_DIR="./build"

# ------------------------------------------------------------------------------

# --- 2. 派生变量 ---

ARCHIVE_PATH="${ARCHIVE_DIR}/${APP_NAME}.xcarchive"
EXPORT_PATH="${EXPORT_DIR}/${APP_NAME} $(date +%Y%m%d_%H%M%S)"
PROJECT_PATH="${PROJECT_DIR}/${PROJECT_NAME}"

# --- 3. 环境检查 ---

echo "🔍 检查环境..."

# 检查 xcodebuild 是否可用
if ! command -v xcodebuild &>/dev/null; then
    echo "❌ 错误: 未检测到 'xcodebuild' 工具。"
    echo "   请确保已安装 Xcode 命令行工具。"
    exit 1
fi

# 检查项目是否存在
if [ ! -d "$PROJECT_PATH" ]; then
    echo "❌ 错误: 找不到项目: $PROJECT_PATH"
    exit 1
fi

# 准备输出目录
mkdir -p "$ARCHIVE_DIR"
mkdir -p "$EXPORT_PATH"

# 清理旧的 Archive (如果存在)
if [ -d "$ARCHIVE_PATH" ]; then
    echo "🗑️  清理旧的 Archive..."
    rm -rf "$ARCHIVE_PATH"
fi

# --- 4. 生成 Archive ---

echo ""
echo "📦 开始生成 Archive..."
echo "   Project:   $PROJECT_PATH"
echo "   Scheme:    $SCHEME_NAME"
echo "   Archive:   $ARCHIVE_PATH"
echo ""

xcodebuild archive \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME_NAME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=macOS" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

if [ $? -ne 0 ]; then
    echo "❌ Archive 生成失败，请检查上方错误日志。"
    exit 1
fi

# 验证 Archive 是否成功
if [ ! -d "$ARCHIVE_PATH" ]; then
    echo "❌ 错误: Archive 生成失败，未找到: $ARCHIVE_PATH"
    exit 1
fi

echo "✅ Archive 生成成功!"

# --- 5. 导出 App (Copy App) ---

echo ""
echo "📤 导出 App 到: $EXPORT_PATH"

# 从 Archive 中复制 .app
APP_IN_ARCHIVE="${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app"

if [ ! -d "$APP_IN_ARCHIVE" ]; then
    echo "❌ 错误: 在 Archive 中找不到 App: $APP_IN_ARCHIVE"
    exit 1
fi

# 复制 App 到导出目录
cp -R "$APP_IN_ARCHIVE" "$EXPORT_PATH/"

# --- 6. 结果验证 ---

EXPORTED_APP="${EXPORT_PATH}/${APP_NAME}.app"

if [ -d "$EXPORTED_APP" ]; then
    echo ""
    echo "✅ 导出成功!"
    echo "📂 Archive 路径: $ARCHIVE_PATH"
    echo "📂 App 导出路径: $EXPORTED_APP"
    echo ""
    
    # 显示 App 信息
    echo "📋 App 信息:"
    /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${EXPORTED_APP}/Contents/Info.plist" 2>/dev/null && \
        echo "   版本: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${EXPORTED_APP}/Contents/Info.plist")"
    /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "${EXPORTED_APP}/Contents/Info.plist" 2>/dev/null && \
        echo "   Build: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${EXPORTED_APP}/Contents/Info.plist")"
    
    # 可选: 在 Finder 中打开导出目录
    open "$EXPORT_PATH"
else
    echo ""
    echo "❌ 导出失败，请检查上方错误日志。"
    exit 1
fi

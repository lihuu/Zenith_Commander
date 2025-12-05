#!/bin/bash

# ==============================================================================
# Zenith Commander - DMG 打包构建脚本
# ==============================================================================

# --- 1. 配置区域 (请修改这里) ---

# [输入] 你的 App 名称 (不带 .app 后缀)
APP_NAME="Zenith Commander"

# [输入] 你的 .app 文件所在的路径 (可以是相对路径或绝对路径)
# 通常 Xcode Archive 后导出，或者在 Build 目录中
APP_SOURCE_DIR="./build/Release"

# [输入] 打包后的 DMG 输出路径
OUTPUT_DIR="./dist"

# [输入] (可选) DMG 背景图片的路径
# 图片建议尺寸: 600x400 或 800x500, 格式推荐 png 或 jpg
# 如果没有背景图，请将此行注释掉
# INSTALLER_BACKGROUND="./assets/dmg-background.png"

# [输入] (可选) 图标大小 (像素)
ICON_SIZE=120

# ------------------------------------------------------------------------------

# --- 2. 环境检查 ---

# 检查 create-dmg 是否安装
if ! command -v create-dmg &>/dev/null; then
  echo "❌ 错误: 未检测到 'create-dmg' 工具。"
  echo "   请先运行: brew install create-dmg"
  exit 1
fi

# 准备一下来源文件

# 删除旧的 APP_SOURCE_DIR 目录（如果存在的话）

if [ -d "$APP_SOURCE_DIR" ]; then
  echo "🗑️  清理旧的 App 源文件目录..."
  rm -rf "$APP_SOURCE_DIR"
fi

# 将构建输出，重命名为Release目录（输出目录是：Zenith Commander 开头的一个目录）
BUILT_APP_DIR=$(find ./build -type d -name "${APP_NAME}*" | head -n 1)
if [ -z "$BUILT_APP_DIR" ]; then
  echo "❌ 错误: 未找到构建输出目录。请确保 Xcode 构建已完成。"
  exit 1
fi
mv "$BUILT_APP_DIR" "$APP_SOURCE_DIR"


# 检查源文件是否存在
APP_PATH="${APP_SOURCE_DIR}/${APP_NAME}.app"
if [ ! -d "$APP_PATH" ]; then
  echo "❌ 错误: 找不到 App 文件: $APP_PATH"
  echo "   请确认 Xcode 构建已完成，并且路径配置正确。"
  exit 1
fi

# 准备输出目录
mkdir -p "$OUTPUT_DIR"
DMG_PATH="${OUTPUT_DIR}/${APP_NAME}.dmg"

# 如果旧的 dmg 存在，先删除
if [ -f "$DMG_PATH" ]; then
  echo "🗑️  清理旧的 DMG 文件..."
  rm "$DMG_PATH"
fi

echo "🚀 开始构建 ${APP_NAME}.dmg ..."

# --- 3. 构建参数组装 ---

# 基础参数
CREATE_DMG_ARGS=(
  --volname "${APP_NAME} Installer"  # 挂载后的卷名
  --window-pos 200 120               # 打开时的窗口位置
  --window-size 800 500              # 窗口大小 (根据你的背景图调整)
  --icon-size "$ICON_SIZE"           # 图标大小
  --text-size 14                     # 字体大小
  --app-drop-link 600 235            # "Applications" 快捷方式图标的位置 (x, y)
  --icon "${APP_NAME}.app" 200 235   # 你的 App 图标的位置 (x, y)
  --hide-extension "${APP_NAME}.app" # 隐藏 .app 后缀
)

# 如果配置了背景图，添加背景参数
if [ ! -z "$INSTALLER_BACKGROUND" ] && [ -f "$INSTALLER_BACKGROUND" ]; then
  echo "🖼️  使用自定义背景图: $INSTALLER_BACKGROUND"
  CREATE_DMG_ARGS+=(--background "$INSTALLER_BACKGROUND")
fi

# --- 4. 执行打包 ---

# 运行 create-dmg
create-dmg "${CREATE_DMG_ARGS[@]}" "$DMG_PATH" "$APP_SOURCE_DIR"

# --- 5. 结果验证 ---

if [ -f "$DMG_PATH" ]; then
  echo ""
  echo "✅ 打包成功!"
  echo "📂 输出文件: $DMG_PATH"
  # 可选: 构建完成后自动在 Finder 中打开输出目录
  open "$OUTPUT_DIR"
else
  echo ""
  echo "❌ 打包失败，请检查上方错误日志。"
  exit 1
fi

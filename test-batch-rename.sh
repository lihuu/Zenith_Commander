#!/bin/bash

# 测试批量重命名功能

set -e

echo "=== 批量重命名功能测试 ==="
echo ""

# 1. 创建测试目录和文件
TEST_DIR="/tmp/zenith_batch_rename_test"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

echo "1. 创建测试文件..."
cd "$TEST_DIR"
touch "document1.txt" "document2.txt" "image1.JPG" "image2.PNG"
ls -l
echo ""

# 2. 测试 URL Scheme
echo "2. 测试 URL Scheme 调用主应用..."
echo "   URL: zenith-commander://batch-rename?files=..."

FILES="$TEST_DIR/document1.txt,$TEST_DIR/document2.txt,$TEST_DIR/image1.JPG"
URL="zenith-commander://batch-rename?files=$FILES"

echo "   打开主应用并传递文件列表..."
open "$URL"

echo ""
echo "✅ 测试脚本完成！"
echo ""
echo "请检查："
echo "1. Zenith Commander 应用是否打开"
echo "2. 查看系统日志："
echo "   log stream --predicate 'process CONTAINS \"Zenith\"' --level debug"
echo ""
echo "FinderSync Extension 测试："
echo "1. 在 Finder 中打开 $TEST_DIR"
echo "2. 选中多个文件"
echo "3. 右键 → 批量重命名 → 自定义规则"
echo ""
echo "测试文件位置: $TEST_DIR"

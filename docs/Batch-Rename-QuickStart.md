# 批量重命名功能 - 快速开始

## 已完成的工作

✅ FinderSync Extension 菜单扩展
✅ URL Scheme 配置 (`zenith-commander://`)
✅ 主应用 URL 处理逻辑
✅ 通知机制 (`batchRenameRequested`)

## 当前状态

**可以使用的功能：**

- 选中多个文件 → 右键 → 批量重命名
  - ✅ 添加序号 (01, 02, 03...)
  - ✅ 添加前缀 (backup\_...)
  - ✅ 添加日期 (...\_2026-01-06)
  - ✅ 扩展名转小写
  - ⚠️ 自定义规则...（已实现 URL 调用，但主应用尚未实现 UI）

## 快速测试

### 1. 构建并运行应用

```bash
cd "/Users/lihu/git/Zenith Commander"
xcodebuild -scheme "Zenith Commander" -configuration Release build
open "/Users/lihu/Library/Developer/Xcode/DerivedData/Zenith_Commander-bgbemcuzqrroztapkgblljzokjof/Build/Products/Release/Zenith Commander.app"
```

### 2. 测试 URL Scheme

```bash
./test-batch-rename.sh
```

或手动测试：

```bash
open "zenith-commander://batch-rename?files=/tmp/test1.txt,/tmp/test2.txt"
```

### 3. 测试 FinderSync Extension

1. 在 Finder 中创建测试文件
2. 选中 2+ 个文件
3. 右键 → 批量重命名 → 选择任一选项

## 下一步：实现主应用批量重命名 UI

需要在主应用中添加批量重命名界面。建议步骤：

### 1. 创建批量重命名视图

```swift
// Zenith Commander/Views/BatchRenameView.swift
struct BatchRenameView: View {
    let files: [URL]
    @State private var prefix = ""
    @State private var suffix = ""
    @State private var addNumbering = false
    @State private var startNumber = 1
    // ... 更多选项

    var body: some View {
        // UI 实现
    }
}
```

### 2. 在 ContentView 或 MainView 中响应通知

```swift
@State private var showBatchRename = false
@State private var batchRenameFiles: [URL] = []

var body: some View {
    // 现有内容...
    .sheet(isPresented: $showBatchRename) {
        BatchRenameView(files: batchRenameFiles)
    }
    .onReceive(NotificationCenter.default.publisher(for: .batchRenameRequested)) { notification in
        if let filePaths = notification.userInfo?["filePaths"] as? [String] {
            batchRenameFiles = filePaths.map { URL(fileURLWithPath: $0) }
            showBatchRename = true
        }
    }
}
```

### 3. 实现重命名逻辑

参考 `FinderSync.swift` 中的 `performBatchRename()` 方法。

## 调试技巧

### 查看 FinderSync 日志

```bash
log stream --predicate 'subsystem CONTAINS "FinderSync" OR process CONTAINS "Zenith"' --level debug
```

### 查看应用是否接收到 URL

在 `AppDelegate.handleURLScheme()` 中添加断点或日志。

### 重新注册 URL Scheme

```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user
```

## 项目文档

- [实现文档](./Batch-Rename-Implementation.md)
- [URL Scheme 配置指南](./URL-Scheme-Setup.md)

## 问题反馈

如遇到问题，请检查：

1. ✅ 应用已重新构建
2. ✅ FinderSync Extension 已在系统设置中启用
3. ✅ URL Scheme 已正确配置
4. ✅ 查看系统日志确认错误信息

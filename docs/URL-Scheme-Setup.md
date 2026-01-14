# URL Scheme 配置指南

## 配置步骤

为了让 FinderSync Extension 能够打开主应用并传递批量重命名的文件列表，需要配置 URL Scheme。

### 方法 1: 通过 Xcode（推荐）

1. 在 Xcode 中打开 `Zenith Commander.xcodeproj`
2. 选择左侧项目导航器中的 "Zenith Commander" 项目
3. 选择 "Zenith Commander" Target（不是 FinderSyncExtension）
4. 点击 "Info" 标签页
5. 在 "URL Types" 区域点击 "+" 添加新的 URL Type
6. 配置如下：
   - **Identifier**: `com.lihuu.top.Zenith-Commander`
   - **URL Schemes**: `zenith-commander`
   - **Role**: Editor

### 方法 2: 通过命令行

运行以下命令来配置 URL Scheme（在项目根目录下）：

```bash
# 创建 Info.plist 条目（如果不存在）
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" "Zenith Commander/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "Zenith Commander/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLName string com.lihuu.top.Zenith-Commander" "Zenith Commander/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "Zenith Commander/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string zenith-commander" "Zenith Commander/Info.plist"
```

## URL Scheme 格式

配置完成后，FinderSync Extension 会使用以下格式打开主应用：

```
zenith-commander://batch-rename?files=path1,path2,path3
```

## 代码实现

### 主应用处理 (Zenith_CommanderApp.swift)

```swift
// 在 AppDelegate 中
func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
        handleURLScheme(url)
    }
}

private func handleURLScheme(_ url: URL) {
    guard url.scheme == "zenith-commander" else { return }

    if url.host == "batch-rename" {
        handleBatchRename(url: url)
    }
}
```

### FinderSync Extension 调用

```swift
let filePaths = sortedURLs.map { $0.path }.joined(separator: ",")
let encodedPaths = filePaths.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
let urlString = "zenith-commander://batch-rename?files=\(encodedPaths)"

if let url = URL(string: urlString) {
    NSWorkspace.shared.open(url)
}
```

## 验证配置

配置完成后，重新构建应用并测试：

1. 构建并安装应用
2. 在 Terminal 中运行：
   ```bash
   open "zenith-commander://batch-rename?files=/tmp/test1.txt,/tmp/test2.txt"
   ```
3. 应该看到主应用打开并收到文件列表

## 故障排除

如果 URL Scheme 不工作：

1. 检查 `build/Release/Zenith Commander.app/Contents/Info.plist` 中是否包含 `CFBundleURLTypes`
2. 确保应用已重新构建并安装
3. 检查系统日志：
   ```bash
   log stream --predicate 'process == "Zenith Commander"' --level debug
   ```

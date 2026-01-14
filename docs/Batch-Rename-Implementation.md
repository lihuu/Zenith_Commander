# 批量重命名功能实现完成

## 实现内容

已成功实现 FinderSync Extension 通过 URL Scheme 打开主应用进行批量重命名的功能。

## 功能说明

### 1. FinderSync Extension 菜单

在 Finder 中选中 2 个或更多文件，右键菜单会显示"批量重命名"子菜单，包含：

- **添加序号 (01, 02, 03...)** - 在文件名前添加两位数序号
- **添加前缀 (backup\_...)** - 添加 `backup_` 前缀
- **添加日期 (...\_2026-01-06)** - 在文件名后添加当前日期
- **扩展名转小写** - 将文件扩展名转为小写
- **自定义规则...** - 打开主应用进行自定义批量重命名

### 2. URL Scheme 配置

已在项目中配置 URL Scheme：`zenith-commander://`

格式：`zenith-commander://batch-rename?files=path1,path2,path3`

### 3. 主应用 URL 处理

在 `AppDelegate` 中实现了 URL Scheme 处理逻辑：

```swift
func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
        handleURLScheme(url)
    }
}
```

收到批量重命名请求后，会发送通知：

```swift
NotificationCenter.default.post(
    name: .batchRenameRequested,
    object: nil,
    userInfo: ["filePaths": filePaths]
)
```

## 测试步骤

### 测试 URL Scheme（命令行）

```bash
# 创建测试文件
mkdir -p /tmp/test_rename
cd /tmp/test_rename
touch test1.txt test2.txt test3.txt

# 测试打开主应用
open "zenith-commander://batch-rename?files=/tmp/test_rename/test1.txt,/tmp/test_rename/test2.txt"
```

### 测试 FinderSync Extension

1. **重新安装应用**

   ```bash
   cd "/Users/lihu/git/Zenith Commander"
   ./build-dmg.sh
   # 安装新构建的 DMG
   ```

2. **启用 FinderSync Extension**

   - 系统设置 → 隐私与安全性 → 扩展 → Finder 扩展
   - 勾选 "FinderSyncExtension"

3. **测试菜单功能**

   - 在 Finder 中创建几个测试文件
   - 选中 2 个或更多文件
   - 右键菜单 → 批量重命名 → 选择任一选项
   - 或选择"自定义规则..."打开主应用

4. **查看日志**

   ```bash
   # 查看 FinderSync Extension 日志
   log stream --predicate 'subsystem == "com.lihuu.top.Zenith-Commander"' --level debug

   # 或查看所有相关日志
   log stream --predicate 'process CONTAINS "Zenith"' --level debug
   ```

## 后续工作

### 1. 在主应用中实现批量重命名界面

需要在主应用中添加一个批量重命名的视图，响应 `batchRenameRequested` 通知：

```swift
// 在 ContentView 或 MainView 中
.onReceive(NotificationCenter.default.publisher(for: .batchRenameRequested)) { notification in
    if let filePaths = notification.userInfo?["filePaths"] as? [String] {
        // 打开批量重命名界面
        showBatchRenameView(files: filePaths)
    }
}
```

### 2. 实现批量重命名 UI

创建一个批量重命名的视图，包含：

- 文件列表预览
- 前缀/后缀输入框
- 序号选项（起始编号、位数）
- 正则替换选项
- 预览新文件名
- 执行重命名

### 3. URL Scheme 验证问题

如果 URL Scheme 不工作，需要：

1. 在 Xcode 中打开项目
2. 选择 Target "Zenith Commander"
3. 点击 Info 标签
4. 手动添加 URL Types:
   - Identifier: `com.lihuu.top.Zenith-Commander`
   - URL Schemes: `zenith-commander`

或者确保 `INFOPLIST_KEY_CFBundleURLTypes` 在构建设置中正确应用。

## 文件变更

已修改的文件：

1. `/Users/lihu/git/Zenith Commander/FinderSyncExtension/FinderSync.swift`

   - 添加了"自定义规则"菜单项
   - 实现了 `openMainAppForBatchRename()` 方法

2. `/Users/lihu/git/Zenith Commander/Zenith Commander/Zenith_CommanderApp.swift`

   - 添加了 URL Scheme 处理逻辑
   - 添加了 `batchRenameRequested` 通知

3. `/Users/lihu/git/Zenith Commander/Zenith Commander.xcodeproj/project.pbxproj`
   - 添加了 `INFOPLIST_KEY_CFBundleURLTypes` 配置

## 常见问题

### Q: URL Scheme 不工作？

A:

1. 确保应用已重新构建并安装
2. 检查系统日志确认 URL 是否被接收
3. 尝试清理 Launch Services 缓存：
   ```bash
   /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user
   ```

### Q: FinderSync Extension 不显示菜单？

A:

1. 确认扩展已在系统设置中启用
2. 重启 Finder：`killall Finder`
3. 检查日志查看扩展是否加载

### Q: 点击菜单无反应？

A:

1. 检查是否选中了至少 2 个文件
2. 查看系统日志确认点击是否被处理
3. 确保主应用已注册 URL Scheme

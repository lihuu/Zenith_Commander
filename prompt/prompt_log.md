# promptxcodebuild -scheme "Zenith Commander" clean build

```markdown
角色：你是 macOS / Swift（App + Finder Sync Extension）工程改造专家

目标：
将 Finder Sync Extension 触发主 App 的机制改造成“requestId + App Group 请求队列”的最佳实践，并且支持两种唤醒方式：

1. URL Scheme（zenith://）
2. 直接定位宿主 .app 并打开（不依赖 scheme，开发调试稳定）

工程前提：

- 工程内已有两个 target：macOS 主 App + Finder Sync Extension（FIFinderSync）
- 当前扩展已能在 Finder 里提供右键菜单项（比如“复制完整路径”）
- 主 App 已配置了 URL Scheme（如 zenith）

要求（必须全部满足）：

1. Extension 发起请求时生成 requestId（UUID 字符串），把请求写入 App Group（UserDefaults 或文件）并只传 requestId 给主 App
2. Extension 唤醒主 App 时，优先“直接定位宿主 App 并打开”，失败则 fallback 到 URL Scheme open
3. 主 App 支持两种入口：
   - URL Scheme 打开（zenith://request?rid=...）
   - Extension 直接打开宿主 App（无 URL 的情况，主 App 启动后从 App Group 读取最近请求）
4. request payload 至少包含：
   - id（requestId）
   - action（如 copyPath / rename / ping）
   - paths（选中项 full path 数组；多选时每项一个字符串）
   - createdAt（ISO8601 string，可选但建议）
5. 所有代码需可编译运行；不要引入第三方依赖；尽量少改动现有结构

实施步骤（按顺序执行）：

A. 统一 App Group（App 与 Extension 都必须配置）

1. 为主 App target 与 Finder Extension target 都启用 App Groups entitlement
2. 使用同一个 group id，例如：group.com.lihuu.top.ZenithCommander
   - 若工程已有 group id，以工程现有为准，但必须两边一致

B. 新增共享请求队列模块（建议放在主 App 的 Shared 目录，并设置 target membership：App + Extension）
创建一个 Swift 文件：Shared/FinderRequest.swift，包含：

1. enum FinderRequestAction: String { case copyPath, rename, ping }
2. struct FinderRequest: Codable { id, action, paths, createdAt }
3. struct FinderRequestStore
   - 常量：suiteName = "group.com.lihuu.top.ZenithCommander"
   - 保存函数：save(\_ request) -> requestId
     - 将 request 编码为 JSON String 存入 UserDefaults(suiteName) 的 key: "finder*request*<id>"
     - 同时更新一个 key: "finder_request_latest" = <id>
   - 读取函数：load(id) -> FinderRequest?
   - 读取最新：loadLatest() -> FinderRequest?
   - 删除函数：delete(id)
   - 注意容错：解码失败返回 nil

C. 修改 Finder Sync Extension：触发请求 + 唤醒主 App（两种方式）
在 FinderSync.swift 中：

1. 右键菜单项保留或改名均可，但点击后不要直接执行业务；而是：
   - 收集 urls：selectedItemURLs() ?? [targetedURL]
   - paths = urls.map { $0.path }
   - 生成 request：action = .copyPath（先用 copyPath 做通路验证）
   - requestId = FinderRequestStore.save(request)
2. 唤醒主 App：
   - 实现 func openContainingApp() -> Bool
     - 从 Bundle.main.bundleURL（.appex）向上寻找宿主 .app：
       - appex bundleURL: .../YourApp.app/Contents/PlugIns/YourExt.appex
       - 向上 3 层到 .../YourApp.app
     - 用 NSWorkspace.shared.openApplication(at: appURL, configuration: .init()) 打开
     - 成功返回 true，否则 false
   - 如果 openContainingApp() 返回 false，则 fallback：
     - NSWorkspace.shared.open(URL(string:"zenith://request?rid=<requestId>")!)
3. 保留日志：NSLog 输出 requestId、paths.count、打开方式（direct/scheme）

D. 修改主 App：处理 requestId（两入口）
根据你工程结构选择合适入口点（SwiftUI App 或 AppKit）：

1. URL Scheme 入口：
   - 若是 SwiftUI App：在顶层使用 .onOpenURL { url in ... }
   - 解析 rid 参数（query item "rid"），读取 FinderRequestStore.load(id)
2. “直接打开宿主 app”入口：
   - App 启动后（例如 .task 或 applicationDidFinishLaunching）调用 FinderRequestStore.loadLatest()
   - 如果 latest request 尚未处理，则处理它
3. 处理逻辑（先做最小可验证闭环）：
   - 若 action == copyPath：
     - 将 paths join("\n") 写入 NSPasteboard.general
   - 处理完后 delete(requestId)（避免重复执行）
4. 为便于验证：在主 App 中打印日志/弹一个轻提示（可选）

E. 验证方式（写进注释或 README）

1. 调试态：Xcode Run 主 App（保持运行）→ 在 Finder 里点右键菜单 → 主 App 应被唤醒并写入剪贴板
2. 若 URL Scheme 未登记（开发态常见），依然要能通过“直接定位宿主 app”方式成功
3. 发布态：将 App 安装到 /Applications 并启用 Finder 扩展 → 两种唤醒均可用

约束：

- 不要把 paths 直接塞到 URL 里；URL 只允许传 rid
- 不要引入 XPC（本次只做 requestId 通路）
- 所有新增文件需设置正确的 target membership（App + Extension 共享模块必须两个 target 都勾选）
- 注意：Extension 和 App 的 CFBundleVersion 必须一致（若不一致，修复为一致）

交付物：

1. Shared/FinderRequest.swift（共享模块）
2. 修改后的 FinderSync.swift（Extension）
3. 修改后的 App 入口文件（能处理 onOpenURL + loadLatest）
4. 若涉及 entitlements/Info.plist 修改，请明确指出改动位置与键值
```

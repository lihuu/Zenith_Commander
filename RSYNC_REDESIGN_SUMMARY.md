# Rsync Sync Sheet 重新设计总结

## 概述

参考 `RsyncFileSync.jsx` 原型设计，完全重新设计了 `RsyncSyncSheetView.swift`，实现了更现代、更直观的同步界面布局。

## 主要改进

### 1. 整体布局优化

- **模态窗口尺寸**: 从 650x550 增加到 **700x600**，提供更舒适的内容展示空间
- **结构分层**: 
  - Header (顶部标题栏 + Profile Badge)
  - Path Visualizer (源路径 ← → 目标路径)
  - Main Content (根据状态动态切换)
  - Footer (上下文相关的操作按钮)

### 2. Header 视图

#### 设计特点
- 左侧：同步图标 + 标题文字
- 右侧：Profile Badge (显示当前配置文件)
- 旋转动画：同步进行时图标自动旋转
- 分隔线：底部使用主题边框色

#### 代码实现
```swift
HStack {
    Image(systemName: "arrow.triangle.2.circlepath")
        .rotationEffect(appState.rsyncUIState.isRunningSync ? .degrees(360) : .degrees(0))
        .animation(...)
    Text("Directory Synchronization (Rsync)")
    
    Spacer()
    
    // Profile Badge
    HStack {
        Text("Profile:") + Text("Mirror Backup").bold()
    }
    .background(Theme.info.opacity(0.2))
}
.background(Theme.backgroundSecondary)
```

### 3. Path Visualizer 路径可视化

#### 设计特点
- **三列布局**: 源路径 + 箭头 + 目标路径
- **大写标签**: "SOURCE (ACTIVE)" / "DESTINATION"
- **等宽字体**: 路径使用 monospaced 字体
- **颜色区分**: 源路径用绿色 (success)，目标路径用蓝色 (info)
- **自动截断**: 路径过长时中间截断显示

#### 代码实现
```swift
HStack(spacing: 16) {
    VStack(alignment: .leading) {
        Text("SOURCE (ACTIVE)")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(Theme.textTertiary)
        Text(localConfig.source.path)
            .foregroundColor(Theme.success)
    }
    
    Image(systemName: "arrow.right")
        .foregroundColor(Theme.textTertiary)
    
    VStack(alignment: .trailing) {
        Text("DESTINATION")
        Text(localConfig.destination.path)
            .foregroundColor(Theme.info)
    }
}
.background(Theme.backgroundTertiary.opacity(0.5))
```

### 4. Configuration View 配置视图

#### 设计特点
- **双列布局**: 左列为模式选择，右列为选项勾选
- **分组标题**: "Mode" 和 "Options" 带下划线分隔
- **单选按钮**: 圆圈图标 + 文字描述
- **复选框**: 使用原生 Toggle + .checkbox 样式
- **命令预览**: 底部显示生成的 rsync 命令
- **语法高亮**: 命令、路径、参数使用不同颜色

#### 代码实现
```swift
HStack(alignment: .top, spacing: 16) {
    // Left Column - Mode
    VStack(alignment: .leading) {
        Text("Mode")
            .overlay(Divider(), alignment: .bottom)
        modeRadioButton(.mirror, "Mirror (Delete extraneous files)")
        modeRadioButton(.update, "Update (Skip newer files)")
        modeRadioButton(.copyAll, "Copy All (Overwrite everything)")
        modeRadioButton(.custom, "Custom")
    }
    
    // Right Column - Options
    VStack(alignment: .leading) {
        Text("Options")
            .overlay(Divider(), alignment: .bottom)
        Toggle("Recursive (-r)", isOn: ...)
        Toggle("Preserve times (-t)", isOn: ...)
        Toggle("Compress (-z)", isOn: ...)
        Toggle("Force Delete (--delete)", isOn: ...)
            .foregroundColor(Theme.error) // 危险操作用红色
    }
}

// Command Preview
VStack {
    Text("# Generated Command Preview:")
        .foregroundColor(Theme.textTertiary)
    HStack {
        Text("rsync").foregroundColor(Theme.warning)
        Text(flags).foregroundColor(Theme.textPrimary)
        Text(source).foregroundColor(Theme.success)
        Text(destination).foregroundColor(Theme.info)
    }
}
.background(Theme.backgroundTertiary.opacity(0.8))
.cornerRadius(6)
```

### 5. Preview View 预览视图

#### 设计特点
- **统计卡片**: 4 个横向排列的状态卡 (ADD/UPDATE/DELETE/SKIP)
- **大数字显示**: 使用 size 20、bold、rounded 字体
- **表格布局**: 文件列表使用三列表格 (Change | File Path | Size)
- **徽章样式**: 变更类型使用彩色徽章显示
- **斑马纹**: 偶数行显示浅灰色背景
- **限制显示**: 最多显示前 20 条记录

#### 代码实现
```swift
// Stat Badges
HStack(spacing: 12) {
    statBadge("ADD", count, Theme.success)
    statBadge("UPDATE", count, Theme.info)
    statBadge("DELETE", count, Theme.error)
    statBadge("SKIP", count, Theme.warning)
}

func statBadge(_ label: String, _ count: Int, _ color: Color) -> some View {
    VStack {
        Text("\(count)")
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundColor(color)
        Text(label)
            .foregroundColor(Theme.textSecondary)
    }
    .background(color.opacity(0.08))
    .cornerRadius(6)
    .overlay(RoundedRectangle(cornerRadius: 6).stroke(color.opacity(0.2)))
}

// File List Table
VStack {
    // Header
    HStack {
        Text("Change").frame(width: 80)
        Text("File Path").frame(maxWidth: .infinity)
        Text("Size").frame(width: 80)
    }
    .background(Theme.backgroundTertiary.opacity(0.3))
    
    // Rows
    ForEach(items.prefix(20)) { item in
        HStack {
            Text(changeType)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .background(changeColor)
            Text(item.path)
            Text(item.size)
        }
        .background(index % 2 == 0 ? .clear : Theme.backgroundTertiary.opacity(0.1))
    }
}
```

### 6. Progress View 进度视图

#### 设计特点
- **居中布局**: 所有内容垂直居中显示
- **加载动画**: 使用原生 ProgressView + 1.5x 缩放
- **进度条**: 自定义绘制带百分比的进度条
- **固定宽度**: 进度信息区域固定 300px 宽度
- **状态文本**: 显示当前操作描述

#### 代码实现
```swift
VStack(spacing: 0) {
    Spacer()
    
    VStack(spacing: 16) {
        ProgressView()
            .scaleEffect(1.5)
            .tint(Theme.accent)
        
        Text("Synchronizing files...")
            .foregroundColor(Theme.textPrimary)
        
        VStack(spacing: 8) {
            HStack {
                Text("Progress")
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text(String(format: "%.0f%%", percentage))
                    .foregroundColor(Theme.accent)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.backgroundTertiary)
                        .frame(height: 8)
                    Rectangle()
                        .fill(Theme.accent)
                        .frame(width: geometry.size.width * progress, height: 8)
                }
                .cornerRadius(4)
            }
            .frame(height: 8)
        }
        .frame(width: 300)
    }
    
    Spacer()
}
```

### 7. Result View 结果视图

#### 设计特点
- **居中布局**: 所有内容垂直居中
- **大图标**: 48pt 的成功/失败图标
- **状态文字**: 18pt 半粗体标题
- **统计摘要**: 显示传输文件数量
- **错误列表**: 失败时显示最多 3 条错误信息
- **卡片样式**: 错误信息使用半透明背景卡片

#### 代码实现
```swift
VStack(spacing: 0) {
    Spacer()
    
    VStack(spacing: 20) {
        Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.system(size: 48))
            .foregroundColor(success ? Theme.success : Theme.error)
        
        Text(success ? "Synchronization Complete" : "Synchronization Failed")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(Theme.textPrimary)
        
        if success {
            Text("\(count) files transferred")
                .foregroundColor(Theme.textSecondary)
        }
        
        if !errors.isEmpty {
            VStack(alignment: .leading) {
                ForEach(errors.prefix(3)) { error in
                    Text(error)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.error)
                }
            }
            .padding(12)
            .background(Theme.error.opacity(0.1))
            .cornerRadius(6)
        }
    }
    
    Spacer()
}
```

### 8. Footer View 底部按钮

#### 设计特点
- **上下文相关**: 根据当前状态显示不同按钮组合
- **状态信息**: 左侧显示检测到的变更数量
- **按钮样式**: 
  - Cancel/Close: 灰色背景
  - Back: 灰色背景
  - Dry Run: 灰边框 + 透明背景 + 眼睛图标
  - Start Sync: 蓝色背景 (主要强调色)
  - Confirm & Sync: 绿色背景 (成功色)
- **图标**: 所有主要操作按钮都带有图标

#### 代码实现
```swift
HStack {
    // Left Info
    if let previewResult = appState.rsyncUIState.previewResult {
        Text("\(count) changes detected")
            .font(.system(size: 11))
            .foregroundColor(Theme.textSecondary)
    }
    
    Spacer()
    
    HStack(spacing: 12) {
        // Cancel/Close
        Button(syncResult != nil ? "Close" : "Cancel") {
            appState.dismissRsyncSheet()
        }
        .background(Theme.backgroundTertiary)
        
        // Back (Preview only)
        if previewResult != nil && syncResult == nil {
            Button("Back") {
                appState.rsyncUIState.previewResult = nil
            }
            .background(Theme.backgroundTertiary)
        }
        
        // Primary Actions
        if syncResult == nil {
            if previewResult != nil {
                // Confirm & Sync
                Button(action: { await appState.runSync() }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Confirm & Sync")
                    }
                    .foregroundColor(.white)
                }
                .background(Theme.success)
            } else if !isRunningSync {
                // Dry Run
                Button(action: { await appState.runPreview() }) {
                    HStack {
                        Image(systemName: "eye.fill")
                        Text("Dry Run")
                    }
                    .foregroundColor(.white)
                }
                .background(Theme.backgroundTertiary.opacity(0.8))
                .overlay(RoundedRectangle().stroke(Theme.border))
                
                // Start Sync
                Button(action: { await appState.runSync() }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Sync")
                    }
                    .foregroundColor(.white)
                }
                .background(Theme.accent)
            }
        }
    }
}
.background(Theme.backgroundSecondary)
```

## 主题适配 (亮色/暗色)

### 所有颜色使用 Theme.* 常量

| 元素 | 深色主题 | 浅色主题 |
|------|---------|---------|
| **背景** | | |
| background | #1e1e1e | #ffffff |
| backgroundSecondary | #252526 | #f5f5f5 |
| backgroundTertiary | #2d2d2d | #eeeeee |
| **文本** | | |
| textPrimary | #e0e0e0 | #212121 |
| textSecondary | #a0a0a0 | #616161 |
| textTertiary | #6e6e6e | #9e9e9e |
| **强调** | | |
| accent | #4fc3f7 (亮蓝) | #1976d2 (深蓝) |
| success | #4caf50 (绿) | #2e7d32 (深绿) |
| error | #f44336 (红) | #c62828 (深红) |
| info | #2196f3 (蓝) | #1565c0 (深蓝) |
| warning | #ff9800 (橙) | #f57c00 (深橙) |
| **边框** | | |
| border | #1e1e1e | #e0e0e0 |
| borderSubtle | #404040 | #d0d0d0 |

### 动态主题响应

所有颜色通过 `ThemeManager.shared` 动态获取，切换主题时无需重启应用即可生效。

```swift
@ObservedObject private var themeManager = ThemeManager.shared

// 颜色会自动响应主题变化
.foregroundColor(Theme.textPrimary)
.background(Theme.backgroundSecondary)
```

## 与 JSX 原型对比

| 特性 | JSX 原型 | Swift 实现 | 状态 |
|-----|---------|-----------|------|
| Header + Profile Badge | ✓ | ✓ | ✅ 完成 |
| Path Visualizer | ✓ | ✓ | ✅ 完成 |
| Two-column Config Layout | ✓ | ✓ | ✅ 完成 |
| Mode Radio Buttons | ✓ | ✓ | ✅ 完成 |
| Options Checkboxes | ✓ | ✓ | ✅ 完成 |
| Command Preview | ✓ | ✓ | ✅ 完成 |
| Stat Badges | ✓ | ✓ | ✅ 完成 |
| File List Table | ✓ | ✓ | ✅ 完成 |
| Change Type Badges | ✓ | ✓ | ✅ 完成 |
| Progress Bar | ✓ | ✓ | ✅ 完成 |
| Result Icon | ✓ | ✓ | ✅ 完成 |
| Contextual Footer Buttons | ✓ | ✓ | ✅ 完成 |
| Animated Sync Icon | ✓ | ✓ | ✅ 完成 |
| Light/Dark Theme | ✓ | ✓ | ✅ 完成 |

## 文件变更

### 修改文件
- `Zenith Commander/Views/RsyncSyncSheetView.swift` (完全重写, ~600 行)

### 新增功能
- Header 带 Profile Badge
- Path Visualizer 路径可视化
- 双列配置布局
- 统计卡片式预览
- 表格式文件列表
- 居中式进度和结果显示
- 上下文相关的底部按钮
- 完整的亮色主题适配

## 构建和测试

```bash
# 清理构建
xcodebuild clean -scheme "Zenith Commander"

# 编译项目
xcodebuild -scheme "Zenith Commander" build

# 运行测试
xcodebuild test -scheme "Zenith Commander" -destination 'platform=macOS'
```

### 验证项

- [x] 编译成功无错误
- [x] 所有 UI 元素正确显示
- [x] 亮色主题颜色正确
- [x] 暗色主题颜色正确
- [x] 主题切换实时生效
- [x] 动画效果流畅
- [x] 按钮交互正常
- [x] 状态切换逻辑正确
- [x] 响应式布局适配

## 用户体验提升

### Before (旧版)
- 单列布局，内容拥挤
- 路径显示不直观
- 预览结果列表式展示
- 进度条较小不明显
- 按钮样式单调
- 缺少视觉层次

### After (新版)
- 双列布局，内容清晰
- 路径可视化，一目了然
- 统计卡片 + 表格展示
- 大进度条 + 百分比
- 彩色按钮 + 图标
- 视觉层次分明

## 技术细节

### SwiftUI 特性使用
- `@ObservedObject` 监听主题变化
- `@EnvironmentObject` 共享应用状态
- `@State` 管理本地配置
- `GeometryReader` 自定义进度条
- `ViewBuilder` 条件渲染
- `ForEach` 列表渲染
- `.animation()` 旋转动画

### 性能优化
- 列表限制显示 20 条记录
- 路径文本自动截断
- 懒加载 ScrollView
- 条件渲染减少内存占用

## 总结

此次重新设计完全基于 JSX 原型的视觉风格和交互逻辑，将 React 组件的设计理念成功转换为 SwiftUI 实现。所有颜色、间距、布局、动画都严格按照原型进行适配，同时确保了在 macOS 平台上的原生体验和完整的亮色/暗色主题支持。

**用户可以立即体验到更现代、更直观、更美观的 Rsync 同步界面！** 🎉

# Project Agent Instructions

## 1. Project Overview

**Zenith Commander** is a native macOS dual‑pane file manager designed for developers and keyboard‑driven workflows.  
It combines the efficiency of Total Commander with the modal interaction philosophy of Vim.

- Platform: macOS 14.0+ (Sonoma)
- Language: Swift 6.0
- UI Frameworks: SwiftUI (primary), AppKit (window management)
- License: MIT

The AI assistant must follow all rules in this document when modifying the codebase.

---

## 2. Tech Stack

- Swift 6.0
- SwiftUI
- AppKit
- Xcode 15+
- Embedded SFTP framework: `mft` (libssh + OpenSSL) — git submodule at `./mft`; clone with `git submodule update --init --recursive`
- Shell: zsh/bash for scripts
- Grep: using rg instead of grep for searching codebase

---

## 3. Environment Setup

Open the project:

```bash
open "Zenith Commander.xcodeproj"
```

Clone submodules (required for build — provides `mft` SFTP framework):

```bash
git submodule update --init --recursive
```

Build & Run (CLI):

```bash
xcodebuild -scheme "Zenith Commander" build
```

---

## 4. Common Commands

Run tests:

```bash
xcodebuild test -scheme "Zenith Commander" -destination 'platform=macOS'
```

Create DMG:

```bash
./build-dmg.sh
```

---

## 5. Project Structure

```txt
Zenith Commander/
├── Models/              # 数据模型 (MVVM)
│   ├── Actions/             # AppAction — dispatched through AppReducer
│   ├── Configuration/       # Keymaps and static config
│   ├── Entities/            # AppMode, AppSettings, BookmarkItem, Connection, DriveInfo, FileItem, SortOption
│   └── State/               # AppState + AppReducer + AppState+*.swift extensions (Command/Filter/GitHistory/InlineEditing/Modes/Pane), PaneState, TabState
├── Plugins/            # Loadable feature plugins (each has Capabilities/Models/Services/Views)
│   ├── Core/                # PluginContext, PluginManager, PluginTypes, UIHost + Capabilities
│   ├── AI/                  # AI tools plugin (terminal integration, context menu)
│   ├── Fzf/                 # Fzf fuzzy finder plugin
│   ├── Git/                 # Git 功能插件
│   └── Rsync/               # Rsync 同步插件
├── Services/           # 业务逻辑层 (no UI here)
│   ├── CommandParser.swift / CommandExecutionService.swift
│   ├── DirectoryMonitor.swift
│   ├── FileSystemService.swift / GitHistoryService.swift
│   ├── Logger.swift
│   ├── Endpoint/           # 远程/本地端点抽象: EndpointRegistry, FileEndpoint, LocalEndpoint, SFTPEndpoint (imports mft), TransferService, GenericTransferPipeline, TransferFastPath, FileOps, FileEntry, PathRef
│   └── Managers/           # BookmarkManager, ConnectionManager, SettingsManager
├── Localization/       # LocalizationManager.swift (see §7 — single source of localized strings)
├── Shared/             # 跨层共享代码
├── Theme/              # Theme.swift / ThemeManager.swift
└── Views/              # UI-only, declarative
    ├── MainView / PaneView / SettingsView / ConnectionManagerView
    └── Components/     # AsyncIconView, BatchRenameView, BookmarkBarView, BreadcrumbView, DriveSelectorView, FileGridItemView, FileRowView, HelpView, ModalView, PermissionRequestView, ResizableBottomPanel, SortHeaderView, StatusBarView, TabBarView, ToastView, WindowDragHandle
```

Note: `AppState` is the global source of truth and is mutated **only** via `AppAction` dispatched through `AppReducer` (`Models/State/AppReducer.swift`). Logic is split into themed `AppState+*.swift` extensions — add new behavior to the matching extension rather than the base file.

You must NOT move files across layers without explicit instruction.

---

## 6. Architecture & Design Rules

- The app strictly follows **MVVM**.
- `AppState` is the **single global source of truth**; state mutations flow through `AppAction` → `AppReducer` (in `Models/State/`).
- Business logic must live in `Services/`, NOT in `Views`.
- Views must remain UI‑only and declarative.
- Modal interaction is driven by a **state machine** (`Normal`, `Visual`, `Command`, `Filter`, `Drives`, etc.) in `Models/State/AppState+Modes.swift`.
- Plugins communicate with the host only via `Plugins/Core` (`PluginContext`, `PluginTypes`, `UIHost`, declared `Capabilities`). Do not reach into `AppState`/`Services` directly from a plugin.
- **单一运行时源原则**：跨视图共享的运行时状态（如 `ThemeManager.shared.mode`）只能有一个源。Settings 视图必须 `@Binding`/`@ObservedObject` 到该源，**不得**在 `SettingsManager.settings` 里维护平行副本。Settings 与快捷键都只写该源；启动期用一次性迁移把老持久化（settings.json）灌入该源即可。这避免了「快捷键改了状态、Settings 选中态不跟随」的整类 bug。
- **主题-原生控件对齐原则（critical）**：SwiftUI 原生控件（`TextField`、`TextEditor`、`Form`、`Picker`、`Toggle`、`List` 等带系统背景/边框的控件）的颜色取自 SwiftUI 环境的 `colorScheme`，**不会**自动跟随 `ThemeManager.current`。当 `ThemeManager.mode` 与 macOS 系统外观不一致时（例如 ThemeManager=Dark、系统=Light），自定义背景走 DarkTheme、原生控件仍走系统 Light → 视觉撕裂。**根治约束**：必须在根视图（`ContentView`）通过 `.preferredColorScheme(themeManager.preferredColorScheme)` 一次性把 SwiftUI 环境的 `colorScheme` 对齐到 `ThemeManager.mode`（`auto` 模式传 `nil` 跟随系统）；`ThemeManager` 必须暴露 `preferredColorScheme: ColorScheme?` 派生属性。**禁止**在含原生控件的子视图里逐个 hack 颜色（例如给每个 `TextField` 单独设背景）来「修」这类不一致——那只会增殖平行源、绕过单一运行时源原则。新增任何使用原生控件的视图（含插件视图）都依赖这一根级对齐，无需也不能在视图内部重复处理。
- **已知隔离妥协（插件层）**：当前插件 `Capabilities/` 中的 settings provider 与命令/菜单 provider 直接读取宿主 `SettingsManager.shared.settings.<x>`（如 `GitSettingsProvider`/`RsyncSettingsProvider`/`FzfSettingsProvider`/`AISettingsProvider`/`AICommandProvider`/`AIService.terminalProvider`），`GitUIContribution` 直接通过 `@EnvironmentObject` 读取 `AppState` 的 git 历史字段。这是**插件隔离层的临时缺口**，不是「单一运行时源」违规——它们读的是同一个源、不会产生用户可见的漂移 bug。在引入第三方插件或把插件拆成独立 package 前，**不强制改造**；届时应在 `Plugins/Core` 补一个 settings/state 访问 capability（如 `SettingsAccess`/`PluginStateHost`）来根治。新增插件时优先走 `PluginContext`/`Capabilities`，避免再增加对 `SettingsManager`/`AppState` 的直接依赖。
- **已知 reducer-绕过妥协（View 层直写 state）**：`Views/`（主要是 `PaneView.swift`、`MainView.swift`）中有约 30+ 处直接写入 `AppState`/`PaneState`/`TabState` 的 `@Published` 字段，绕过 `AppAction` → `AppReducer`。这与「单一运行时源」是**不同物种**：这里只有一个源（pane state 本身）、SwiftUI `@Published` 观察正确，**不会产生用户可见的不一致**。原因是 `AppReducer` 当初被设计成「键盘/命令输入派发器」，不是数据传输层——目录加载、`pane.gitInfo`、`sortOption`、`viewMode`、`gridColumnCount`、`editingFileName` 逐字内容等都没有对应 `AppAction`，View 调用 `FileSystemService` 后直接把结果写回 pane state。已修复的子集：(1) `MainView.swift`/`UIHost.swift` 中关闭 sheet 时冗余/绕过 `exitMode()` 的直接写入；(2) reducer 版 `leaveDirectory()` 补齐 `sortOption = .default`，与 `PaneView.leaveDirectory()`（权限恢复专用路径）行为对齐。**剩余的 View 直写（目录加载回调、`gitInfo`、`sortOption`/`viewMode`/`gridColumnCount` 绑定、`editingFileName` 逐字输入）属已知妥协，不强制改造**——要把 reducer 升级为数据总线需新增一整套 `setDirectoryContents`/`navigate(path:)`/`setGitInfo`/`setSortOption`/`setViewMode`/`setGridColumnCount` action 并重写 `DirectoryMonitor` 回调与 `PaneView` 加载/导航方法，属中规模重构，收益是架构纯净度而非修 bug。在出现真实「不一致/卡死」故障或大规模重构窗口前保持现状。

You must NOT introduce new architectural patterns without confirmation.

---

## 7. Localization Rules (Critical)

- You must NOT use `NSLocalizedString`.
- You must always:
  - Add keys to `LocalizedStringKey` enum
  - Add translations to `LocalizedStrings`
- Access localization only via:
  - `LocalizationManager.shared.localized(.key)`
  - or `L(.key)`

Violating this rule is considered a critical error.

---

## 8. Code Style Rules

- You must use Swift concurrency (`async/await`) where applicable.
- You must avoid legacy completion‑handler APIs unless required by system frameworks.
- You must NOT introduce force‑unwraps (`!`) unless explicitly justified.
- Public types and methods must include documentation comments.
- View layout logic must not exceed reasonable complexity in a single file.

---

## 9. Testing Rules

- Tests live in `Zenith CommanderTests/` (unit) and `Zenith CommanderUITests/` (UI), registered in `Zenith Commander.xctestplan`.
- Existing unit coverage: `AppStateDispatchTests`, `BookmarkManagerTests`, `CommandExecutionServiceTests`, `CommandParserTests`, `DragDropTests`, `FileSystemServiceTests`, `GitHistoryServiceTests`, `GitHistoryTests`, `LocalFileSystemProviderTests`, `LocalizationTests`, `PaneViewTests`, `RsyncServiceTests`, `SortOptionTests`, `SymlinkNavigationTests`, plus `Zenith CommanderTests/Plugins/` for plugin behavior.
- All changes to `Services/` or `AppState+*.swift` reducers must include updated tests where applicable.
- You must NOT modify production code without updating corresponding tests.
- Tests must be deterministic and not depend on network availability unless explicitly required (SFTP/transfer tests should stub the `Endpoint` layer).

---

## 10. Git & Change Management Rules

- You should commit local changes before modifying code.
- You must keep changes minimal and scoped.
- You must NOT refactor unrelated code.
- Commit messages must be descriptive and scoped.
- You must NOT delete files unless explicitly instructed.

---

## 11. Performance & Safety Rules

- You must NOT block the main thread with file I/O or network operations.
- Heavy file operations must be performed asynchronously.
- You must NOT introduce memory‑retention cycles in ViewModels or Services.

---

## 12. What You Must NEVER Do

- Never delete localization keys.
- Never hard‑code user‑visible strings.
- Never introduce mock data into production paths.
- Never silently change application behavior without clear documentation in code comments.

## 13. SOP Rules

You must also follow all relevant rules from ./AI-SOP.md and .github/copilot-instructions.md.

---

## 14. Test Execution Delegation

- After production code or test modifications, build and relevant tests must be executed before reporting completion.
- During feature development, do not run the full test suite by default.
- Run only the tests directly related to the modified code or the affected feature area, such as:
  - the changed service/model/view tests
  - the plugin tests for the modified plugin
  - targeted UI tests for the changed user flow
  - a focused regression test for the bug or behavior being changed
- Run the full test suite only when explicitly requested, before release/merge, or when the change is broad enough that targeted tests cannot provide useful coverage.
- Prefer running verification in a sub agent instead of the main agent when the environment supports sub agents.
- The test sub agent should use a lightweight model by default: `gpt-5.4-mini`.
- The test sub agent must only report concise verification results:
  - command executed
  - pass/fail status
  - failing test names and key error lines when failures exist
  - no implementation suggestions unless explicitly requested
- The main agent remains responsible for interpreting failures, deciding next steps, and summarizing user-facing status.

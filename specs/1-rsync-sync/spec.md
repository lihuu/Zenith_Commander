# Rsync-based Sync for Dual-Pane

## Background

- Zenith Commander is a dual-pane macOS file manager optimized for developer workflows and keyboard-first interactions.

- Users frequently need to synchronize content between two directories shown in left/right panes (e.g., backing up, mirroring, staging deployments).

- A native, simple, safe sync capability with preview reduces mistakes and speeds up repetitive tasks.

## User Stories

- As a user, I can configure a sync between the left and right panes so that one acts as source and the other as destination.

- As a user, I can run a dry-run preview to see which files would be copied, updated, or deleted before executing.

- As a user, I can choose whether to delete extra files in the destination that are not present in the source.

- As a user, I can preserve file attributes (timestamps, permissions) during sync.

- As a user, I can specify simple exclude patterns to skip certain files or folders.

- As a user, I can only start a sync when both panes point to valid directories (not archives or remote-only without support).

- As a user, I can review a preview list and confirm before running the actual sync.
  - Completion summary with totals and any errors.

## Scope

- In-scope:

  - Sync operations between left/right pane directories when both are valid local or mounted directories supported by the app.
  - Dry-run preview, delete-extra toggle, preserve-attributes toggle, exclude patterns text field.
  - Configuration sheet to select source/destination (Left → Right or Right → Left) and options.
  - Preview screen summarizing planned changes with counts and categorized lists (copy, update, delete, skipped).
  - Execution flow with progress, completion summary, and error handling.

- Out-of-scope:
  - Network discovery, remote authentication UX beyond existing capabilities.
  - Complex include/exclude rule editors (only simple glob-like patterns list).
  - Scheduling, background daemon, or multi-target sync.
  - List: items grouped by action; each entry shows relative path and action.

## UX

- Entry: A command (menu item and shortcut) opens a configuration sheet when in NORMAL mode.
- 右键菜单：
  - 在文件上右键菜单中添加一个“Rsync Sync...”的选项，点击之后弹出同步配置窗口，文件为源目录，另一个 panne 为目标目录
  - 在目录上面右键菜单中添加一个“Rsync Sync...”的选项，点击之后弹出同步配置窗口，目录为源目录，另一个 panne 为目标目录
- 快捷键(shift+s): 弹窗显示，左边 pane 为源目录，右边为目标目录，中间有箭头可以切换方向

- Configuration Sheet:

  - Source/Destination selector: Left → Right or Right → Left.
  - Options: Dry-run (default on for first-time), Delete extras (off by default), Preserve attributes (on by default), Exclude patterns (comma-separated).
  - Validation: Both panes must be directories; show inline error and disable Continue if invalid.
  - Actions: Continue to Preview, Cancel.
  - 同步参数选择：
    - 左边是模式名称（说明），右边是模式对应的参数选择例如：Recursive（-r），即前面是名字，后面是参数
    - 提供四种模式：
      - Update (Skip newer files)默认模式：右边自动勾选对应的参数
      - Mirror (Delete extras)：右边自动勾选对应的参数
      - Copy ALl（Overwrite existing）：右边自动勾选对应的参数
      - Custom：用户自定义参数输入框：用户可以自己勾选参数
  - rsync 命令预览：
    - 底下展示完整的 rsync 参数预览，用户可以看到最终执行的命令是什么样子的

- Preview View:

  - Summary: counts of planned changes with counts and categorized lists (copy, update, delete, skipped).
  - List: items grouped by action; each entry shows relative path and action.
  - Actions: Back to Configuration, Run Sync, Cancel.

- Run State:
  - Progress indicator with current operation, total completed/remaining.
  - Completion summary with totals and any errors.
- Prototype
  - A simple prototype is available at: prototype/protype-website/src/RsyncFileSync.jsx

## Non-functional Requirements

- Follow MVVM: logic in `Services/`, UI in `Views/`, sync state in `AppState`.
- Do not block main thread; perform preview and execution asynchronously.
- Respect localization rules: no hard-coded user-visible strings; use existing localization system.
- Provide deterministic tests for Services behavior; avoid flakiness.
- Error messages must be user-friendly and actionable.
- All operations execute without freezing the UI; progress updates are visible.

## Acceptance Criteria

- Users can open the sync configuration sheet from the app and see options.
- Continue is disabled unless both panes point to valid directories.
- Dry-run preview shows accurate categorized results for copy/update/delete/skipped with counts.
- When Delete extras is enabled, preview includes deletions present only in destination.
- Preserve attributes option is reflected in execution (attributes preserved).
- Exclude patterns prevent matching files from appearing in preview and execution.
- Running the sync performs actions consistent with preview; final summary matches expected results.
- All operations execute without freezing the UI; progress updates are visible.
- Implementation places business logic in Services, state in AppState, and UI in Views, following MVVM.

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

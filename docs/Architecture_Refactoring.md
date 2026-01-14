# Zenith Commander Architecture & Refactoring Guide

## 1. Current Architecture Analysis

The project follows an MVVM pattern with a Redux-like state management approach. However, as the application has grown, several architectural issues have emerged, primarily centered around `AppState`.

### Key Issues

- **AppState as a "God Object"**: `AppState.swift` has become bloated, containing over 30 `@Published` properties and mixing state with business logic.
- **Business Logic Leakage**: File operations, command execution, and clipboard management logic are implemented directly in `AppState` extensions instead of being delegated to dedicated services.
- **Mixed Responsibilities in Models**: The `Models/` directory currently contains a mix of:
  - **State**: `AppState`, `PaneState`
  - **Entities**: `FileItem`, `BookmarkItem`
  - **Logic**: `BookmarkManager`, `SettingsManager` (should be Services)
  - **Configuration**: `AppMode+Keymaps`

## 2. Refactoring Goals

The primary goal is to enforce a strict separation of concerns, ensuring that **Models hold data**, **Services perform logic**, and **State holds the current truth**.

### Target Directory Structure

```text
Zenith Commander/
├── Models/
│   ├── State/                  # Pure State Objects (ObservableObjects)
│   │   ├── AppState.swift      # Global state properties only
│   │   ├── PaneState.swift
│   │   └── TabState.swift
│   ├── Entities/               # Pure Data Structures (Structs/Enums)
│   │   ├── AppMode.swift
│   │   ├── FileItem.swift
│   │   ├── BookmarkItem.swift
│   │   ├── AppSettings.swift
│   │   └── ...
│   ├── Actions/                # Action Definitions
│   │   └── AppAction.swift
│   └── Configuration/          # Static Configuration
│       └── Keymaps.swift
│
├── Services/                   # Business Logic Layer
│   ├── Command/                # Command Processing
│   │   ├── CommandExecutor.swift
│   │   └── CommandParser.swift
│   ├── FileSystem/             # File Operations
│   │   ├── FileSystemService.swift
│   │   └── BatchRenameService.swift
│   ├── Managers/               # State Managers / Singletons
│   │   ├── BookmarkManager.swift
│   │   └── SettingsManager.swift
│   └── Git/
│       └── GitService.swift
```

## 3. Refactoring Constraints & Best Practices

### A. Strict Separation of Concerns

1.  **AppState is for State Only**: `AppState` should only store data. It should **not** contain methods that perform file I/O, network requests, or complex data processing.
2.  **Logic in Services**: Any operation that "does something" (renaming files, copying data, parsing commands) must exist in a `Service` or `Manager` class.
3.  **Managers are Services**: Classes like `BookmarkManager` and `SettingsManager` are functionally services and should reside in the `Services/` directory.

### B. Dependency Injection & Testing

1.  **Inject Services**: `AppState` should depend on protocols (e.g., `FileSysteming`) rather than concrete implementations where possible, to facilitate testing.
2.  **Test Logic in Isolation**: By moving logic to Services, we can write unit tests for `BatchRenameService` or `CommandParser` without needing to instantiate the entire `AppState`.

### C. Concurrency (Swift 6)

1.  **MainActor Usage**: UI-related state (`AppState`, `PaneState`) must be isolated to the `@MainActor`.
2.  **Service Isolation**: Services should ideally be actor-isolated or strictly `Sendable` to prevent data races.
3.  **Non-Blocking**: Long-running operations (file copies, git fetch) must run off the main thread and update state asynchronously.

## 4. Implementation Plan

### Phase 1: Entity & Manager Split (Completed)

- Split `Bookmark.swift` -> `Entities/BookmarkItem.swift` & `Services/Managers/BookmarkManager.swift`.
- Split `Settings.swift` -> `Entities/AppSettings.swift` & `Services/Managers/SettingsManager.swift`.
- Moved Keymaps to `Models/Configuration/Keymaps.swift`.

### Phase 2: Service Extraction (Next Steps)

- **Batch Rename**: Extract logic from `AppState` to `Services/BatchRenameService.swift`.
- **Clipboard**: Extract copy/cut/paste logic to `Services/ClipboardService.swift`.
- **Command Execution**: Move `AppState+Command` logic to `Services/Command/CommandExecutionService.swift`.

### Phase 3: State Decomposition

- Group related `@Published` properties in `AppState` into nested structs (e.g., `struct BatchRenameState`, `struct GitState`).

## 5. Development Guidelines

- **Don't Break the Build**: Ensure all references are updated after moving files.
- **Update Xcode Project**: Manually remove old file references and add new ones in Xcode after filesystem changes.
- **Run Tests**: Verify changes using `xcodebuild test -scheme "Zenith Commander"`.

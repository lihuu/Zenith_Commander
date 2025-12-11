# Project Agent Instructions

## 1. Project Overview

**Zenith Commander** is a native macOS dual‑pane file manager designed for developers and keyboard‑driven workflows.  
It combines the efficiency of Total Commander with the modal interaction philosophy of Vim.

- Platform: macOS 14.0+ (Sonoma)
- Language: Swift 5.9+
- UI Frameworks: SwiftUI (primary), AppKit (window management)
- License: MIT

The AI assistant must follow all rules in this document when modifying the codebase.

---

## 2. Tech Stack

- Swift 5.9+
- SwiftUI
- AppKit
- Xcode 15+
- Embedded SFTP framework: `mft` (libssh + OpenSSL)
- Shell: zsh/bash for scripts
- Grep: using rg instead of grep for searching codebase

---

## 3. Environment Setup

Open the project:

```bash
open "Zenith Commander.xcodeproj"
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
.
├── Zenith Commander/
│   ├── Zenith_CommanderApp.swift   # App Entry Point
│   ├── Localization/               # Custom localization system
│   ├── Models/                     # Data models (AppState, FileItem, etc.)
│   ├── Services/                   # Business logic (FS, Git, Commands)
│   ├── Theme/                      # Theme definitions
│   └── Views/                      # SwiftUI Views
├── mft/                            # Embedded SFTP framework
├── build-dmg.sh                    # Distribution script
├── Zenith Commander.xcodeproj
└── README.md
```

You must NOT move files across layers without explicit instruction.

---

## 6. Architecture & Design Rules

- The app strictly follows **MVVM**.
- `AppState` is the **single global source of truth**.
- Business logic must live in `Services/`, NOT in `Views`.
- Views must remain UI‑only and declarative.
- Modal interaction is driven by a **state machine** (`Normal`, `Visual`, `Command`, `Filter`, `Drives`, etc.).

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

- All changes to `Services/` must include updated tests where applicable.
- You must NOT modify production code without updating corresponding tests.
- Tests must be deterministic and not depend on network availability unless explicitly required.

---

## 10. Git & Change Management Rules

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

You must also follow all relevant rules from AI-SOP.md and .github/copilot-instructions.md.

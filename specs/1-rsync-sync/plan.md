# Rsync Sync Implementation Plan

## Overview

- Introduce an rsync-based synchronization feature between the left/right panes.

- Follow MVVM: business logic in `Services`, state in `AppState`, UI in `Views`.

- Provide configuration sheet, preview (dry-run), and execution flow with progress and summary.

## Components

- RsyncService (`Services/RsyncService.swift`)

  - Responsibility: Build and execute rsync preview and run operations safely via async subprocess.
  - APIs:
    - `preview(config: RsyncSyncConfig) async throws -> RsyncPreviewResult`
    - `run(config: RsyncSyncConfig, progress: AsyncStream<RsyncProgress>) async throws -> RsyncRunResult`
    - Internal helpers: `buildCommand(config:)`, `parseDryRunOutput(_:)`, `validatePaths(_:)`
  - Notes:
    - Use `/usr/bin/rsync` with flags derived from config.
    - Dry-run uses `-n` and `--itemize-changes` to parse planned actions.
    - Excludes via multiple `--exclude` entries.
    - Preserve attributes via `-a` and/or specific flags (timestamps/permissions).
    - Delete extras via `--delete` when mirror mode enabled.
    - Execute using `Process` + `Pipe` asynchronously to avoid blocking main thread.
    - Return structured preview/run results and errors.

- RsyncSyncConfig (`Models/RsyncSyncConfig.swift`)

  - Responsibility: Encapsulate rsync configuration and validation.
  - Fields:
    - `source: URL`
    - `destination: URL`
    - `mode: RsyncMode` (update, mirror, copyAll, custom)
    - `dryRun: Bool`
    - `preserveAttributes: Bool`
    - `deleteExtras: Bool`
    - `excludePatterns: [String]`
    - `customFlags: [String]` (for custom mode only)
  - Methods:
    - `isValid() -> Bool` (both URLs are directories)
    - `effectiveFlags() -> [String]` (derive rsync flags from fields)

- AppState extension (`Models/AppState+Rsync.swift`)

  - Responsibility: Hold UI state and orchestrate the rsync flow.
  - Add state struct `RsyncUIState`:
    - `isSheetPresented: Bool`
    - `config: RsyncSyncConfig`
    - `preview: RsyncPreviewResult?`
    - `runProgress: [RsyncProgress]`
    - `runResult: RsyncRunResult?`
    - `errorMessage: String?`
    - `isBusy: Bool` (performing preview/run)
  - Methods:
    - `presentRsyncSheet(sourceIsLeft: Bool)` sets default `config` (left→right or right→left) and presents sheet.
    - `updateConfig(_:)` merges user edits.
    - `runPreview()` calls `RsyncService.preview` and stores result or error.
    - `executeSync()` streams progress from `RsyncService.run` and captures final result.
    - `dismissRsyncSheet()` resets state.

- SwiftUI views

  - `RsyncSyncSheetView` (`Views/RsyncSyncSheetView.swift`)
    - Responsibility: Configuration sheet and preview UI.
    - Sections:
      - Configuration: source/destination selector (Left→Right / Right→Left), mode selector, toggles (dry-run, delete extras, preserve attributes), exclude patterns entry, custom flags when applicable.
      - Command preview: built command string (read-only) for transparency.
      - Validation: inline errors and disabled Continue if invalid.
      - Actions: Continue to Preview (runs `runPreview()`), Cancel.
    - Preview state:
      - Summary counts (copy/update/delete/skipped).
      - Grouped lists per action (virtual list for performance).
      - Actions: Back (return to configuration), Run Sync (calls `executeSync()`), Cancel.
      - Progress view: shows live updates during execution and final summary.
    - Bindings:
      - Binds into `AppState.rsyncUIState` with two-way updates via `updateConfig`.
    - Localization:
      - All user-visible strings via `LocalizationManager` and key enums.

- Command integration
  - Extend `CommandParser` to add `:rsync` command.
    - Usage: `:rsync` opens the Rsync Sync sheet using current pane context (default source = left, destination = right; configurable).
    - Optional flags in command for quick modes (e.g., `:rsync mirror`, `:rsync update`). Parser maps to `RsyncMode` and pre-populates config.

## Data Structures

- `RsyncMode`: enum with cases `.update`, `.mirror`, `.copyAll`, `.custom`.
- `RsyncPreviewResult`:
  - `copied: [RsyncItem]`, `updated: [RsyncItem]`, `deleted: [RsyncItem]`, `skipped: [RsyncItem]`
  - `counts: (copy: Int, update: Int, delete: Int, skip: Int)`
- `RsyncProgress`:
  - `message: String` (e.g., current file), `completed: Int`, `total: Int`
- `RsyncRunResult`:
  - `success: Bool`, `errors: [String]`, `summary: (copy: Int, update: Int, delete: Int, skip: Int)`
- `RsyncItem`:
  - `relativePath: String`, `action: RsyncAction`
- `RsyncAction`: enum `.copy`, `.update`, `.delete`, `.skip`

## Interaction Flow

1. Entry points

   - Menu, context menu (file/directory), keyboard shortcut (Shift+S), and `:rsync` command.
   - AppState computes source/destination from active panes and presents `RsyncSyncSheetView`.

2. Configure

   - User adjusts mode/toggles/excludes.
   - AppState updates `config` and surfaces built command preview from `RsyncService.buildCommand`.

3. Preview (dry-run)

   - User taps Continue → AppState calls `runPreview()`.
   - RsyncService performs dry-run and parses `--itemize-changes` output into `RsyncPreviewResult`.
   - AppState stores result; view shows summary and grouped lists.

4. Execute

   - User taps Run Sync → AppState calls `executeSync()`.
   - RsyncService runs real rsync with derived flags; emits `RsyncProgress` via AsyncStream.
   - AppState updates progress, stores final `RsyncRunResult`, shows completion summary.

5. Close
   - User cancels or closes sheet → `dismissRsyncSheet()` resets state.

## Validation & Errors

- Paths must be directories; RsyncService.validatePaths checks and throws error with localized message.

- Command building rejects unsafe inputs; excludes and custom flags are sanitized.

- Surface actionable errors in UI; never crash.

## Testing

- Unit tests for `RsyncService`:

  - `buildCommand(config:)` covers flags for all modes and excludes.
  - `parseDryRunOutput(_:)` parses itemized changes into correct buckets.
  - Dry-run and run with temporary directories (no network).

- AppState tests for flow: preview then run, progress updates.

- View snapshot tests for configuration and preview states.

- CommandParser tests for `:rsync` mapping.

## Implementation Steps

1. Models

   - Add `Models/RsyncSyncConfig.swift` and enums/structs listed above.

2. Services

   - Add `Services/RsyncService.swift` with async preview/run.

3. AppState

   - Extend with `RsyncUIState` and methods; wire into existing global state.

4. Views

   - Add `Views/RsyncSyncSheetView.swift` and integrate presentation from main view.

5. Commands

   - Update `Services/CommandParser.swift` to support `:rsync` with optional mode argument.

6. Localization

   - Add keys for labels, errors, and summaries per localization rules.

7. Tests
   - Add tests in `Zenith CommanderTests/` for Services, AppState, CommandParser.

## Notes

- Do not block main thread; use async subprocess for rsync.

- Keep business logic in Services, state in AppState, and UI-only in Views.

- Follow existing project architecture and localization system.

# Rsync Sync Feature - Implementation Tasks

## Feature: Rsync-based Sync for Dual-Pane

**Tech Stack**: Swift 5.9+, SwiftUI, AppKit, MVVM architecture

**Project Structure**:

- Models/: Data models and state structures
- Services/: Business logic and async operations
- Views/: SwiftUI UI components
- Localization/: Custom localization system (LocalizationManager, LocalizedStringKey enum)

---

## Phase 1: Setup

**Goal**: Initialize project structure and foundational types

**Tasks**:

- [x] T001 Create RsyncMode enum in Zenith Commander/Models/RsyncSyncConfig.swift
- [x] T002 Create RsyncAction enum in Zenith Commander/Models/RsyncSyncConfig.swift
- [x] T003 Create RsyncItem struct in Zenith Commander/Models/RsyncSyncConfig.swift
- [x] T004 Create RsyncPreviewResult struct in Zenith Commander/Models/RsyncSyncConfig.swift
- [x] T005 Create RsyncProgress struct in Zenith Commander/Models/RsyncSyncConfig.swift
- [x] T006 Create RsyncRunResult struct in Zenith Commander/Models/RsyncSyncConfig.swift

---

## Phase 2: Foundational Components

**Goal**: Build core configuration model and service infrastructure (blocking prerequisites for all user stories)

**Independent Test Criteria**: Configuration validates correctly, service can be instantiated

**Tasks**:

- [x] T007 Create RsyncSyncConfig struct with all fields in Zenith Commander/Models/RsyncSyncConfig.swift
- [x] T008 Implement isValid() method in RsyncSyncConfig in Zenith Commander/Models/RsyncSyncConfig.swift
- [x] T009 Implement effectiveFlags() method in RsyncSyncConfig in Zenith Commander/Models/RsyncSyncConfig.swift
- [x] T010 Create RsyncService class skeleton in Zenith Commander/Services/RsyncService.swift
- [x] T011 Implement validatePaths() helper in RsyncService in Zenith Commander/Services/RsyncService.swift
- [x] T012 Implement buildCommand() helper in RsyncService in Zenith Commander/Services/RsyncService.swift
- [x] T013 Add localization keys for rsync labels in Zenith Commander/Localization/LocalizationManager.swift
- [x] T014 Add localization keys for rsync errors in Zenith Commander/Localization/LocalizationManager.swift

---

## Phase 3: User Story 1 - Configure Sync

**Story**: As a user, I can configure a sync between the left and right panes so that one acts as source and the other as destination.

**Independent Test Criteria**: Configuration sheet opens, source/destination selector works, mode selection updates config

**Tasks**:

- [x] T015 [US1] Create RsyncUIState struct in Zenith Commander/Models/AppState+Rsync.swift
- [x] T016 [US1] Add rsyncUIState property to AppState in Zenith Commander/Models/AppState.swift
- [x] T017 [US1] Implement presentRsyncSheet(sourceIsLeft:) in Zenith Commander/Models/AppState+Rsync.swift
- [x] T018 [US1] Implement updateConfig(\_:) in Zenith Commander/Models/AppState+Rsync.swift
- [x] T019 [US1] Implement dismissRsyncSheet() in Zenith Commander/Models/AppState+Rsync.swift
- [x] T020 [P] [US1] Create RsyncSyncSheetView skeleton in Zenith Commander/Views/RsyncSyncSheetView.swift
- [x] T021 [P] [US1] Add source/destination selector UI in Zenith Commander/Views/RsyncSyncSheetView.swift
- [x] T022 [P] [US1] Add mode selector UI (Update/Mirror/CopyAll/Custom) in Zenith Commander/Views/RsyncSyncSheetView.swift
- [x] T023 [P] [US1] Add toggles for preserve attributes and delete extras in Zenith Commander/Views/RsyncSyncSheetView.swift
- [x] T024 [P] [US1] Add exclude patterns text field in Zenith Commander/Views/RsyncSyncSheetView.swift
- [x] T025 [P] [US1] Add custom flags input (visible only in Custom mode) in Zenith Commander/Views/RsyncSyncSheetView.swift
- [x] T026 [US1] Wire RsyncSyncSheetView bindings to AppState.rsyncUIState in Zenith Commander/Views/RsyncSyncSheetView.swift
- [x] T027 [US1] Add sheet presentation logic to MainView in Zenith Commander/Views/RsyncSyncSheetView.swift

---

## Phase 4: User Story 2 - Dry-Run Preview

**Story**: As a user, I can run a dry-run preview to see which files would be copied, updated, or deleted before executing.

**Independent Test Criteria**: Preview button triggers dry-run, results categorize actions correctly, UI shows summary and grouped lists

**Tasks**:

- [x] T028 [US2] Implement parseDryRunOutput(\_:) in RsyncService in Zenith Commander/Services/RsyncService.swift
- [x] T029 [US2] Implement preview(config:) async method in RsyncService in Zenith Commander/Services/RsyncService.swift
- [x] T030 [US2] Implement runPreview() in AppState+Rsync in Zenith Commander/Models/AppState+Rsync.swift
- [x] T031 [P] [US2] Add command preview display (read-only) in Zenith Commander/Views/RsyncSyncSheetView.swift
- [x] T032 [P] [US2] Add validation logic and Continue button state in Zenith Commander/Views/RsyncSyncSheetView.swift
- [x] T033 [P] [US2] Create preview summary view with counts in Zenith Commander/Views/RsyncSyncSheetView.swift
- [x] T034 [P] [US2] Create grouped list view for preview items in Zenith Commander/Views/RsyncSyncSheetView.swift
- [x] T035 [US2] Add Back and Run Sync actions to preview view in Zenith Commander/Views/RsyncSyncSheetView.swift

---

## Phase 5: User Story 3 - Execute Sync

**Story**: As a user, I can execute the sync and see progress updates with a final summary.

**Independent Test Criteria**: Run Sync executes rsync, progress updates stream correctly, final summary matches expected results

**Tasks**:

- [ ] T036 [US3] Implement run(config:progress:) async method in RsyncService in Zenith Commander/Services/RsyncService.swift
- [ ] T037 [US3] Implement executeSync() with AsyncStream in AppState+Rsync in Zenith Commander/Models/AppState+Rsync.swift
- [ ] T038 [P] [US3] Add progress indicator view in Zenith Commander/Views/RsyncSyncSheetView.swift
- [ ] T039 [P] [US3] Add completion summary view in Zenith Commander/Views/RsyncSyncSheetView.swift
- [ ] T040 [US3] Wire progress updates to UI in Zenith Commander/Views/RsyncSyncSheetView.swift

---

## Phase 6: User Story 4 - Delete Extras Mode

**Story**: As a user, I can choose whether to delete extra files in the destination that are not present in the source.

**Independent Test Criteria**: Mirror mode includes deletions in preview and execution, toggle works correctly

**Tasks**:

- [ ] T041 [P] [US4] Update effectiveFlags() to add --delete for mirror mode in Zenith Commander/Models/RsyncSyncConfig.swift
- [ ] T042 [P] [US4] Update parseDryRunOutput() to parse deletions in Zenith Commander/Services/RsyncService.swift
- [ ] T043 [US4] Verify delete extras toggle updates config.deleteExtras in Zenith Commander/Views/RsyncSyncSheetView.swift

---

## Phase 7: User Story 5 - Preserve Attributes

**Story**: As a user, I can preserve file attributes (timestamps, permissions) during sync.

**Independent Test Criteria**: Preserve attributes toggle adds correct flags, executed sync preserves attributes

**Tasks**:

- [ ] T044 [P] [US5] Update effectiveFlags() to add -a or specific flags when preserveAttributes is true in Zenith Commander/Models/RsyncSyncConfig.swift
- [ ] T045 [US5] Verify preserve attributes toggle updates config.preserveAttributes in Zenith Commander/Views/RsyncSyncSheetView.swift

---

## Phase 8: User Story 6 - Exclude Patterns

**Story**: As a user, I can specify simple exclude patterns to skip certain files or folders.

**Independent Test Criteria**: Exclude patterns prevent matching files from appearing in preview and execution

**Tasks**:

- [ ] T046 [P] [US6] Update buildCommand() to add multiple --exclude flags from excludePatterns in Zenith Commander/Services/RsyncService.swift
- [ ] T047 [US6] Verify exclude patterns field updates config.excludePatterns in Zenith Commander/Views/RsyncSyncSheetView.swift

---

## Phase 9: User Story 7 - Directory Validation

**Story**: As a user, I can only start a sync when both panes point to valid directories.

**Independent Test Criteria**: Continue button disabled for invalid paths, inline error shown, validation prevents execution

**Tasks**:

- [ ] T048 [P] [US7] Implement path validation in validatePaths() in Zenith Commander/Services/RsyncService.swift
- [ ] T049 [P] [US7] Add inline error display for validation failures in Zenith Commander/Views/RsyncSyncSheetView.swift
- [ ] T050 [US7] Wire validation to Continue button enabled state in Zenith Commander/Views/RsyncSyncSheetView.swift

---

## Phase 10: Command Integration

**Story**: Support keyboard shortcut (Shift+S), context menu, and :rsync command

**Independent Test Criteria**: All entry points open sync sheet with correct defaults

**Tasks**:

- [ ] T051 [P] Add :rsync command parsing in Zenith Commander/Services/CommandParser.swift
- [ ] T052 [P] Add :rsync mode argument support (update/mirror/copyAll/custom) in Zenith Commander/Services/CommandParser.swift
- [ ] T053 [P] Add Shift+S keyboard shortcut handler in Zenith Commander/Views/MainView.swift
- [ ] T054 Add context menu "Rsync Sync..." option for files in Zenith Commander/Views/PaneView.swift
- [ ] T055 Add context menu "Rsync Sync..." option for directories in Zenith Commander/Views/PaneView.swift

---

## Phase 11: Polish & Cross-Cutting Concerns

**Goal**: Error handling, localization completion, testing

**Tasks**:

- [ ] T056 [P] Add error handling and user-friendly messages in Zenith Commander/Services/RsyncService.swift
- [ ] T057 [P] Complete all localization strings for rsync feature in Zenith Commander/Localization/LocalizationManager.swift
- [ ] T058 [P] Write unit tests for RsyncService.buildCommand() in Zenith CommanderTests/RsyncServiceTests.swift
- [ ] T059 [P] Write unit tests for RsyncService.parseDryRunOutput() in Zenith CommanderTests/RsyncServiceTests.swift
- [ ] T060 [P] Write unit tests for RsyncService preview/run with temp directories in Zenith CommanderTests/RsyncServiceTests.swift
- [ ] T061 [P] Write AppState tests for rsync flow in Zenith CommanderTests/AppStateRsyncTests.swift
- [ ] T062 [P] Write CommandParser tests for :rsync command in Zenith CommanderTests/CommandParserTests.swift
- [ ] T063 Perform end-to-end manual testing of complete sync flow

---

## Dependencies

**Story Completion Order**:

1. Phase 1-2 (Setup & Foundational) → MUST complete first
2. Phase 3 (US1: Configure) → Required for all subsequent stories
3. Phase 4 (US2: Preview) → Required for Phase 5
4. Phase 5 (US3: Execute) → Can run after US2
5. Phase 6-9 (US4-7: Feature toggles) → Independent, can run in parallel after US3
6. Phase 10 (Command integration) → Can run after US1
7. Phase 11 (Polish) → Final phase after all features

**Parallel Execution Examples**:

- After Phase 2: T015-T019 (AppState), T020-T025 (UI) can run in parallel
- Phase 6-9: All US4-7 tasks can run in parallel
- Phase 10: T051-T055 can run in parallel
- Phase 11: T056-T062 (tests) can run in parallel

---

## Implementation Strategy

**MVP Scope**: Phase 1-5 (Setup → Configure → Preview → Execute)

**Incremental Delivery**:

1. Deliver MVP (Phase 1-5) for basic sync with preview
2. Add feature toggles (Phase 6-9) incrementally
3. Complete entry points (Phase 10)
4. Polish and harden (Phase 11)

---

## Format Validation

✅ All tasks follow checklist format: `- [ ] [TaskID] [Labels] Description with file path`

✅ Task IDs: Sequential T001-T063

✅ Labels: [P] for parallelizable tasks, [US#] for user story tasks

✅ File paths: Absolute paths included for all implementation tasks

✅ Phases: Organized by user story with clear goals and test criteria

✅ Dependencies: Documented with parallel opportunities identified

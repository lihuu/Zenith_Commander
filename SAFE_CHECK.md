Zenith Commander - File Safety & Security Guidelines
Overview
This document defines the strict safety protocols for file operations in Zenith Commander. All file manipulation code generated or written must adhere to these rules to prevent data loss.

1. The "Trash First" Rule
   Rule: NEVER use FileManager.removeItem(at:) for user-initiated deletion unless explicitly requested (e.g., "Shift+Delete" for permanent delete).
   Implementation:
   Always use FileManager.default.trashItem(at:resultSaveURL:).
   This moves files to the macOS Trash (Bin), allowing user recovery.
2. File Coordination (NSFileCoordinator)
   Rule: All write operations (Move, Rename, Delete, Edit) MUST be coordinated to prevent conflicts with other processes (Finder, Dropbox, iCloud).
   Implementation Pattern:
   let coordinator = NSFileCoordinator(filePresenter: nil)
   let intent = NSFileAccessIntent.writingIntent(with: targetURL, options: .forMoving)

coordinator.coordinate(with: [intent], queue: .main) { error in
if let error = error {
// Handle coordination error (e.g., file is locked by another app)
return
}
// Perform the actual file operation here safely
try? FileManager.default.moveItem(at: intent.url, to: destinationURL)
}

3. Atomic Writes
   Rule: When saving file content, always use atomic writing to prevent data corruption during crashes or power loss.
   Implementation:
   data.write(to: url, options: .atomic)
4. Permission Handling (Sandbox & TCC)
   Rule: Assume we do NOT have permission. Fail gracefully.
   Checklist:
   Check FileManager.default.isWritableFile(atPath:) before attempting operations.
   Wrap operations in do-catch blocks specifically handling CocoaError.fileWriteNoPermission.
   For persistent access across app launches, save Security Scoped Bookmarks for user-selected folders.
5. Undo Support (NSUndoManager)
   Rule: Every destructive action (Move, Rename, Trash) must be registerable with UndoManager.
   Implementation:
   When performing an action (e.g., Move A to B), immediately register the inverse action (Move B to A) with the UndoManager.
   This allows users to press Cmd+Z to fix mistakes immediately.
6. Dangerous Operation Guard (The "Are you sure?" Check)
   Rule: For bulk operations affecting >10 files or deleting non-empty folders:
   Requirement: Show a confirmation alert.
   Rsync Safety: When using rsync, ALWAYS run a --dry-run first and parse the output to warn about deletions (files missing in source but present in destination when using --delete).
   Summary for AI Assistant:
   When asked to implement file operations, YOU MUST:
   Use NSFileCoordinator.
   Use trashItem instead of removeItem.
   Wrap in do-catch with permission checks.

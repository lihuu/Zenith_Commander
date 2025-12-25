//
//  RsyncContextMenuProvider.swift
//  Zenith Commander
//
//  Rsync plugin context menu contribution
//

import SwiftUI

final class RsyncContextMenuProvider: ContextMenuProvider {
    func menuItems(for context: MenuContext) -> [MenuElement] {
        var elements: [MenuElement] = []

        // Only show rsync menu if:
        // 1. Rsync is enabled in settings
        // 2. We have valid paths
        guard SettingsManager.shared.settings.rsync.enabled,
            let inactivePath = context.inactivePanePath
        else {
            return []
        }

        // Add separator before rsync items
        elements.append(.separator(MenuSeparator(id: "rsync-separator")))

        // Sync selected items to opposite pane
        let hasSelection = !context.selectedFiles.isEmpty
        let syncTitle =
            hasSelection
            ? LocalizationManager.shared.localized(.rsyncMenuSyncSelected)
            : LocalizationManager.shared.localized(.rsyncMenuSyncDirectory)

        elements.append(
            .item(
                ContextMenuItem(
                    id: "rsync-sync-to-opposite",
                    title: syncTitle,
                    icon: "arrow.triangle.2.circlepath",
                    isEnabled: true,
                    action: { [weak self] in
                        await self?.handleSyncToOpposite(context: context)
                    }
                )))

        // Configure sync options
        elements.append(
            .item(
                ContextMenuItem(
                    id: "rsync-configure",
                    title: LocalizationManager.shared.localized(.rsyncMenuConfigure),
                    icon: "gearshape",
                    isEnabled: true,
                    action: { [weak self] in
                        await self?.handleConfigureSync(context: context)
                    }
                )))

        // Quick sync (mirror) to opposite pane
        elements.append(
            .item(
                ContextMenuItem(
                    id: "rsync-mirror",
                    title: LocalizationManager.shared.localized(.rsyncMenuMirror),
                    icon: "arrow.left.arrow.right",
                    isEnabled: hasSelection,
                    action: { [weak self] in
                        await self?.handleMirrorSync(context: context)
                    }
                )))

        return elements
    }

    // MARK: - Action Handlers

    @MainActor
    private func handleSyncToOpposite(context: MenuContext) async {
        // In a real implementation, this would be called from a View context
        // where AppState is available as @EnvironmentObject
        // For now, we use the shared singleton pattern
        let appState = AppState()

        // Determine source and destination based on active pane
        let sourceIsLeft = context.activePaneSide == .left
        appState.presentRsyncSheet(sourceIsLeft: sourceIsLeft)
    }

    @MainActor
    private func handleConfigureSync(context: MenuContext) async {
        let appState = AppState()

        // Open rsync configuration sheet
        let sourceIsLeft = context.activePaneSide == .left
        appState.presentRsyncSheet(sourceIsLeft: sourceIsLeft)
    }

    @MainActor
    private func handleMirrorSync(context: MenuContext) async {
        let appState = AppState()
        guard let inactivePath = context.inactivePanePath else { return }

        // Create mirror sync config
        let config = RsyncSyncConfig(
            source: context.currentPath,
            destination: inactivePath,
            mode: .mirror,
            dryRun: false,
            preserveAttributes: true,
            deleteExtras: true,
            excludePatterns: [],
            customFlags: []
        )

        // Execute mirror sync with progress
        appState.rsyncUIState.isRunningSync = true

        let (stream, continuation) = AsyncStream<RsyncProgress>.makeStream()

        Task {
            for await progress in stream {
                appState.rsyncUIState.syncProgress = progress
            }
        }

        do {
            let result = try await RsyncService.shared.run(
                config: config,
                progressContinuation: continuation
            )

            appState.rsyncUIState.syncResult = result

            if result.success {
                appState.showToast(LocalizationManager.shared.localized(.rsyncMirrorSuccess))
                // Refresh both panes
                await appState.leftPane.refresh(using: appState.env.fileSystem)
                await appState.rightPane.refresh(using: appState.env.fileSystem)
            } else {
                appState.rsyncUIState.error = result.errors.first
            }
        } catch {
            appState.rsyncUIState.error = error.localizedDescription
        }

        appState.rsyncUIState.isRunningSync = false
    }
}

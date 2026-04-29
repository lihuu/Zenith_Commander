//
//  AIContextMenuProvider.swift
//  Zenith Commander
//
//  Context menu provider for AI tools
//

import Foundation

final class AIContextMenuProvider: ContextMenuProvider {
    private let pluginContext: PluginContext
    private let settingsProvider: () -> AISettings
    private let service: AIServiceProviding

    init(
        context: PluginContext,
        settingsProvider: @escaping () -> AISettings = { SettingsManager.shared.settings.ai },
        service: AIServiceProviding = AIService.shared
    ) {
        pluginContext = context
        self.settingsProvider = settingsProvider
        self.service = service
    }

    func menuItems(for context: ContextMenuContext) -> [MenuElement] {
        guard context.placement == .directory else {
            return []
        }

        let settings = settingsProvider()
        guard settings.enabled else {
            return []
        }

        let panes = pluginContext.panes()
        let currentPath = panes.active == .left ? panes.leftPath : panes.rightPath
        let directory = URL(fileURLWithPath: currentPath)
        guard directory.isFileURL else {
            return []
        }

        let enabledTools = settings.tools.filter(\.enabled)
        guard !enabledTools.isEmpty else {
            return []
        }

        return [.separator(MenuSeparator(id: "ai-separator"))]
            + enabledTools.map { tool in
                .item(
                    ContextMenuItem(
                        id: "ai-open-\(tool.id)",
                        title: LocalizationManager.shared.localized(
                            .aiOpenToolHere,
                            tool.displayName
                        ),
                        icon: tool.icon,
                        isEnabled: service.isToolInstalled(tool),
                        action: { [weak self] in
                            await self?.handleOpenTool(tool)
                        }
                    )
                )
            }
    }

    @MainActor
    private func handleOpenTool(_ tool: AIToolConfig) async {
        let panes = pluginContext.panes()
        let currentPath = panes.active == .left ? panes.leftPath : panes.rightPath
        let directory = URL(fileURLWithPath: currentPath)

        do {
            try service.openToolInTerminal(tool: tool, at: directory)
        } catch {
            await pluginContext.dispatch(.ui(.toast(service.errorMessage(for: error, tool: tool))))
        }
    }
}

//
//  AICommandProvider.swift
//  Zenith Commander
//
//  Command provider for AI tool launcher
//

import Foundation

final class AICommandProvider: CommandProvider {
    private let context: PluginContext
    private let settingsProvider: () -> AISettings
    private let service: AIServiceProviding

    init(
        context: PluginContext,
        settingsProvider: @escaping () -> AISettings = { SettingsManager.shared.settings.ai },
        service: AIServiceProviding = AIService.shared
    ) {
        self.context = context
        self.settingsProvider = settingsProvider
        self.service = service
    }

    var commands: [CommandSpec] {
        [
            CommandSpec(
                name: "ai",
                help: LocalizationManager.shared.localized(.aiCommandHelp)
            )
        ]
    }

    func invoke(_ command: CommandInvocation) async throws -> CommandResult {
        let settings = settingsProvider()
        guard settings.enabled else {
            return .message(LocalizationManager.shared.localized(.aiDisabled))
        }

        let tools = settings.tools.filter(\.enabled)
        guard !tools.isEmpty else {
            return .message(LocalizationManager.shared.localized(.aiNoToolsConfigured))
        }

        guard let requestedTool = command.args.first else {
            let toolNames = tools.map(\.displayName).joined(separator: ", ")
            return .message(LocalizationManager.shared.localized(.aiAvailableTools, toolNames))
        }

        guard let tool = tools.first(where: { $0.matches(identifier: requestedTool) }) else {
            return .message(LocalizationManager.shared.localized(.aiUnknownTool, requestedTool))
        }

        let panes = context.panes()
        let currentPath = panes.active == .left ? panes.leftPath : panes.rightPath
        let directory = URL(fileURLWithPath: currentPath)

        do {
            try service.openToolInTerminal(tool: tool, at: directory)
            return .message(LocalizationManager.shared.localized(.aiOpenedTool, tool.displayName))
        } catch {
            return .message(service.errorMessage(for: error, tool: tool))
        }
    }
}

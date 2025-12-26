//
//  PluginManager.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/19/25.
//

import OSLog
import SwiftUI

final class PluginManager {
    static let shared = PluginManager()

    private var commandProviders: [String: any CommandProvider] = [:]
    private var uiProviders: [any UIContribution] = []
    private var contextMenuProviders: [any ContextMenuProvider] = []
    private var keybindingProviders: [any KeybindingProvider] = []
    private var settingsProviders: [any SettingsProvider] = []

    private init() {}

    /// Register  plugins
    func register(_ plugin: any ZenithPlugin, context: PluginContext) {
        context.logger.info("Registering plugin: \(plugin.displayName)")
        for capability in plugin.makeCapabilities(context: context) {
            switch capability.type {
            case .commandProvider:
                let provider = capability as! any CommandProvider
                for command in provider.commands {
                    commandProviders[command.name] = provider
                }
            case .uiContribution:
                uiProviders.append(capability as! any UIContribution)
            case .contextMenuProvider:
                contextMenuProviders.append(
                    capability as! any ContextMenuProvider
                )
            case .keybindingProvider:
                keybindingProviders.append(
                    capability as! any KeybindingProvider
                )
            case .settingsProvider:
                settingsProviders.append(
                    capability as! any SettingsProvider
                )
            case .toolRunner:
                // ToolRunner 目前固定ProcessToolRunner，先不通过插件扩展
                break
            }
        }
    }

    func handleCommand(_ command: CommandInvocation) async throws
        -> CommandResult
    {
        guard let provider = commandProviders[command.name] else {
            return .message("Unrecognized command: \(command.name)")
        }

        return try await provider.invoke(command)
    }

    func view(for request: UIRequest) -> AnyView? {
        for provider in uiProviders {
            if let view = provider.makeView(for: request) {
                return view
            }
        }
        return nil
    }

    func contextMenuItems() -> [MenuElement] {
        var items: [MenuElement] = []
        for provider in contextMenuProviders {
            items.append(contentsOf: provider.menuItems())
        }
        return items
    }

    /// Get all keybindings for a specific mode
    func keybindings(for mode: AppMode) -> [KeyChord: AppAction] {
        var bindings: [KeyChord: AppAction] = [:]
        for provider in keybindingProviders {
            for binding in provider.keybindings where binding.mode == mode {
                bindings[binding.keyChord] = binding.action
            }
        }
        return bindings
    }

    /// Get all keybindings from all providers
    func allKeybindings() -> [KeybindingDefinition] {
        var allBindings: [KeybindingDefinition] = []
        for provider in keybindingProviders {
            allBindings.append(contentsOf: provider.keybindings)
        }
        return allBindings
    }

    /// Get all settings providers sorted by order
    func allSettingsProviders() -> [any SettingsProvider] {
        settingsProviders.sorted { $0.settingsOrder < $1.settingsOrder }
    }
}

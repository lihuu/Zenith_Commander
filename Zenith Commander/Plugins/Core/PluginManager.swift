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

    /// 已注册过的插件 id —— 保证 `register` 幂等。
    /// 根因：`MainView.init` 内调用 `register`，而 `MainView` 会随语言切换
    /// （`ContentView().id(localizationManager.currentLanguage.id)`）被销毁重建，
    /// 导致 `register` 被重复调用。若不做幂等保护，`settingsProviders` 等
    /// 数组会累积重复条目，最终在 Settings 页渲染出多份同一插件的设置区域
    /// （见 bug：点击 Add AI Tool 后出现两个 AI Tools 区域）。
    private var registeredPluginIDs: Set<String> = []

    /// 非 private：允许单元测试创建独立实例做隔离（shared 单例在测试宿主里
    /// 可能已被 App 启动或其他测试注册过插件，会导致「首次注册」类断言失真）。
    /// 生产代码仍统一使用 `shared`。
    init() {}

    /// Register  plugins
    func register(_ plugin: any ZenithPlugin, context: PluginContext) {
        // 幂等：同一插件重复 `register` 时直接跳过，避免 provider 数组累积重复条目。
        // 这里的 key 用 `plugin.id.rawValue`（与各 `SettingsProvider.pluginId` 同源），
        // 因此即便 `MainView` 被多次重建，也不会再向 `settingsProviders` 等数组里追加重复项。
        guard !registeredPluginIDs.contains(plugin.id.rawValue) else {
            context.logger.info(
                "Plugin already registered, skipping: \(plugin.displayName)"
            )
            return
        }
        registeredPluginIDs.insert(plugin.id.rawValue)

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

    func contextMenuItems(for context: ContextMenuContext) -> [MenuElement] {
        var items: [MenuElement] = []
        for provider in contextMenuProviders {
            items.append(contentsOf: provider.menuItems(for: context))
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

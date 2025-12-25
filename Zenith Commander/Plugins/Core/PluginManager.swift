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

    private init() {}

    /// Register  plugins
    func register(_ plugin: any ZenithPlugin, context: PluginContext) {
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
}

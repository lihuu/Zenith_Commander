//
//  PluginManager.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/19/25.
//

import OSLog
import SwiftUI

final class PluginManager {
    private var commandProviders: [String: any CommandProvider] = [:]
    private var uiProviders: [any UIContribution] = []
    
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
            case .toolRunner:
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
}

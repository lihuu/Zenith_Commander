//
//  CommandProvider.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/19/25.
//

import SwiftUI

struct CommandSpec {
    let name: String
    let help: String
}

struct CommandInvocation {
    let name: String
    let args: [String]
}

enum CommandResult {
    case message(String)
    case openUI(UIRequest)
}

protocol CommandProvider: PluginCapability {
    var commands: [CommandSpec] { get }

    func invoke(_ command: CommandInvocation) async throws -> CommandResult
}

extension CommandProvider {
    var type: CapabilityType {
        .commandProvider
    }
}

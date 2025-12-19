//
//  RsyncCommandProvider.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/19/25.
//

final class RsyncCommandProvider: CommandProvider {
    private let context: PluginContext

    init(context: PluginContext) {
        self.context = context
    }
    
    
    var commands: [CommandSpec]{
        [CommandSpec(name: "rsync", help: "Synchronize files and directories")]
    }
    
    func invoke(_ command: CommandInvocation) async throws -> CommandResult{
        await context.dispatch(.showSheet(.rsyncSheet))
        return .openUI(.rsyncSheet)
    }
}


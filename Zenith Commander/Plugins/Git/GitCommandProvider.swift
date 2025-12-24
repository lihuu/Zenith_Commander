import SwiftUI

struct GitCommandProvider: CommandProvider {
    private let context: PluginContext

    init(context: PluginContext) {
        self.context = context
    }

    var commands: [CommandSpec] {
        [
            CommandSpec(name: "git", help: "Show Git History")
        ]
    }

    func invoke(_ command: CommandInvocation) async throws -> CommandResult {
        return .openUI(.gitPanel)
    }
}

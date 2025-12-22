import SwiftUI

final class GitCommandProvider: CommandProvider {
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
        // Dispatch UI event to show Git Panel
        // Note: Currently MainView handles .gitPanel via bottom sheet manually controlled by AppState.showGitHistory
        // But the plugin system allows .openUI(.gitPanel).
        // If we want to fully support CommandResult.openUI(.gitPanel) we need to ensure MainView handles it.
        // For now, let's make it consistent with AppState.
        
        // Since we don't have direct access to AppState here, we use context.dispatch
        // We probably need a new UIRequest type for gitPanel that UIHost knows about, OR
        // we reuse the existing mechanism.
        // Let's assume .openUI(.gitPanel) is the way.
        
        return .openUI(.gitPanel)
    }
}

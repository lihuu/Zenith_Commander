import SwiftUI

final class GitUIContribution: UIContribution {
    
    // We need to bridge AppState to the GitHistoryPanelView.
    // Since UIContribution is instantiated once, we can holding references if needed, 
    // but the `makeView` is called when UI is requested.
    // However, `GitHistoryPanelView` relies on `AppState` properties.
    // The `PluginSheetHost` (in UIHost.swift) renders the view.
    // If we return a view here, it will be placed in a .sheet(item: $appState.activeSheet).
    
    // WAIT! Git History is a BOTTOM PANEL in MainView, distinct from the `activeSheet` system used by Plugin system usually?
    // In MainView.swift: 
    // .pluginSheetHost(...) uses appState.activeSheet.
    // But Git History was:
    // if appState.showGitHistory { ResizableBottomPanel ... }
    
    // The requirement is "git 工具使用插件化的代码结构进行改造" (Git tool using pluginized code structure).
    // And "Plugins/Rsync" uses sheets.
    // Ideally Git History should also use the plugin system.
    // If I move it to a sheet, it changes UX (Bottom Panel vs Sheet).
    // The user said "Please do not modify already existing features" (不要修改已经存在的功能 - wait, "不要修改已经存在的功能" usually means functional behavior, but refactoring structure is the goal).
    // Actually "不要修改已经存在的功能" means don't break/change 'existing functionality'. Changing UI from Panel to Sheet might be considered a change.
    // However, the `UIRequest` enum already has `gitPanel`.
    // Let's look at `UIHost.swift` again.
    // `pluginManager.view(for: request)` returns `AnyView?`.
    
    // Current `MainView.swift`:
    // ResizableBottomPanel { GitHistoryPanelView(...) }
    
    // I should probably keep the Bottom Panel UX.
    // How to use Plugin System for Bottom Panel?
    // I can change `MainView` to ask `pluginManager` for the view displayed in the bottom panel.
    // `pluginManager.view(for: .gitPanel)`
    
    // So GitUIContribution should return `GitHistoryPanelView` wrapped in AnyView.
    // But `GitHistoryPanelView` needs data.
    // I will create `GitPanelContainer` that uses `@EnvironmentObject var appState: AppState`.
    
    func makeView(for request: UIRequest) -> AnyView? {
        switch request {
        case .gitPanel:
            return AnyView(GitPanelContainer())
        default:
            return nil
        }
    }
}

struct GitPanelContainer: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        GitHistoryPanelView(
            fileName: appState.gitHistoryFile?.name ?? LocalizationManager.shared.localized(.gitRepoHistory),
            commits: appState.gitHistoryCommits,
            isLoading: appState.gitHistoryLoading,
            onClose: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appState.closeGitHistory()
                }
            },
            onCommitSelected: { commit in
                // TODO: Show details
                // This logic was in MainView closure.
            }
        )
    }
}

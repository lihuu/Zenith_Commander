import SwiftUI

struct GitUIContribution: UIContribution {
    let context: PluginContext

    init(context: PluginContext) {
        self.context = context
    }

    func makeView(for request: UIRequest) -> AnyView? {
        switch request {
        case .gitPanel:
            return AnyView(GitPanelContainer(context: context))
        default:
            return nil
        }
    }
}

struct GitPanelContainer: View {
    let context: PluginContext
    @EnvironmentObject var appState: AppState

    var body: some View {
        GitHistoryPanelView(
            context: context,
            fileName: appState.gitHistoryFile?.name
                ?? LocalizationManager.shared.localized(.gitRepoHistory),
            commits: appState.gitHistoryCommits,
            isLoading: appState.gitHistoryLoading,
            isLoadingMore: appState.gitHistoryLoadingMore,
            hasMore: appState.gitHistoryHasMore,
            onClose: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appState.closeGitHistory()
                }
            },
            onCommitSelected: { commit in
                // TODO: Show details
                // This logic was in MainView closure.
            },
            onLoadMore: {
                appState.loadMoreGitHistory()
            }
        )
    }
}

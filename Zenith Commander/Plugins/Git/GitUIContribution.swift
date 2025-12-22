import SwiftUI

final class GitUIContribution: UIContribution {
    
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

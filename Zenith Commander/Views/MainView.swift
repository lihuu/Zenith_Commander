//
//  MainView.swift
//  Zenith Commander
//
//  主视图 - 双面板布局
//

import Combine
import SwiftUI
import os.log

struct MainView: View {
    @StateObject private var appState = AppState()
    @StateObject private var bookmarkManager = BookmarkManager.shared
    private var showSettings: Binding<Bool> {
        Binding<Bool>(
            get: { appState.mode == .settings },
            set: { newValue in
                if !newValue {
                    appState.exitMode()
                }
            }
        )
    }

    private var showHelp: Binding<Bool> {
        Binding<Bool>(
            get: { appState.mode == .help },
            set: { newValue in
                if !newValue {
                    appState.exitMode()
                }
            }
        )
    }  // 帮助视图显示状态

    @State private var gitHistoryPanelHeight: CGFloat = 250  // Git 历史面板高度（本地状态，避免触发全局刷新）

    var body: some View {
        VStack(spacing: 0) {
            // 书签栏
            if appState.showBookmarkBar {
                BookmarkBarView(
                    bookmarkManager: bookmarkManager,
                    onBookmarkClicked: { bookmark in
                        navigateToBookmark(bookmark)
                    }
                )
            }

            // 双面板区域
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        // 左面板
                        PaneView(
                            pane: appState.leftPane,
                            bookmarkManager: bookmarkManager,
                            side: .left
                        )
                        .frame(width: geometry.size.width / 2)

                        // 分隔线
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: 1)

                        // 右面板
                        PaneView(
                            pane: appState.rightPane,
                            bookmarkManager: bookmarkManager,
                            side: .right
                        )
                        .frame(width: geometry.size.width / 2 - 1)
                    }

                    // Git History 底部面板
                    if appState.showGitHistory {
                        ResizableBottomPanel(
                            height: $gitHistoryPanelHeight,
                            isVisible: $appState.showGitHistory,
                            minHeight: 100,
                            maxHeight: geometry.size.height * 0.6
                        ) {
                            GitHistoryPanelView(
                                fileName: appState.gitHistoryFile?.name
                                    ?? LocalizationManager.shared.localized(
                                        .gitRepoHistory
                                    ),
                                commits: appState.gitHistoryCommits,
                                isLoading: appState.gitHistoryLoading,
                                onClose: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        appState.closeGitHistory()
                                    }
                                },
                                onCommitSelected: { commit in
                                    Logger.git.debug(
                                        "Commit selected: \(commit.shortHash, privacy: .public)"
                                    )
                                    // TODO: 显示 commit 详情或 diff
                                }
                            )
                        }
                    }
                }
            }

            // 状态栏
            StatusBarView(
                mode: appState.mode,
                statusText: appState.statusText,
                driveName: appState.currentPane.activeTab.drive.name,
                itemCount: appState.currentPane.activeTab.files.count,
                selectedCount: appState.currentPane.selections.count,
                gitInfo: appState.currentPane.gitInfo,
                onDriveClick: {
                    appState.enterMode(.driveSelect)
                }
            )
        }.environmentObject(appState)
            .background(Theme.background)
            .toast(message: appState.toastMessage)
            .overlay {
                // 驱动器选择器
                if appState.showDriveSelector {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            appState.exitMode()
                        }

                    DriveSelectorView(
                        drives: appState.availableDrives,
                        cursorIndex: appState.driveSelectorCursor,
                        onSelect: { drive in
                            Task { await appState.selectDrive(drive) }
                        },
                        onDismiss: {
                            appState.exitMode()
                        }
                    )
                }

                // 批量重命名模态窗口
                if appState.showRenameModal {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            appState.showRenameModal = false
                            appState.exitMode()  // 退出 BATCH_RENAME 模式
                        }

                    BatchRenameView(
                        isPresented: $appState.showRenameModal,
                        findText: $appState.renameFindText,
                        replaceText: $appState.renameReplaceText,
                        useRegex: $appState.renameUseRegex,
                        selectedFiles: appState.selectedFiles(),
                        onApply: {
                            Task { await appState.performBatchRename() }
                        },
                        onDismiss: {
                            appState.exitMode()  // 退出 BATCH_RENAME 模式
                        }
                    )
                }

                // Connection Manager Modal
                if appState.showConnectionManager {
                    ConnectionManagerView(
                        isPresented: $appState.showConnectionManager,
                        appState: appState
                    )
                }
            }
            .sheet(
                isPresented: showSettings,
                onDismiss: {
                    // 关闭设置时退出 SETTINGS 模式
                    appState.exitMode()
                }
            ) {
                SettingsView()
            }
            .sheet(
                isPresented: showHelp,
                onDismiss: {
                    // 关闭帮助时退出 HELP 模式
                    appState.exitMode()
                }
            ) {
                HelpView()
            }
            .sheet(
                isPresented: $appState.rsyncUIState.showConfigSheet,
                onDismiss: {
                    appState.dismissRsyncSheet()
                }
            ) {
                if let config = appState.rsyncUIState.config {
                    RsyncSyncSheetView(config: config)
                        .environmentObject(appState)
                }
            }
            .focusable()
            .onKeyPress { keyPress in
                handleKeyPress(keyPress)
            }
            .onAppear {
                // 加载可用驱动器 - 使用异步更新避免在视图更新期间修改 @Published 属性
                DispatchQueue.main.async {
                    appState.availableDrives = FileSystemService.shared
                        .getMountedVolumes()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openSettings)) {
                _ in
                appState.enterMode(.settings)
            }
            .onReceive(NotificationCenter.default.publisher(for: .showHelp)) {
                _ in
                appState.enterMode(.help)
            }
            .onReceive(NotificationCenter.default.publisher(for: .goToParent)) {
                _ in
                Task { @MainActor in
                    await appState.leaveDirectory()
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .enterDirectory)
            ) {
                _ in
                Task { @MainActor in
                    await appState.enterDirectory()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .switchPane)) {
                _ in
                Task { @MainActor in
                    await appState.dispatch(.pane(.toggleActivePane))
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .newTab)) {
                _ in
                Task { @MainActor in
                    await appState.dispatch(.paneAsync(.newTab))
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .closeTab)) {
                _ in
                Task { @MainActor in
                    await appState.dispatch(.pane(.closeTab))
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSApplication.willTerminateNotification
                )
            ) { _ in
                // 应用退出时保存当前路径
                appState.saveCurrentPaths()
            }
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        print("🎹 KeyPress: key=\(keyPress.key), mode=\(appState.mode)")
        guard let action = appState.mode.action(for: keyPress) else {
            print("🎹 KeyPress: no action found for this key in \(appState.mode) mode")
            return .ignored
        }

        print("🎹 KeyPress: action=\(action)")
        Task { @MainActor in
            await appState.dispatch(action)
        }

        return .handled
    }

    /// 导航到书签位置
    private func navigateToBookmark(_ bookmark: BookmarkItem) {
        Task {
            let pane = appState.currentPane

            if bookmark.type == .folder {
                // 如果是文件夹，导航到该目录
                pane.activeTab.currentPath = bookmark.path
                let files = await FileSystemService.shared.loadDirectory(
                    at: bookmark.path
                )

                await MainActor.run {
                    pane.activeTab.files = files
                    pane.cursorIndex = 0
                    pane.objectWillChange.send()
                }
            } else {
                // 如果是文件，直接使用默认应用打开
                let _ = await MainActor.run {
                    NSWorkspace.shared.open(bookmark.path)
                }
            }
        }
    }

}

#Preview {
    MainView()
        .frame(width: 1200, height: 800)
        .environmentObject(AppState())
}

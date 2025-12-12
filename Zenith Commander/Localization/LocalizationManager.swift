//
//  LocalizationManager.swift
//  Zenith Commander
//
//  国际化管理器 - 管理应用语言设置
//

import SwiftUI
import Combine

// MARK: - 支持的语言

/// 应用支持的语言枚举
/// 添加新语言时，在这里添加新的 case，并在 LocalizedStrings 中添加对应的翻译
enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case english = "en"
    case chinese = "zh-Hans"
    // 未来可以添加更多语言:
    // case japanese = "ja"
    // case korean = "ko"
    // case french = "fr"
    // case german = "de"
    // case spanish = "es"
    
    var id: String { rawValue }
    
    /// 语言显示名称（原生名称）
    var nativeName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "简体中文"
        }
    }
    
    /// 语言显示名称（英文）
    var englishName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "Chinese (Simplified)"
        }
    }
    
    /// 语言图标
    var icon: String {
        switch self {
        case .english: return "🇺🇸"
        case .chinese: return "🇨🇳"
        }
    }
    
    /// 语言代码（用于 Locale）
    var localeIdentifier: String {
        rawValue
    }
}

// MARK: - 本地化管理器

/// 本地化管理器 - 单例模式
/// 语言设置跟随系统语言，只支持中文和英文，其他语言默认使用英文
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    /// 当前语言（只读，跟随系统语言）
    @Published private(set) var currentLanguage: AppLanguage
    
    private init() {
        // 读取系统语言设置
        self.currentLanguage = Self.detectSystemLanguage()
    }
    
    /// 检测系统语言，只支持中文和英文，其他语言默认使用英文
    private static func detectSystemLanguage() -> AppLanguage {
        // 获取系统首选语言列表
        let preferredLanguages = Locale.preferredLanguages
        
        for languageCode in preferredLanguages {
            // 检查是否是中文（简体或繁体都算中文）
            if languageCode.hasPrefix("zh") {
                return .chinese
            }
            // 检查是否是英文
            if languageCode.hasPrefix("en") {
                return .english
            }
        }
        
        // 默认使用英文
        return .english
    }
    
    /// 刷新语言设置（当系统语言变化时调用）
    
    /// 获取本地化字符串
    func localized(_ key: LocalizedStringKey) -> String {
        return LocalizedStrings.shared.get(key, for: currentLanguage)
    }
    
    /// 获取带参数的本地化字符串
    func localized(_ key: LocalizedStringKey, _ args: CVarArg...) -> String {
        let format = LocalizedStrings.shared.get(key, for: currentLanguage)
        return String(format: format, arguments: args)
    }
}

// MARK: - 本地化字符串 Key

/// 所有可本地化的字符串 Key
/// 添加新的本地化字符串时，在这里添加新的 case
enum LocalizedStringKey: String, CaseIterable {
    // MARK: - 通用
    case appName
    case ok
    case cancel
    case confirm
    case delete
    case save
    case close
    case reset
    case done
    case error
    case success
    case warning
    case loading
    case yes
    case no
    
    // MARK: - 模式名称
    case modeNormal
    case modeVisual
    case modeCommand
    case modeFilter
    case modeDrives
    case modeAI
    case modeRename
    case modeSettings
    case modeHelp
    
    // MARK: - 设置页面
    case settings
    case settingsAppearance
    case settingsTheme
    case settingsThemeLight
    case settingsThemeDark
    case settingsThemeAuto
    case settingsFontSize
    case settingsLineHeight
    case settingsTerminal
    case settingsDefaultTerminal
    case settingsInstalled
    case settingsNotInstalled
    case settingsResetToDefaults
    case settingsResetConfirmTitle
    case settingsResetConfirmMessage
    case settingsLanguage
    case settingsLanguageDescription
    case settingsRestartRequired
    case settingsRestartTitle
    case settingsRestartMessage
    case settingsRestartNow
    case settingsRestartLater
    
    // MARK: - Git 设置
    case settingsGit
    case settingsGitEnabled
    case settingsGitEnabledDescription
    case settingsGitInstalled
    case settingsGitNotInstalled
    case settingsGitShowUntracked
    case settingsGitShowUntrackedDescription
    case settingsGitShowIgnored
    case settingsGitShowIgnoredDescription
    
    // MARK: - Rsync Settings
    case settingsRsync
    case settingsRsyncEnabled
    case settingsRsyncEnabledDescription
    case settingsRsyncInstalled
    case settingsRsyncNotInstalled
    
    // MARK: - Git 状态显示
    case gitStatusModified
    case gitStatusAdded
    case gitStatusDeleted
    case gitStatusRenamed
    case gitStatusUntracked
    case gitStatusConflict
    case gitBranch
    case gitAhead
    case gitBehind
    
    // MARK: - 帮助页面
    case help
    case helpKeyboardShortcuts
    case helpNavigation
    case helpModeSwitching
    case helpFileOperations
    case helpTabs
    case helpBookmarks
    case helpSettingsTheme
    case helpVisualMode
    case helpCommandMode
    case helpPressToClose
    
    // MARK: - 导航
    case moveCursorUp
    case moveCursorDown
    case goToParent
    case enterDirectory
    case jumpToFirst
    case jumpToLast
    case switchPanes
    case openFile
    
    // MARK: - 模式切换
    case enterVisualMode
    case enterCommandMode
    case enterFilterMode
    case openDriveSelector
    case openHelp
    case exitMode
    
    // MARK: - 文件操作
    case copyFiles
    case pasteFiles
    case refreshDirectory
    case batchRename
    case createDirectory
    case createFile
    case moveFile
    case copyFile
    case deleteFile
    case changeDirectory
    case openSelected
    case openTerminal
    case quitApp
    
    // MARK: - 标签页
    case newTab
    case closeTab
    case previousTab
    case nextTab
    
    // MARK: - 书签
    case toggleBookmarkBar
    case addToBookmarks
    
    // MARK: - 主题
    case openSettings
    case cycleTheme
    
    // MARK: - Visual 模式
    case extendSelection
    case selectAll
    case batchRenameSelected
    case exitVisualMode
    
    // MARK: - 文件列表
    case name
    case size
    case dateModified
    case kind
    case noFiles
    case items
    case selected
    
    // MARK: - 状态栏
    case freeSpace
    case totalSpace
    
    // MARK: - 批量重命名
    case batchRenameTitle
    case batchRenamePattern
    case batchRenamePreview
    case batchRenameApply
    case batchRenameVariables
    
    // MARK: - AI 分析
    case aiAnalyzing
    case aiAnalysisResult
    case aiAnalysisError
    
    // MARK: - 权限
    case permissionRequired
    case permissionDescription
    case permissionGrant
    
    // MARK: - Toast 消息
    case toastCopied
    case toastPasted
    case toastDeleted
    case toastCreated
    case toastMoved
    case toastRenamed
    case toastBookmarkAdded
    case toastBookmarkRemoved
    
    // MARK: - Git History
    case gitHistory
    case gitCommits
    case gitLoadingHistory
    case gitNoHistory
    case gitShowHistory
    case gitRepoHistory
    case gitCommitDetails
    case gitChangedFiles
    case gitViewDiff
    case gitCommitHash
    case gitCommitAuthor
    case gitCommitDate
    case gitCommitMessage
    case gitCommitParent
    case gitShowDetails
    case gitCopyHash
    
    // MARK: - 错误消息
    case errorFileNotFound
    case errorPermissionDenied
    case errorOperationFailed
    case errorInvalidPath
    case errorDirectoryNotEmpty
    
    // MARK: - Context Menu
    case contextOpen
    case contextOpenInTerminal
    case contextRemoveFromBookmarks
    case contextAddToBookmarks
    case contextCopyYank
    case contextPaste
    case contextShowInFinder
    case contextCopyFullPath
    case contextRename
    case contextMoveToTrash
    case contextRefresh
    case contextNewFile
    case contextNewFolder
    
    // MARK: - Bookmark Bar
    case bookmarkBarEmpty
    case bookmarkBarEditDone
    case bookmarkBarEdit
    
    // MARK: - Toast Messages (Detailed)
    case toastBookmarkBarShown
    case toastBookmarkBarHidden
    case toastAlreadyBookmarked
    case toastBookmarksAdded
    case toastTheme
    case toastSwitchedToDrive
    case toastFailedToCreateDirectory
    case toastFailedToCreateFile
    case toastMoveFailed
    case toastCopyFailed
    case toastDeleteFailed
    case toastNoFileSelected
    case toastUnknownCommand
    case toastNoFilesForRename
    case toastFindTextEmpty
    case toastFilesRenamed
    case toastFileRenamed
    case toastRenamedWithErrors
    case toastRenameError
    case toastCannotDeleteParent
    case toastNoFilesToDelete
    case toastFilesMovedToTrash
    case toastTargetNotFolder
    case toastCannotMoveToSame
    case toastItemsMoved
    case toastItemsCopied
    case toastPathCopied
    case toastRefreshed
    case toastDirectoryNotFound
    case toastCreatedFile
    case toastCreatedFolder
    case toastErrorCreatingFile
    case toastErrorCreatingFolder
    case toastFilesYanked
    case toastNoFilesToYank
    case toastFilesCut
    case toastNavigatedTo
    case toastOpening
    case toastCannotCopyParent
    case toastSelectFileForGitHistory
    case toastNewTabCreated
    case toastRsyncDisabled
    
    // MARK: - 菜单栏
    case menuNavigation
    case menuView
    case menuHelp
    case menuAbout
    case menuShowHelp
    case menuSettings
    case menuEdit
    case menuCut
    case menuCopy
    case menuPaste
    case menuSelectAll
    case menuUndo
    case menuRedo
    case menuHide
    case menuHideOthers
    case menuShowAll
    case menuQuit
    
    // MARK: - Rsync Sync
    case rsyncSync
    case rsyncSyncTitle
    case rsyncSource
    case rsyncDestination
    case rsyncMode
    case rsyncModeUpdate
    case rsyncModeMirror
    case rsyncModeCopyAll
    case rsyncModeCustom
    case rsyncPreserveAttributes
    case rsyncDeleteExtras
    case rsyncExcludePatterns
    case rsyncCustomFlags
    case rsyncCommandPreview
    case rsyncContinue
    case rsyncPreview
    case rsyncRun
    case rsyncBack
    case rsyncProgress
    case rsyncComplete
    case rsyncCopied
    case rsyncUpdated
    case rsyncDeleted
    case rsyncSkipped
    case rsyncErrors
    case rsyncSummary
    
    // MARK: - Rsync Errors
    case rsyncErrorSourceNotFound
    case rsyncErrorSourceNotDirectory
    case rsyncErrorDestinationNotFound
    case rsyncErrorDestinationNotDirectory
    case rsyncErrorSameSourceDestination
    case rsyncErrorExecutionFailed
    case rsyncErrorInvalidPath
    case rsyncErrorValidation
}

// MARK: - 本地化字符串存储

/// 本地化字符串存储 - 包含所有语言的翻译
class LocalizedStrings {
    static let shared = LocalizedStrings()
    
    private var translations: [AppLanguage: [LocalizedStringKey: String]] = [:]
    
    private init() {
        setupEnglish()
        setupChinese()
    }
    
    /// 获取指定语言的本地化字符串
    func get(_ key: LocalizedStringKey, for language: AppLanguage) -> String {
        return translations[language]?[key] ?? translations[.english]?[key] ?? key.rawValue
    }
    
    // MARK: - English Translations
    
    private func setupEnglish() {
        translations[.english] = [
            // 通用
            .appName: "Zenith Commander",
            .ok: "OK",
            .cancel: "Cancel",
            .confirm: "Confirm",
            .delete: "Delete",
            .save: "Save",
            .close: "Close",
            .reset: "Reset",
            .done: "Done",
            .error: "Error",
            .success: "Success",
            .warning: "Warning",
            .loading: "Loading...",
            .yes: "Yes",
            .no: "No",
            
            // 模式名称
            .modeNormal: "NORMAL",
            .modeVisual: "VISUAL",
            .modeCommand: "COMMAND",
            .modeFilter: "FILTER",
            .modeDrives: "DRIVES",
            .modeAI: "AI",
            .modeRename: "RENAME",
            .modeSettings: "SETTINGS",
            .modeHelp: "HELP",
            
            // 设置页面
            .settings: "Settings",
            .settingsAppearance: "Appearance",
            .settingsTheme: "Theme",
            .settingsThemeLight: "Light",
            .settingsThemeDark: "Dark",
            .settingsThemeAuto: "Auto",
            .settingsFontSize: "Font Size",
            .settingsLineHeight: "Line Height",
            .settingsTerminal: "Terminal",
            .settingsDefaultTerminal: "Default Terminal",
            .settingsInstalled: "Installed",
            .settingsNotInstalled: "Not Installed",
            .settingsResetToDefaults: "Reset to Defaults",
            .settingsResetConfirmTitle: "Reset Settings",
            .settingsResetConfirmMessage: "Are you sure you want to reset all settings to their default values?",
            .settingsLanguage: "Language",
            .settingsLanguageDescription: "Select your preferred language",
            .settingsRestartRequired: "Restart required for menu language to take effect",
            .settingsRestartTitle: "Restart Required",
            .settingsRestartMessage: "The app needs to restart for the language change to fully take effect on system menus.",
            .settingsRestartNow: "Restart Now",
            .settingsRestartLater: "Restart Later",
            
            // Git 设置
            .settingsGit: "Git Integration",
            .settingsGitEnabled: "Enable Git Integration",
            .settingsGitEnabledDescription: "Show Git status indicators for files and folders",
            .settingsGitInstalled: "Git is installed",
            .settingsGitNotInstalled: "Git is not installed",
            .settingsGitShowUntracked: "Show Untracked Files",
            .settingsGitShowUntrackedDescription: "Display status for files not tracked by Git",
            .settingsGitShowIgnored: "Show Ignored Files",
            .settingsGitShowIgnoredDescription: "Display status for files in .gitignore",
            
            // Rsync Settings
            .settingsRsync: "Rsync Integration",
            .settingsRsyncEnabled: "Enable Rsync Integration",
            .settingsRsyncEnabledDescription: "Enable Rsync features (Context Menu, Shortcuts)",
            .settingsRsyncInstalled: "Rsync is installed",
            .settingsRsyncNotInstalled: "Rsync is not installed",
            
            // Git 状态显示
            .gitStatusModified: "Modified",
            .gitStatusAdded: "Added",
            .gitStatusDeleted: "Deleted",
            .gitStatusRenamed: "Renamed",
            .gitStatusUntracked: "Untracked",
            .gitStatusConflict: "Conflict",
            .gitBranch: "Branch",
            .gitAhead: "ahead",
            .gitBehind: "behind",
            
            // Git History
            .gitHistory: "Git History",
            .gitCommits: "commits",
            .gitLoadingHistory: "Loading history...",
            .gitNoHistory: "No git history for this file",
            .gitShowHistory: "Show Git History",
            .gitRepoHistory: "Repository History",
            .gitCommitDetails: "Commit Details",
            .gitChangedFiles: "Changed Files",
            .gitViewDiff: "View Diff",
            .gitCommitHash: "Commit Hash",
            .gitCommitAuthor: "Author",
            .gitCommitDate: "Date",
            .gitCommitMessage: "Message",
            .gitCommitParent: "Parent",
            .gitShowDetails: "Show Details",
            .gitCopyHash: "Copy Hash",
            
            // 帮助页面
            .help: "Help",
            .helpKeyboardShortcuts: "Keyboard Shortcuts",
            .helpNavigation: "Navigation",
            .helpModeSwitching: "Mode Switching",
            .helpFileOperations: "File Operations",
            .helpTabs: "Tabs",
            .helpBookmarks: "Bookmarks",
            .helpSettingsTheme: "Settings & Theme",
            .helpVisualMode: "Visual Mode",
            .helpCommandMode: "Command Mode",
            .helpPressToClose: "Press ESC or ? to close",
            
            // 导航
            .moveCursorUp: "Move cursor up",
            .moveCursorDown: "Move cursor down",
            .goToParent: "Go to parent directory",
            .enterDirectory: "Enter directory",
            .jumpToFirst: "Jump to first item",
            .jumpToLast: "Jump to last item",
            .switchPanes: "Switch between panes",
            .openFile: "Open file/Enter directory",
            
            // 模式切换
            .enterVisualMode: "Enter Visual mode (select multiple)",
            .enterCommandMode: "Enter Command mode",
            .enterFilterMode: "Enter Filter mode",
            .openDriveSelector: "Open Drive selector",
            .openHelp: "Open Help",
            .exitMode: "Exit current mode / Cancel",
            
            // 文件操作
            .copyFiles: "Copy (yank) selected files",
            .pasteFiles: "Paste files",
            .refreshDirectory: "Refresh current directory",
            .batchRename: "Batch rename selected files",
            .createDirectory: "Create directory",
            .createFile: "Create file",
            .moveFile: "Move selected to dest",
            .copyFile: "Copy selected to dest",
            .deleteFile: "Delete selected files",
            .changeDirectory: "Change directory",
            .openSelected: "Open selected file",
            .openTerminal: "Open terminal here",
            .quitApp: "Quit application",
            
            // 标签页
            .newTab: "New tab",
            .closeTab: "Close current tab",
            .previousTab: "Previous tab",
            .nextTab: "Next tab",
            
            // 书签
            .toggleBookmarkBar: "Toggle bookmark bar",
            .addToBookmarks: "Add to bookmarks",
            
            // 主题
            .openSettings: "Open Settings",
            .cycleTheme: "Cycle theme (Light/Dark/Auto)",
            
            // Visual 模式
            .extendSelection: "Extend selection",
            .selectAll: "Select all",
            .batchRenameSelected: "Batch rename selected files",
            .exitVisualMode: "Exit Visual mode",
            
            // 文件列表
            .name: "Name",
            .size: "Size",
            .dateModified: "Date Modified",
            .kind: "Kind",
            .noFiles: "No files",
            .items: "items",
            .selected: "selected",
            
            // 状态栏
            .freeSpace: "Free",
            .totalSpace: "Total",
            
            // 批量重命名
            .batchRenameTitle: "Batch Rename",
            .batchRenamePattern: "Pattern",
            .batchRenamePreview: "Preview",
            .batchRenameApply: "Apply",
            .batchRenameVariables: "Variables",
            
            // AI 分析
            .aiAnalyzing: "Analyzing...",
            .aiAnalysisResult: "Analysis Result",
            .aiAnalysisError: "Analysis failed",
            
            // 权限
            .permissionRequired: "Permission Required",
            .permissionDescription: "Zenith Commander needs access to your files",
            .permissionGrant: "Grant Access",
            
            // Toast 消息
            .toastCopied: "Copied to clipboard",
            .toastPasted: "Pasted successfully",
            .toastDeleted: "Deleted successfully",
            .toastCreated: "Created successfully",
            .toastMoved: "Moved successfully",
            .toastRenamed: "Renamed successfully",
            .toastBookmarkAdded: "Bookmark added",
            .toastBookmarkRemoved: "Bookmark removed",
            
            // 错误消息
            .errorFileNotFound: "File not found",
            .errorPermissionDenied: "Permission denied",
            .errorOperationFailed: "Operation failed",
            .errorInvalidPath: "Invalid path",
            .errorDirectoryNotEmpty: "Directory is not empty",
            
            // Context Menu
            .contextOpen: "Open",
            .contextOpenInTerminal: "Open in Terminal",
            .contextRemoveFromBookmarks: "Remove from Bookmarks",
            .contextAddToBookmarks: "Add to Bookmarks (⌘B)",
            .contextCopyYank: "Copy (y)",
            .contextPaste: "Paste (p)",
            .contextShowInFinder: "Show in Finder",
            .contextCopyFullPath: "Copy Full Path",
            .contextRename: "Rename",
            .contextMoveToTrash: "Move to Trash",
            .contextRefresh: "Refresh (R)",
            .contextNewFile: "New File",
            .contextNewFolder: "New Folder",
            
            // Bookmark Bar
            .bookmarkBarEmpty: "No bookmarks - Right-click to add",
            .bookmarkBarEditDone: "Done",
            .bookmarkBarEdit: "Edit",
            
            // Toast Messages (Detailed)
            .toastBookmarkBarShown: "Bookmark bar shown",
            .toastBookmarkBarHidden: "Bookmark bar hidden",
            .toastAlreadyBookmarked: "Already bookmarked",
            .toastBookmarksAdded: "%d bookmark(s) added",
            .toastTheme: "Theme: %@",
            .toastSwitchedToDrive: "Switched to %@",
            .toastFailedToCreateDirectory: "Failed to create directory: %@",
            .toastFailedToCreateFile: "Failed to create file: %@",
            .toastMoveFailed: "Move failed: %@",
            .toastCopyFailed: "Copy failed: %@",
            .toastDeleteFailed: "Delete failed: %@",
            .toastNoFileSelected: "No file selected",
            .toastUnknownCommand: "Unknown command: %@",
            .toastNoFilesForRename: "No files selected for rename",
            .toastFindTextEmpty: "Find text cannot be empty",
            .toastFilesRenamed: "%d file(s) renamed successfully",
            .toastFileRenamed: "Renamed '%@' to '%@'",
            .toastRenamedWithErrors: "%d renamed, %d failed",
            .toastRenameError: "Rename failed: %@",
            .toastCannotDeleteParent: "Cannot delete parent directory item",
            .toastNoFilesToDelete: "No files to delete",
            .toastFilesMovedToTrash: "%d file(s) moved to Trash",
            .toastTargetNotFolder: "Target is not a folder",
            .toastCannotMoveToSame: "Cannot move to same location",
            .toastItemsMoved: "Moved %d item(s)",
            .toastItemsCopied: "Copied %d item(s)",
            .toastPathCopied: "Path copied: %@",
            .toastRefreshed: "Refreshed",
            .toastDirectoryNotFound: "Directory not found: %@",
            .toastCreatedFile: "Created file: %@",
            .toastCreatedFolder: "Created folder: %@",
            .toastErrorCreatingFile: "Error creating file: %@",
            .toastErrorCreatingFolder: "Error creating folder: %@",
            .toastFilesYanked: "%d file(s) yanked",
            .toastNoFilesToYank: "No files to yank",
            .toastFilesCut: "%d file(s) cut",
            .toastNavigatedTo: "Navigated to %@",
            .toastOpening: "Opening %@...",
            .toastCannotCopyParent: "Cannot copy parent directory item",
            .toastSelectFileForGitHistory: "Select a file to view Git history",
            .toastNewTabCreated: "New tab created",
            .toastRsyncDisabled: "Rsync integration is disabled in Settings",
            
            // Menu Bar
            .menuNavigation: "Navigation",
            .menuView: "View",
            .menuHelp: "Help",
            .menuAbout: "About Zenith Commander",
            .menuShowHelp: "Zenith Commander Help",
            .menuSettings: "Settings...",
            .menuEdit: "Edit",
            .menuCut: "Cut",
            .menuCopy: "Copy",
            .menuPaste: "Paste",
            .menuSelectAll: "Select All",
            .menuUndo: "Undo",
            .menuRedo: "Redo",
            .menuHide: "Hide Zenith Commander",
            .menuHideOthers: "Hide Others",
            .menuShowAll: "Show All",
            .menuQuit: "Quit Zenith Commander",
            
            // Rsync Sync
            .rsyncSync: "Rsync Sync...",
            .rsyncSyncTitle: "Rsync Synchronization",
            .rsyncSource: "Source",
            .rsyncDestination: "Destination",
            .rsyncMode: "Mode",
            .rsyncModeUpdate: "Update (Skip newer files)",
            .rsyncModeMirror: "Mirror (Delete extras)",
            .rsyncModeCopyAll: "Copy All (Overwrite existing)",
            .rsyncModeCustom: "Custom",
            .rsyncPreserveAttributes: "Preserve Attributes",
            .rsyncDeleteExtras: "Delete Extras",
            .rsyncExcludePatterns: "Exclude Patterns (comma-separated)",
            .rsyncCustomFlags: "Custom Flags",
            .rsyncCommandPreview: "Command Preview",
            .rsyncContinue: "Continue to Preview",
            .rsyncPreview: "Preview",
            .rsyncRun: "Run Sync",
            .rsyncBack: "Back",
            .rsyncProgress: "Progress",
            .rsyncComplete: "Complete",
            .rsyncCopied: "Copied",
            .rsyncUpdated: "Updated",
            .rsyncDeleted: "Deleted",
            .rsyncSkipped: "Skipped",
            .rsyncErrors: "Errors",
            .rsyncSummary: "Summary",
            
            // Rsync Errors
            .rsyncErrorSourceNotFound: "Source path not found",
            .rsyncErrorSourceNotDirectory: "Source path is not a directory",
            .rsyncErrorDestinationNotFound: "Destination path not found",
            .rsyncErrorDestinationNotDirectory: "Destination path is not a directory",
            .rsyncErrorSameSourceDestination: "Source and destination cannot be the same",
            .rsyncErrorExecutionFailed: "Rsync execution failed",
            .rsyncErrorInvalidPath: "Invalid path",
            .rsyncErrorValidation: "Validation failed"
        ]
    }
    
    // MARK: - Chinese Translations
    
    private func setupChinese() {
        translations[.chinese] = [
            // 通用
            .appName: "Zenith Commander",
            .ok: "确定",
            .cancel: "取消",
            .confirm: "确认",
            .delete: "删除",
            .save: "保存",
            .close: "关闭",
            .reset: "重置",
            .done: "完成",
            .error: "错误",
            .success: "成功",
            .warning: "警告",
            .loading: "加载中...",
            .yes: "是",
            .no: "否",
            
            // 模式名称
            .modeNormal: "普通",
            .modeVisual: "选择",
            .modeCommand: "命令",
            .modeFilter: "过滤",
            .modeDrives: "驱动器",
            .modeAI: "AI",
            .modeRename: "重命名",
            .modeSettings: "设置",
            .modeHelp: "帮助",
            
            // 设置页面
            .settings: "设置",
            .settingsAppearance: "外观",
            .settingsTheme: "主题",
            .settingsThemeLight: "浅色",
            .settingsThemeDark: "深色",
            .settingsThemeAuto: "跟随系统",
            .settingsFontSize: "字体大小",
            .settingsLineHeight: "行高",
            .settingsTerminal: "终端",
            .settingsDefaultTerminal: "默认终端",
            .settingsInstalled: "已安装",
            .settingsNotInstalled: "未安装",
            .settingsResetToDefaults: "恢复默认设置",
            .settingsResetConfirmTitle: "重置设置",
            .settingsResetConfirmMessage: "确定要将所有设置恢复为默认值吗？",
            .settingsLanguage: "语言",
            .settingsLanguageDescription: "选择界面显示语言",
            .settingsRestartRequired: "需要重启应用以使菜单语言生效",
            .settingsRestartTitle: "需要重启",
            .settingsRestartMessage: "需要重启应用才能使系统菜单的语言更改完全生效。",
            .settingsRestartNow: "立即重启",
            .settingsRestartLater: "稍后重启",
            
            // Git 设置
            .settingsGit: "Git 集成",
            .settingsGitEnabled: "启用 Git 集成",
            .settingsGitEnabledDescription: "为文件和文件夹显示 Git 状态指示器",
            .settingsGitInstalled: "Git 已安装",
            .settingsGitNotInstalled: "Git 未安装",
            .settingsGitShowUntracked: "显示未跟踪文件",
            .settingsGitShowUntrackedDescription: "显示未被 Git 跟踪的文件状态",
            .settingsGitShowIgnored: "显示被忽略文件",
            .settingsGitShowIgnoredDescription: "显示在 .gitignore 中的文件状态",
            
            // Rsync Settings
            .settingsRsync: "Rsync 集成",
            .settingsRsyncEnabled: "启用 Rsync 集成",
            .settingsRsyncEnabledDescription: "启用 Rsync 相关功能（右键菜单、快捷键）",
            .settingsRsyncInstalled: "Rsync 已安装",
            .settingsRsyncNotInstalled: "Rsync 未安装",
            
            // Git 状态显示
            .gitStatusModified: "已修改",
            .gitStatusAdded: "已添加",
            .gitStatusDeleted: "已删除",
            .gitStatusRenamed: "已重命名",
            .gitStatusUntracked: "未跟踪",
            .gitStatusConflict: "冲突",
            .gitBranch: "分支",
            .gitAhead: "领先",
            .gitBehind: "落后",
            
            // Git History
            .gitHistory: "Git 历史",
            .gitCommits: "次提交",
            .gitLoadingHistory: "加载历史记录...",
            .gitNoHistory: "此文件没有 Git 历史记录",
            .gitShowHistory: "显示 Git 历史",
            .gitRepoHistory: "仓库历史",
            .gitCommitDetails: "提交详情",
            .gitChangedFiles: "变更文件",
            .gitViewDiff: "查看差异",
            .gitCommitHash: "提交哈希",
            .gitCommitAuthor: "作者",
            .gitCommitDate: "日期",
            .gitCommitMessage: "提交信息",
            .gitCommitParent: "父提交",
            .gitShowDetails: "显示详情",
            .gitCopyHash: "复制哈希",
            
            // 帮助页面
            .help: "帮助",
            .helpKeyboardShortcuts: "键盘快捷键",
            .helpNavigation: "导航",
            .helpModeSwitching: "模式切换",
            .helpFileOperations: "文件操作",
            .helpTabs: "标签页",
            .helpBookmarks: "书签",
            .helpSettingsTheme: "设置与主题",
            .helpVisualMode: "选择模式",
            .helpCommandMode: "命令模式",
            .helpPressToClose: "按 ESC 或 ? 关闭",
            
            // 导航
            .moveCursorUp: "向上移动光标",
            .moveCursorDown: "向下移动光标",
            .goToParent: "返回上级目录",
            .enterDirectory: "进入目录",
            .jumpToFirst: "跳转到第一项",
            .jumpToLast: "跳转到最后一项",
            .switchPanes: "切换面板",
            .openFile: "打开文件/进入目录",
            
            // 模式切换
            .enterVisualMode: "进入选择模式（多选）",
            .enterCommandMode: "进入命令模式",
            .enterFilterMode: "进入过滤模式",
            .openDriveSelector: "打开驱动器选择器",
            .openHelp: "打开帮助",
            .exitMode: "退出当前模式 / 取消",
            
            // 文件操作
            .copyFiles: "复制选中的文件",
            .pasteFiles: "粘贴文件",
            .refreshDirectory: "刷新当前目录",
            .batchRename: "批量重命名选中的文件",
            .createDirectory: "创建目录",
            .createFile: "创建文件",
            .moveFile: "移动选中项到目标位置",
            .copyFile: "复制选中项到目标位置",
            .deleteFile: "删除选中的文件",
            .changeDirectory: "切换目录",
            .openSelected: "打开选中的文件",
            .openTerminal: "在此处打开终端",
            .quitApp: "退出应用",
            
            // 标签页
            .newTab: "新建标签页",
            .closeTab: "关闭当前标签页",
            .previousTab: "上一个标签页",
            .nextTab: "下一个标签页",
            
            // 书签
            .toggleBookmarkBar: "显示/隐藏书签栏",
            .addToBookmarks: "添加到书签",
            
            // 主题
            .openSettings: "打开设置",
            .cycleTheme: "切换主题（浅色/深色/自动）",
            
            // Visual 模式
            .extendSelection: "扩展选择",
            .selectAll: "全选",
            .batchRenameSelected: "批量重命名选中的文件",
            .exitVisualMode: "退出选择模式",
            
            // 文件列表
            .name: "名称",
            .size: "大小",
            .dateModified: "修改日期",
            .kind: "类型",
            .noFiles: "无文件",
            .items: "项",
            .selected: "已选择",
            
            // 状态栏
            .freeSpace: "可用",
            .totalSpace: "总共",
            
            // 批量重命名
            .batchRenameTitle: "批量重命名",
            .batchRenamePattern: "模式",
            .batchRenamePreview: "预览",
            .batchRenameApply: "应用",
            .batchRenameVariables: "变量",
            
            // AI 分析
            .aiAnalyzing: "分析中...",
            .aiAnalysisResult: "分析结果",
            .aiAnalysisError: "分析失败",
            
            // 权限
            .permissionRequired: "需要权限",
            .permissionDescription: "Zenith Commander 需要访问您的文件",
            .permissionGrant: "授予权限",
            
            // Toast 消息
            .toastCopied: "已复制到剪贴板",
            .toastPasted: "粘贴成功",
            .toastDeleted: "删除成功",
            .toastCreated: "创建成功",
            .toastMoved: "移动成功",
            .toastRenamed: "重命名成功",
            .toastBookmarkAdded: "已添加书签",
            .toastBookmarkRemoved: "已移除书签",
            
            // 错误消息
            .errorFileNotFound: "文件未找到",
            .errorPermissionDenied: "权限被拒绝",
            .errorOperationFailed: "操作失败",
            .errorInvalidPath: "无效路径",
            .errorDirectoryNotEmpty: "目录不为空",
            
            // Context Menu
            .contextOpen: "打开",
            .contextOpenInTerminal: "在终端中打开",
            .contextRemoveFromBookmarks: "从书签中移除",
            .contextAddToBookmarks: "添加到书签 (⌘B)",
            .contextCopyYank: "复制 (y)",
            .contextPaste: "粘贴 (p)",
            .contextShowInFinder: "在访达中显示",
            .contextCopyFullPath: "复制完整路径",
            .contextRename: "重命名",
            .contextMoveToTrash: "移到废纸篓",
            .contextRefresh: "刷新 (R)",
            .contextNewFile: "新建文件",
            .contextNewFolder: "新建文件夹",
            
            // Bookmark Bar
            .bookmarkBarEmpty: "无书签 - 右键文件添加",
            .bookmarkBarEditDone: "完成编辑",
            .bookmarkBarEdit: "编辑书签",
            
            // Toast Messages (Detailed)
            .toastBookmarkBarShown: "已显示书签栏",
            .toastBookmarkBarHidden: "已隐藏书签栏",
            .toastAlreadyBookmarked: "已收藏",
            .toastBookmarksAdded: "已添加 %d 个书签",
            .toastTheme: "主题：%@",
            .toastSwitchedToDrive: "已切换到 %@",
            .toastFailedToCreateDirectory: "创建目录失败：%@",
            .toastFailedToCreateFile: "创建文件失败：%@",
            .toastMoveFailed: "移动失败：%@",
            .toastCopyFailed: "复制失败：%@",
            .toastDeleteFailed: "删除失败：%@",
            .toastNoFileSelected: "未选择文件",
            .toastUnknownCommand: "未知命令：%@",
            .toastNoFilesForRename: "没有选择要重命名的文件",
            .toastFindTextEmpty: "查找文本不能为空",
            .toastFilesRenamed: "%d 个文件重命名成功",
            .toastFileRenamed: "已将 '%@' 重命名为 '%@'",
            .toastRenamedWithErrors: "%d 个成功，%d 个失败",
            .toastRenameError: "重命名失败：%@",
            .toastCannotDeleteParent: "无法删除上级目录",
            .toastNoFilesToDelete: "没有要删除的文件",
            .toastFilesMovedToTrash: "%d 个文件已移到废纸篓",
            .toastTargetNotFolder: "目标不是文件夹",
            .toastCannotMoveToSame: "无法移动到相同位置",
            .toastItemsMoved: "已移动 %d 个项目",
            .toastItemsCopied: "已复制 %d 个项目",
            .toastPathCopied: "已复制路径：%@",
            .toastRefreshed: "已刷新",
            .toastDirectoryNotFound: "目录未找到：%@",
            .toastCreatedFile: "已创建文件：%@",
            .toastCreatedFolder: "已创建文件夹：%@",
            .toastErrorCreatingFile: "创建文件出错：%@",
            .toastErrorCreatingFolder: "创建文件夹出错：%@",
            .toastFilesYanked: "已复制 %d 个文件",
            .toastNoFilesToYank: "没有可复制的文件",
            .toastFilesCut: "已剪切 %d 个文件",
            .toastNavigatedTo: "已导航到 %@",
            .toastOpening: "正在打开 %@...",
            .toastCannotCopyParent: "无法复制上级目录",
            .toastSelectFileForGitHistory: "选择一个文件查看 Git 历史",
            .toastNewTabCreated: "已创建新标签页",
            .toastRsyncDisabled: "Rsync 集成已在设置中禁用",
            
            // 菜单栏
            .menuNavigation: "导航",
            .menuView: "视图",
            .menuHelp: "帮助",
            .menuAbout: "关于 Zenith Commander",
            .menuShowHelp: "Zenith Commander 帮助",
            .menuSettings: "设置...",
            .menuEdit: "编辑",
            .menuCut: "剪切",
            .menuCopy: "拷贝",
            .menuPaste: "粘贴",
            .menuSelectAll: "全选",
            .menuUndo: "撤销",
            .menuRedo: "重做",
            .menuHide: "隐藏 Zenith Commander",
            .menuHideOthers: "隐藏其他",
            .menuShowAll: "显示全部",
            .menuQuit: "退出 Zenith Commander",
            
            // Rsync 同步
            .rsyncSync: "Rsync 同步...",
            .rsyncSyncTitle: "Rsync 同步",
            .rsyncSource: "源目录",
            .rsyncDestination: "目标目录",
            .rsyncMode: "模式",
            .rsyncModeUpdate: "更新（跳过较新文件）",
            .rsyncModeMirror: "镜像（删除多余文件）",
            .rsyncModeCopyAll: "全部复制（覆盖现有文件）",
            .rsyncModeCustom: "自定义",
            .rsyncPreserveAttributes: "保留属性",
            .rsyncDeleteExtras: "删除多余文件",
            .rsyncExcludePatterns: "排除模式（逗号分隔）",
            .rsyncCustomFlags: "自定义参数",
            .rsyncCommandPreview: "命令预览",
            .rsyncContinue: "继续预览",
            .rsyncPreview: "预览",
            .rsyncRun: "执行同步",
            .rsyncBack: "返回",
            .rsyncProgress: "进度",
            .rsyncComplete: "完成",
            .rsyncCopied: "已复制",
            .rsyncUpdated: "已更新",
            .rsyncDeleted: "已删除",
            .rsyncSkipped: "已跳过",
            .rsyncErrors: "错误",
            .rsyncSummary: "摘要",
            
            // Rsync 错误
            .rsyncErrorSourceNotFound: "源路径未找到",
            .rsyncErrorSourceNotDirectory: "源路径不是目录",
            .rsyncErrorDestinationNotFound: "目标路径未找到",
            .rsyncErrorDestinationNotDirectory: "目标路径不是目录",
            .rsyncErrorSameSourceDestination: "源和目标不能相同",
            .rsyncErrorExecutionFailed: "Rsync 执行失败",
            .rsyncErrorInvalidPath: "无效路径",
            .rsyncErrorValidation: "验证失败"
        ]
    }
}

// MARK: - View Extension for Localization

extension View {
    /// 获取本地化字符串
    func L(_ key: LocalizedStringKey) -> String {
        LocalizationManager.shared.localized(key)
    }
}

// MARK: - String Extension

extension String {
    /// 便捷方法：获取本地化字符串
    static func localized(_ key: LocalizedStringKey) -> String {
        LocalizationManager.shared.localized(key)
    }
}

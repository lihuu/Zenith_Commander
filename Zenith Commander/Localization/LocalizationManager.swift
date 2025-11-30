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
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    /// 当前语言
    @Published var currentLanguage: AppLanguage {
        didSet {
            if oldValue != currentLanguage {
                saveLanguagePreference()
                objectWillChange.send()
            }
        }
    }
    
    /// UserDefaults key
    private let languageKey = "app_language"
    
    private init() {
        // 从 UserDefaults 加载保存的语言设置
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            // 默认使用英语
            self.currentLanguage = .english
        }
    }
    
    /// 保存语言偏好
    private func saveLanguagePreference() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
    }
    
    /// 设置语言
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
    }
    
    /// 获取本地化字符串
    func localized(_ key: LocalizedStringKey) -> String {
        return LocalizedStrings.shared.get(key, for: currentLanguage)
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
    
    // MARK: - 错误消息
    case errorFileNotFound
    case errorPermissionDenied
    case errorOperationFailed
    case errorInvalidPath
    case errorDirectoryNotEmpty
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
            .goToParent: "Go to parent directory / Move left in grid",
            .enterDirectory: "Enter directory / Move right in grid",
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
            .errorDirectoryNotEmpty: "Directory is not empty"
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
            .goToParent: "返回上级目录 / 网格模式左移",
            .enterDirectory: "进入目录 / 网格模式右移",
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
            .errorDirectoryNotEmpty: "目录不为空"
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

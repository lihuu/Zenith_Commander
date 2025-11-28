//
//  ThemeManager.swift
//  Zenith Commander
//
//  主题管理器 - 管理主题切换和持久化
//

import SwiftUI
import Combine

/// 主题模式
enum ThemeMode: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"
    case auto = "Auto"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .light: return "浅色"
        case .dark: return "深色"
        case .auto: return "跟随系统"
        }
    }
    
    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .auto: return "circle.lefthalf.filled"
        }
    }
}

/// 主题颜色协议 - 定义所有主题必须实现的颜色
protocol ThemeColors {
    // MARK: - 背景色
    var background: Color { get }
    var backgroundSecondary: Color { get }
    var backgroundTertiary: Color { get }
    var backgroundElevated: Color { get }
    
    // MARK: - 边框色
    var border: Color { get }
    var borderLight: Color { get }
    var borderSubtle: Color { get }
    
    // MARK: - 文本色
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var textTertiary: Color { get }
    var textMuted: Color { get }
    
    // MARK: - 强调色
    var accent: Color { get }
    var accentSecondary: Color { get }
    var selection: Color { get }
    var selectionInactive: Color { get }
    
    // MARK: - 语义色
    var folder: Color { get }
    var file: Color { get }
    var code: Color { get }
    var image: Color { get }
    var video: Color { get }
    var audio: Color { get }
    var archive: Color { get }
    
    // MARK: - 状态色
    var success: Color { get }
    var warning: Color { get }
    var error: Color { get }
    var info: Color { get }
    
    // MARK: - 模式指示色
    var modeNormal: Color { get }
    var modeVisual: Color { get }
    var modeCommand: Color { get }
    var modeFilter: Color { get }
    var modeDrive: Color { get }
    var modeAI: Color { get }
    
    // MARK: - 窗口控制按钮
    var windowClose: Color { get }
    var windowMinimize: Color { get }
    var windowMaximize: Color { get }
    
    // MARK: - AI 渐变色
    var aiGradientStart: Color { get }
    var aiGradientEnd: Color { get }
}

/// 主题管理器
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    /// 当前主题模式
    @Published var mode: ThemeMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "themeMode")
            // 延迟更新以避免在视图更新期间发布更改
            DispatchQueue.main.async { [weak self] in
                self?.updateCurrentTheme()
            }
        }
    }
    
    /// 当前使用的主题
    @Published private(set) var current: ThemeColors
    
    /// 系统外观监听
    private var appearanceObserver: NSObjectProtocol?
    
    private init() {
        // 从 UserDefaults 读取保存的主题模式
        let savedThemeMode: ThemeMode
        if let savedMode = UserDefaults.standard.string(forKey: "themeMode"),
           let themeMode = ThemeMode(rawValue: savedMode) {
            savedThemeMode = themeMode
        } else {
            savedThemeMode = .auto
        }
        
        // 初始化当前主题 - 必须先初始化所有存储属性
        let initialTheme: ThemeColors
        switch savedThemeMode {
        case .light:
            initialTheme = LightTheme()
        case .dark:
            initialTheme = DarkTheme()
        case .auto:
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            initialTheme = isDark ? DarkTheme() : LightTheme()
        }
        
        // 设置存储属性
        self.mode = savedThemeMode
        self.current = initialTheme
        
        // 监听系统外观变化
        setupAppearanceObserver()
    }
    
    deinit {
        if let observer = appearanceObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }
    
    /// 设置系统外观变化监听
    private func setupAppearanceObserver() {
        appearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if self?.mode == .auto {
                // 延迟更新以避免在视图更新期间发布更改
                DispatchQueue.main.async {
                    self?.updateCurrentTheme()
                }
            }
        }
    }
    
    /// 更新当前主题
    private func updateCurrentTheme() {
        let newTheme: ThemeColors
        switch mode {
        case .light:
            newTheme = LightTheme()
        case .dark:
            newTheme = DarkTheme()
        case .auto:
            newTheme = isSystemDarkMode ? DarkTheme() : LightTheme()
        }
        current = newTheme
    }
    
    /// 检测系统是否为深色模式
    private var isSystemDarkMode: Bool {
        if let appearance = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) {
            return appearance == .darkAqua
        }
        return false
    }
    
    /// 切换到下一个主题模式
    func cycleTheme() {
        let allModes = ThemeMode.allCases
        if let currentIndex = allModes.firstIndex(of: mode) {
            let nextIndex = (currentIndex + 1) % allModes.count
            mode = allModes[nextIndex]
        }
    }
}

// MARK: - 深色主题
struct DarkTheme: ThemeColors {
    // MARK: - 背景色
    let background = Color(hex: "#1e1e1e")
    let backgroundSecondary = Color(hex: "#252526")
    let backgroundTertiary = Color(hex: "#2d2d2d")
    let backgroundElevated = Color(hex: "#333333")
    
    // MARK: - 边框色
    let border = Color(hex: "#1e1e1e")
    let borderLight = Color(hex: "#333333")
    let borderSubtle = Color(hex: "#404040")
    
    // MARK: - 文本色
    let textPrimary = Color(hex: "#e0e0e0")
    let textSecondary = Color(hex: "#a0a0a0")
    let textTertiary = Color(hex: "#6e6e6e")
    let textMuted = Color(hex: "#505050")
    
    // MARK: - 强调色
    let accent = Color(hex: "#4fc3f7")
    let accentSecondary = Color(hex: "#81c784")
    let selection = Color(hex: "#264f78")
    let selectionInactive = Color(hex: "#3a3a3a")
    
    // MARK: - 语义色
    let folder = Color(hex: "#90caf9")
    let file = Color(hex: "#9e9e9e")
    let code = Color(hex: "#4fc3f7")
    let image = Color(hex: "#ce93d8")
    let video = Color(hex: "#f48fb1")
    let audio = Color(hex: "#ffb74d")
    let archive = Color(hex: "#a5d6a7")
    
    // MARK: - 状态色
    let success = Color(hex: "#4caf50")
    let warning = Color(hex: "#ff9800")
    let error = Color(hex: "#f44336")
    let info = Color(hex: "#2196f3")
    
    // MARK: - 模式指示色
    let modeNormal = Color(hex: "#6e6e6e")
    let modeVisual = Color(hex: "#ff9800")
    let modeCommand = Color(hex: "#2196f3")
    let modeFilter = Color(hex: "#4caf50")
    let modeDrive = Color(hex: "#9c27b0")
    let modeAI = Color(hex: "#e91e63")
    
    // MARK: - 窗口控制按钮
    let windowClose = Color(hex: "#FF5F57")
    let windowMinimize = Color(hex: "#FFBD2E")
    let windowMaximize = Color(hex: "#28C840")
    
    // MARK: - AI 渐变色
    let aiGradientStart = Color(hex: "#880e4f")
    let aiGradientEnd = Color(hex: "#4a148c")
}

// MARK: - 浅色主题
struct LightTheme: ThemeColors {
    // MARK: - 背景色
    let background = Color(hex: "#ffffff")
    let backgroundSecondary = Color(hex: "#f5f5f5")
    let backgroundTertiary = Color(hex: "#eeeeee")
    let backgroundElevated = Color(hex: "#ffffff")
    
    // MARK: - 边框色
    let border = Color(hex: "#e0e0e0")
    let borderLight = Color(hex: "#eeeeee")
    let borderSubtle = Color(hex: "#d0d0d0")
    
    // MARK: - 文本色
    let textPrimary = Color(hex: "#212121")
    let textSecondary = Color(hex: "#616161")
    let textTertiary = Color(hex: "#9e9e9e")
    let textMuted = Color(hex: "#bdbdbd")
    
    // MARK: - 强调色
    let accent = Color(hex: "#1976d2")
    let accentSecondary = Color(hex: "#388e3c")
    let selection = Color(hex: "#bbdefb")
    let selectionInactive = Color(hex: "#e0e0e0")
    
    // MARK: - 语义色
    let folder = Color(hex: "#1976d2")
    let file = Color(hex: "#757575")
    let code = Color(hex: "#0277bd")
    let image = Color(hex: "#7b1fa2")
    let video = Color(hex: "#c2185b")
    let audio = Color(hex: "#f57c00")
    let archive = Color(hex: "#388e3c")
    
    // MARK: - 状态色
    let success = Color(hex: "#2e7d32")
    let warning = Color(hex: "#f57c00")
    let error = Color(hex: "#c62828")
    let info = Color(hex: "#1565c0")
    
    // MARK: - 模式指示色
    let modeNormal = Color(hex: "#9e9e9e")
    let modeVisual = Color(hex: "#f57c00")
    let modeCommand = Color(hex: "#1565c0")
    let modeFilter = Color(hex: "#2e7d32")
    let modeDrive = Color(hex: "#7b1fa2")
    let modeAI = Color(hex: "#c2185b")
    
    // MARK: - 窗口控制按钮
    let windowClose = Color(hex: "#FF5F57")
    let windowMinimize = Color(hex: "#FFBD2E")
    let windowMaximize = Color(hex: "#28C840")
    
    // MARK: - AI 渐变色
    let aiGradientStart = Color(hex: "#f8bbd9")
    let aiGradientEnd = Color(hex: "#e1bee7")
}

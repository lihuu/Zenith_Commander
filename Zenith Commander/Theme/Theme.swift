//
//  Theme.swift
//  Zenith Commander
//
//  主题配色定义 - 动态主题支持
//

import SwiftUI

/// 应用主题 - 便捷访问当前主题颜色
enum Theme {
    /// 获取当前主题
    private static var current: ThemeColors {
        ThemeManager.shared.current
    }
    
    // MARK: - 背景色
    static var background: Color { current.background }
    static var backgroundSecondary: Color { current.backgroundSecondary }
    static var backgroundTertiary: Color { current.backgroundTertiary }
    static var backgroundElevated: Color { current.backgroundElevated }
    
    // MARK: - 边框色
    static var border: Color { current.border }
    static var borderLight: Color { current.borderLight }
    static var borderSubtle: Color { current.borderSubtle }
    
    // MARK: - 文本色
    static var textPrimary: Color { current.textPrimary }
    static var textSecondary: Color { current.textSecondary }
    static var textTertiary: Color { current.textTertiary }
    static var textMuted: Color { current.textMuted }
    
    // MARK: - 强调色
    static var accent: Color { current.accent }
    static var accentSecondary: Color { current.accentSecondary }
    static var selection: Color { current.selection }
    static var selectionInactive: Color { current.selectionInactive }
    
    // MARK: - 语义色
    static var folder: Color { current.folder }
    static var file: Color { current.file }
    static var code: Color { current.code }
    static var image: Color { current.image }
    static var video: Color { current.video }
    static var audio: Color { current.audio }
    static var archive: Color { current.archive }
    
    // MARK: - 状态色
    static var success: Color { current.success }
    static var warning: Color { current.warning }
    static var error: Color { current.error }
    static var info: Color { current.info }
    
    // MARK: - 模式指示色
    static var modeNormal: Color { current.modeNormal }
    static var modeVisual: Color { current.modeVisual }
    static var modeCommand: Color { current.modeCommand }
    static var modeFilter: Color { current.modeFilter }
    static var modeDrive: Color { current.modeDrive }
    static var modeAI: Color { current.modeAI }
    
    // MARK: - 窗口控制按钮
    static var windowClose: Color { current.windowClose }
    static var windowMinimize: Color { current.windowMinimize }
    static var windowMaximize: Color { current.windowMaximize }
    
    // MARK: - AI 渐变色
    static var aiGradientStart: Color { current.aiGradientStart }
    static var aiGradientEnd: Color { current.aiGradientEnd }
}

// MARK: - Color Hex 扩展
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

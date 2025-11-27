//
//  Theme.swift
//  Zenith Commander
//
//  主题配色定义 - 暗色主题，参考 VS Code / Neovim
//

import SwiftUI

/// 应用主题
enum Theme {
    // MARK: - 背景色
    static let background = Color(hex: "#1e1e1e")
    static let backgroundSecondary = Color(hex: "#252526")
    static let backgroundTertiary = Color(hex: "#2d2d2d")
    static let backgroundElevated = Color(hex: "#333333")
    
    // MARK: - 边框色
    static let border = Color(hex: "#1e1e1e")
    static let borderLight = Color(hex: "#333333")
    static let borderSubtle = Color(hex: "#404040")
    
    // MARK: - 文本色
    static let textPrimary = Color(hex: "#e0e0e0")
    static let textSecondary = Color(hex: "#a0a0a0")
    static let textTertiary = Color(hex: "#6e6e6e")
    static let textMuted = Color(hex: "#505050")
    
    // MARK: - 强调色
    static let accent = Color(hex: "#4fc3f7")       // 蓝色强调
    static let accentSecondary = Color(hex: "#81c784") // 绿色
    static let selection = Color(hex: "#264f78")    // 选中背景
    static let selectionInactive = Color(hex: "#3a3a3a")
    
    // MARK: - 语义色
    static let folder = Color(hex: "#90caf9")       // 文件夹蓝色
    static let file = Color(hex: "#9e9e9e")         // 文件灰色
    static let code = Color(hex: "#4fc3f7")         // 代码文件
    static let image = Color(hex: "#ce93d8")        // 图片紫色
    static let video = Color(hex: "#f48fb1")        // 视频粉色
    static let audio = Color(hex: "#ffb74d")        // 音频橙色
    static let archive = Color(hex: "#a5d6a7")      // 压缩包绿色
    
    // MARK: - 状态色
    static let success = Color(hex: "#4caf50")
    static let warning = Color(hex: "#ff9800")
    static let error = Color(hex: "#f44336")
    static let info = Color(hex: "#2196f3")
    
    // MARK: - 模式指示色
    static let modeNormal = Color(hex: "#6e6e6e")
    static let modeVisual = Color(hex: "#ff9800")
    static let modeCommand = Color(hex: "#2196f3")
    static let modeFilter = Color(hex: "#4caf50")
    static let modeDrive = Color(hex: "#9c27b0")
    static let modeAI = Color(hex: "#e91e63")
    
    // MARK: - 窗口控制按钮
    static let windowClose = Color(hex: "#FF5F57")
    static let windowMinimize = Color(hex: "#FFBD2E")
    static let windowMaximize = Color(hex: "#28C840")
    
    // MARK: - AI 渐变色
    static let aiGradientStart = Color(hex: "#880e4f")
    static let aiGradientEnd = Color(hex: "#4a148c")
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

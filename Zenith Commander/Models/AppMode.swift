//
//  AppMode.swift
//  Zenith Commander
//
//  应用模式定义
//

import SwiftUI

/// Vim 风格的模态枚举
enum AppMode: String, CaseIterable {
    case normal = "NORMAL"
    case visual = "VISUAL"
    case command = "COMMAND"
    case filter = "FILTER"
    case driveSelect = "DRIVES"
    case aiAnalysis = "AI"
    
    /// 模式显示颜色
    var color: Color {
        switch self {
        case .normal:
            return .gray
        case .visual:
            return .orange
        case .command:
            return .blue
        case .filter:
            return .green
        case .driveSelect:
            return .purple
        case .aiAnalysis:
            return .pink
        }
    }
    
    /// 模式背景色
    var backgroundColor: Color {
        color.opacity(0.15)
    }
}

/// 面板侧边枚举
enum PaneSide: String, CaseIterable {
    case left
    case right
    
    var opposite: PaneSide {
        self == .left ? .right : .left
    }
}

/// 视图模式
enum ViewMode: String, CaseIterable {
    case list
    case grid
}

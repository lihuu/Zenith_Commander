//
//  StatusBarView.swift
//  Zenith Commander
//
//  底部状态栏
//

import SwiftUI

struct StatusBarView: View {
    let mode: AppMode
    let statusText: String
    let itemCount: Int
    let selectedCount: Int
    
    var body: some View {
        HStack(spacing: 8) {
            // 模式指示器
            ModeIndicator(mode: mode)
            
            // 状态文本
            Text(statusText)
                .accessibilityIdentifier("status_text")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
            
            Spacer()
            
            // 选中计数
            if selectedCount > 0 {
                Text("\(selectedCount) selected")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.accent.opacity(0.15))
                    .cornerRadius(3)
            }
            
            // 项目计数
            Text("\(itemCount) items")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.textTertiary)
            
            // 快捷键提示
            Text(keyHint)
                .font(.system(size: 10))
                .foregroundColor(Theme.textMuted)
        }
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(Theme.backgroundSecondary)
    }
    
    private var keyHint: String {
        switch mode {
        case .normal:
            return "? for help"
        case .visual:
            return "ESC to exit"
        case .command:
            return "Enter to execute"
        case .filter:
            return "Enter to confirm"
        case .driveSelect:
            return "j/k to navigate"
        case .aiAnalysis:
            return "ESC to close"
        }
    }
}

struct ModeIndicator: View {
    let mode: AppMode
    
    var body: some View {
        Text(mode.rawValue)
            .accessibilityIdentifier("mode_indicator")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(mode.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(mode.backgroundColor)
            .cornerRadius(3)
    }
}

#Preview {
    VStack(spacing: 0) {
        StatusBarView(
            mode: .normal,
            statusText: "Macintosh HD | Documents",
            itemCount: 42,
            selectedCount: 0
        )
        
        StatusBarView(
            mode: .visual,
            statusText: "3 files selected",
            itemCount: 42,
            selectedCount: 3
        )
        
        StatusBarView(
            mode: .command,
            statusText: ":ai summarize this folder",
            itemCount: 42,
            selectedCount: 0
        )
    }
    .background(Theme.background)
}

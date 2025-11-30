//
//  HelpView.swift
//  Zenith Commander
//
//  帮助视图 - 显示快捷键信息
//

import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HelpTitleBar(onClose: { dismiss() })
            
            // 内容区域
            ScrollView {
                VStack(spacing: 20) {
                    // Normal 模式快捷键
                    HelpSection(title: "Navigation", icon: "arrow.up.arrow.down") {
                        HelpRow(keys: ["↑", "k"], description: "Move cursor up")
                        HelpRow(keys: ["↓", "j"], description: "Move cursor down")
                        HelpRow(keys: ["←", "h"], description: "Go to parent directory / Move left in grid")
                        HelpRow(keys: ["→", "l"], description: "Enter directory / Move right in grid")
                        HelpRow(keys: ["g"], description: "Jump to first item")
                        HelpRow(keys: ["G"], description: "Jump to last item")
                        HelpRow(keys: ["Tab"], description: "Switch between panes")
                        HelpRow(keys: ["Return"], description: "Open file/Enter directory")
                    }
                    
                    HelpSection(title: "Mode Switching", icon: "switch.2") {
                        HelpRow(keys: ["v"], description: "Enter Visual mode (select multiple)")
                        HelpRow(keys: [":"], description: "Enter Command mode")
                        HelpRow(keys: ["/"], description: "Enter Filter mode")
                        HelpRow(keys: ["Shift+D"], description: "Open Drive selector")
                        HelpRow(keys: ["?"], description: "Open Help")
                        HelpRow(keys: ["Esc"], description: "Exit current mode / Cancel")
                    }
                    
                    HelpSection(title: "File Operations", icon: "doc.on.doc") {
                        HelpRow(keys: ["y"], description: "Copy (yank) selected files")
                        HelpRow(keys: ["p"], description: "Paste files")
                        HelpRow(keys: ["r"], description: "Refresh current directory")
                    }
                    
                    HelpSection(title: "Tabs", icon: "rectangle.stack") {
                        HelpRow(keys: ["t"], description: "New tab")
                        HelpRow(keys: ["w"], description: "Close current tab")
                        HelpRow(keys: ["Shift+H"], description: "Previous tab")
                        HelpRow(keys: ["Shift+L"], description: "Next tab")
                    }
                    
                    HelpSection(title: "Bookmarks", icon: "bookmark") {
                        HelpRow(keys: ["b"], description: "Toggle bookmark bar")
                        HelpRow(keys: ["⌘B"], description: "Add to bookmarks")
                    }
                    
                    HelpSection(title: "Settings & Theme", icon: "gearshape") {
                        HelpRow(keys: ["⌘,"], description: "Open Settings")
                        HelpRow(keys: ["Ctrl+T"], description: "Cycle theme (Light/Dark/Auto)")
                    }
                    
                    HelpSection(title: "Visual Mode", icon: "checkmark.square") {
                        HelpRow(keys: ["↑/↓/j/k"], description: "Extend selection")
//                        HelpRow(keys: ["Space"], description: "Toggle selection on current item")
                        HelpRow(keys: ["a"], description: "Select all")
                        HelpRow(keys: ["r"], description: "Batch rename selected files")
                        HelpRow(keys: ["Esc"], description: "Exit Visual mode")
                    }
                    
                    HelpSection(title: "Command Mode", icon: "terminal") {
                        HelpRow(keys: [":q"], description: "Quit application")
                        HelpRow(keys: [":cd <path>"], description: "Change directory")
                        HelpRow(keys: [":open"], description: "Open selected file")
                        HelpRow(keys: [":term"], description: "Open terminal here")
                        HelpRow(keys: [":mkdir <name>"], description: "Create directory")
                        HelpRow(keys: [":touch <name>"], description: "Create file")
                        HelpRow(keys: [":rm"], description: "Delete selected files")
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 600)
        .background(themeManager.current.background)
    }
}

// MARK: - 标题栏

struct HelpTitleBar: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let onClose: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(themeManager.current.accent)
            
            Text("Keyboard Shortcuts")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(themeManager.current.textPrimary)
            
            Spacer()
            
            Text("Press ESC or ? to close")
                .font(.system(size: 11))
                .foregroundColor(themeManager.current.textMuted)
            
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(themeManager.current.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(themeManager.current.backgroundSecondary)
    }
}

// MARK: - 帮助区域

struct HelpSection<Content: View>: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.current.accent)
                
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(themeManager.current.textPrimary)
            }
            
            // 内容
            VStack(spacing: 6) {
                content
            }
            .padding(.leading, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 帮助行

struct HelpRow: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    let keys: [String]
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            // 快捷键
            HStack(spacing: 4) {
                ForEach(keys.indices, id: \.self) { index in
                    if index > 0 {
                        Text("/")
                            .font(.system(size: 10))
                            .foregroundColor(themeManager.current.textMuted)
                    }
                    KeyBadge(key: keys[index])
                }
            }
            .frame(minWidth: 120, alignment: .leading)
            
            // 描述
            Text(description)
                .font(.system(size: 12))
                .foregroundColor(themeManager.current.textSecondary)
            
            Spacer()
        }
    }
}

// MARK: - 按键徽章

struct KeyBadge: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    let key: String
    
    var body: some View {
        Text(key)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(themeManager.current.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(themeManager.current.backgroundTertiary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(themeManager.current.borderSubtle, lineWidth: 1)
            )
    }
}

#Preview {
    HelpView()
}

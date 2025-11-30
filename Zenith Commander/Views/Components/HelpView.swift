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
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HelpTitleBar(onClose: { dismiss() })
            
            // 内容区域
            ScrollView {
                VStack(spacing: 20) {
                    // Normal 模式快捷键
                    HelpSection(title: L(.helpNavigation), icon: "arrow.up.arrow.down") {
                        HelpRow(keys: ["↑", "k"], description: L(.moveCursorUp))
                        HelpRow(keys: ["↓", "j"], description: L(.moveCursorDown))
                        HelpRow(keys: ["←", "h"], description: L(.goToParent))
                        HelpRow(keys: ["→", "l"], description: L(.enterDirectory))
                        HelpRow(keys: ["g"], description: L(.jumpToFirst))
                        HelpRow(keys: ["G"], description: L(.jumpToLast))
                        HelpRow(keys: ["Tab"], description: L(.switchPanes))
                        HelpRow(keys: ["Return"], description: L(.openFile))
                    }
                    
                    HelpSection(title: L(.helpModeSwitching), icon: "switch.2") {
                        HelpRow(keys: ["v"], description: L(.enterVisualMode))
                        HelpRow(keys: [":"], description: L(.enterCommandMode))
                        HelpRow(keys: ["/"], description: L(.enterFilterMode))
                        HelpRow(keys: ["Shift+D"], description: L(.openDriveSelector))
                        HelpRow(keys: ["?"], description: L(.openHelp))
                        HelpRow(keys: ["Esc"], description: L(.exitMode))
                    }
                    
                    HelpSection(title: L(.helpFileOperations), icon: "doc.on.doc") {
                        HelpRow(keys: ["y"], description: L(.copyFiles))
                        HelpRow(keys: ["p"], description: L(.pasteFiles))
                        HelpRow(keys: ["r"], description: L(.refreshDirectory))
                    }
                    
                    HelpSection(title: L(.helpTabs), icon: "rectangle.stack") {
                        HelpRow(keys: ["t"], description: L(.newTab))
                        HelpRow(keys: ["w"], description: L(.closeTab))
                        HelpRow(keys: ["Shift+H"], description: L(.previousTab))
                        HelpRow(keys: ["Shift+L"], description: L(.nextTab))
                    }
                    
                    HelpSection(title: L(.helpBookmarks), icon: "bookmark") {
                        HelpRow(keys: ["b"], description: L(.toggleBookmarkBar))
                        HelpRow(keys: ["⌘B"], description: L(.addToBookmarks))
                    }
                    
                    HelpSection(title: L(.helpSettingsTheme), icon: "gearshape") {
                        HelpRow(keys: ["⌘,"], description: L(.openSettings))
                        HelpRow(keys: ["Ctrl+T"], description: L(.cycleTheme))
                    }
                    
                    HelpSection(title: L(.helpVisualMode), icon: "checkmark.square") {
                        HelpRow(keys: ["↑/↓/j/k"], description: L(.extendSelection))
                        HelpRow(keys: ["a"], description: L(.selectAll))
                        HelpRow(keys: ["r"], description: L(.batchRenameSelected))
                        HelpRow(keys: ["Esc"], description: L(.exitVisualMode))
                    }
                    
                    HelpSection(title: L(.helpCommandMode), icon: "terminal") {
                        HelpRow(keys: [":q"], description: L(.quitApp))
                        HelpRow(keys: [":cd <path>"], description: L(.changeDirectory))
                        HelpRow(keys: [":open"], description: L(.openSelected))
                        HelpRow(keys: [":term"], description: L(.openTerminal))
                        HelpRow(keys: [":mkdir <name>"], description: L(.createDirectory))
                        HelpRow(keys: [":touch <name>"], description: L(.createFile))
                        HelpRow(keys: [":mv <dest>"], description: L(.moveFile))
                        HelpRow(keys: [":cp <dest>"], description: L(.copyFile))
                        HelpRow(keys: [":rm"], description: L(.deleteFile))
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 600)
        .background(themeManager.current.background)
    }
    
    private func L(_ key: LocalizedStringKey) -> String {
        localizationManager.localized(key)
    }
}

// MARK: - 标题栏

struct HelpTitleBar: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    let onClose: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(themeManager.current.accent)
            
            Text(L(.helpKeyboardShortcuts))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(themeManager.current.textPrimary)
            
            Spacer()
            
            Text(L(.helpPressToClose))
                .font(.system(size: 11))
                .foregroundColor(themeManager.current.textMuted)
            
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(themeManager.current.textTertiary)
            }
            .buttonStyle(.plain)
            .help(L(.close))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(themeManager.current.backgroundSecondary)
    }
    
    private func L(_ key: LocalizedStringKey) -> String {
        localizationManager.localized(key)
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

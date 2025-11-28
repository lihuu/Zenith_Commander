//
//  SettingsView.swift
//  Zenith Commander
//
//  设置页面视图
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            SettingsTitleBar(onClose: { dismiss() })
            
            // 设置内容
            ScrollView {
                VStack(spacing: 24) {
                    // 外观设置
                    AppearanceSection(settings: $settingsManager.settings.appearance)
                    
                    Divider()
                        .background(themeManager.current.borderLight)
                    
                    // 终端设置
                    TerminalSection(settings: $settingsManager.settings.terminal)
                    
                    Spacer(minLength: 20)
                    
                    // 重置按钮
                    ResetButton {
                        settingsManager.resetToDefaults()
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 520)
        .background(themeManager.current.background)
    }
}

// MARK: - 标题栏

struct SettingsTitleBar: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let onClose: () -> Void
    
    var body: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(themeManager.current.textPrimary)
            
            Spacer()
            
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

// MARK: - 外观设置区域

struct AppearanceSection: View {
    @Binding var settings: AppearanceSettings
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        SettingsSection(title: "Appearance", icon: "paintbrush.fill") {
            VStack(spacing: 16) {
                // 主题选择
                ThemeSelector(selectedTheme: Binding(
                    get: { settings.themeMode },
                    set: { newValue in
                        settings.themeMode = newValue
                        // 同步更新 ThemeManager - 使用异步更新避免在视图更新期间修改 @Published 属性
                        DispatchQueue.main.async {
                            switch newValue {
                            case "light": themeManager.mode = .light
                            case "dark": themeManager.mode = .dark
                            default: themeManager.mode = .auto
                            }
                        }
                    }
                ))
                
                Divider()
                    .background(themeManager.current.borderLight)
                
                // 字体大小
                FontSizeSlider(
                    value: $settings.fontSize,
                    label: "Font Size",
                    range: 10...18,
                    step: 1
                )
                
                // 行高
                FontSizeSlider(
                    value: $settings.lineHeight,
                    label: "Line Height",
                    range: 1.0...2.0,
                    step: 0.1,
                    format: "%.1f"
                )
            }
        }
    }
}

// MARK: - 主题选择器

struct ThemeSelector: View {
    @Binding var selectedTheme: String
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private let themes: [(id: String, name: String, icon: String)] = [
        ("light", "Light", "sun.max.fill"),
        ("dark", "Dark", "moon.fill"),
        ("auto", "Auto", "circle.lefthalf.filled")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Theme")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeManager.current.textSecondary)
            
            HStack(spacing: 12) {
                ForEach(themes, id: \.id) { theme in
                    ThemeButton(
                        id: theme.id,
                        name: theme.name,
                        icon: theme.icon,
                        isSelected: selectedTheme == theme.id
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTheme = theme.id
                        }
                    }
                }
            }
        }
    }
}

struct ThemeButton: View {
    let id: String
    let name: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(previewBackground)
                        .frame(width: 80, height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? themeManager.current.accent : themeManager.current.borderSubtle, lineWidth: isSelected ? 2 : 1)
                        )
                    
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(previewForeground)
                }
                
                Text(name)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? themeManager.current.accent : themeManager.current.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
    
    private var previewBackground: Color {
        switch id {
        case "light": return Color(hex: "#ffffff")
        case "dark": return Color(hex: "#1e1e1e")
        default: return themeManager.current.backgroundTertiary
        }
    }
    
    private var previewForeground: Color {
        switch id {
        case "light": return Color(hex: "#f57c00")
        case "dark": return Color(hex: "#ffd54f")
        default: return themeManager.current.accent
        }
    }
}

// MARK: - 字体大小滑块

struct FontSizeSlider: View {
    @Binding var value: Double
    let label: String
    let range: ClosedRange<Double>
    let step: Double
    var format: String = "%.0f"
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeManager.current.textSecondary)
                
                Spacer()
                
                Text(String(format: format, value))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(themeManager.current.accent)
                    .frame(width: 40, alignment: .trailing)
            }
            
            HStack(spacing: 12) {
                Text(String(format: format, range.lowerBound))
                    .font(.system(size: 10))
                    .foregroundColor(themeManager.current.textMuted)
                
                Slider(value: $value, in: range, step: step)
                    .tint(themeManager.current.accent)
                
                Text(String(format: format, range.upperBound))
                    .font(.system(size: 10))
                    .foregroundColor(themeManager.current.textMuted)
            }
        }
    }
}

// MARK: - 终端设置区域

struct TerminalSection: View {
    @Binding var settings: TerminalSettings
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        SettingsSection(title: "Terminal", icon: "terminal.fill") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Default Terminal")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeManager.current.textSecondary)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 10) {
                    ForEach(TerminalSettings.availableTerminals) { terminal in
                        TerminalOptionButton(
                            terminal: terminal,
                            isSelected: settings.defaultTerminal == terminal.id
                        ) {
                            settings.defaultTerminal = terminal.id
                        }
                    }
                }
            }
        }
    }
}

struct TerminalOptionButton: View {
    let terminal: TerminalOption
    let isSelected: Bool
    let action: () -> Void
    
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // 终端图标
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? themeManager.current.accent.opacity(0.15) : themeManager.current.backgroundTertiary)
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: terminalIcon)
                        .font(.system(size: 14))
                        .foregroundColor(isSelected ? themeManager.current.accent : themeManager.current.textSecondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(terminal.name)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? themeManager.current.textPrimary : themeManager.current.textSecondary)
                    
                    Text(terminal.isInstalled ? "Installed" : "Not Installed")
                        .font(.system(size: 9))
                        .foregroundColor(terminal.isInstalled ? themeManager.current.success : themeManager.current.textMuted)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(themeManager.current.accent)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? themeManager.current.backgroundTertiary : themeManager.current.backgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? themeManager.current.accent : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .opacity(terminal.isInstalled ? 1.0 : 0.6)
    }
    
    private var terminalIcon: String {
        switch terminal.id {
        case "terminal": return "terminal"
        case "iterm": return "rectangle.split.3x1"
        case "warp": return "bolt.horizontal"
        case "alacritty": return "a.square"
        case "kitty": return "cat"
        case "hyper": return "h.square"
        default: return "terminal"
        }
    }
}

// MARK: - 设置区域容器

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(themeManager.current.accent)
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.current.textPrimary)
            }
            
            // 内容
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.current.backgroundSecondary)
            )
        }
    }
}

// MARK: - 重置按钮

struct ResetButton: View {
    let action: () -> Void
    
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var isHovered = false
    @State private var showConfirmation = false
    
    var body: some View {
        Button(action: { showConfirmation = true }) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 12))
                
                Text("Reset to Defaults")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(themeManager.current.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? themeManager.current.backgroundTertiary : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(themeManager.current.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .alert("Reset Settings", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                action()
            }
        } message: {
            Text("Are you sure you want to reset all settings to their default values?")
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}

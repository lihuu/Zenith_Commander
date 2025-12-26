//
//  GitSettingsView.swift
//  Zenith Commander
//
//  Git 插件设置视图
//

import SwiftUI

// MARK: - Git Settings Section

struct GitSettingsSection: View {
    @Binding var settings: GitSettings
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared

    private var isGitAvailable: Bool {
        GitService.shared.isGitInstalled()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Git 可用性状态
            HStack(spacing: 8) {
                Circle()
                    .fill(isGitAvailable ? Color.green : Color.red)
                    .frame(width: 8, height: 8)

                Text(isGitAvailable ? L(.settingsGitInstalled) : L(.settingsGitNotInstalled))
                    .font(.system(size: 11))
                    .foregroundColor(themeManager.current.textSecondary)
            }

            // 启用 Git 集成
            GitToggleRow(
                title: L(.settingsGitEnabled),
                description: L(.settingsGitEnabledDescription),
                isOn: $settings.enabled,
                isDisabled: !isGitAvailable
            )

            if settings.enabled, isGitAvailable {
                Divider()
                    .background(themeManager.current.borderLight)

                // 显示未追踪文件
                GitToggleRow(
                    title: L(.settingsGitShowUntracked),
                    description: L(.settingsGitShowUntrackedDescription),
                    isOn: $settings.showUntrackedFiles,
                    isDisabled: false
                )

                // 显示被忽略文件
                GitToggleRow(
                    title: L(.settingsGitShowIgnored),
                    description: L(.settingsGitShowIgnoredDescription),
                    isOn: $settings.showIgnoredFiles,
                    isDisabled: false
                )
            }
        }
    }

    private func L(_ key: LocalizedStringKey) -> String {
        localizationManager.localized(key)
    }
}

// MARK: - Git Toggle Row

struct GitToggleRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    var isDisabled = false

    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(
                        isDisabled
                            ? themeManager.current.textMuted : themeManager.current.textPrimary)

                Text(description)
                    .font(.system(size: 10))
                    .foregroundColor(themeManager.current.textMuted)
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .scaleEffect(0.8)
                .disabled(isDisabled)
        }
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}

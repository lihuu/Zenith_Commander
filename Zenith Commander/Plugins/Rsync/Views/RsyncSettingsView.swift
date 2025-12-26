//
//  RsyncSettingsView.swift
//  Zenith Commander
//
//  Rsync 插件设置视图
//

import SwiftUI

// MARK: - Rsync Settings Section

struct RsyncSettingsSection: View {
    @Binding var settings: RsyncSettings
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared

    private var isRsyncAvailable: Bool {
        RsyncService.shared.isRsyncInstalled()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Rsync 可用性状态
            HStack(spacing: 8) {
                Circle()
                    .fill(isRsyncAvailable ? Color.green : Color.red)
                    .frame(width: 8, height: 8)

                Text(isRsyncAvailable ? L(.settingsRsyncInstalled) : L(.settingsRsyncNotInstalled))
                    .font(.system(size: 11))
                    .foregroundColor(themeManager.current.textSecondary)
            }

            // 启用 Rsync 集成
            RsyncToggleRow(
                title: L(.settingsRsyncEnabled),
                description: L(.settingsRsyncEnabledDescription),
                isOn: $settings.enabled,
                isDisabled: !isRsyncAvailable
            )
        }
    }

    private func L(_ key: LocalizedStringKey) -> String {
        localizationManager.localized(key)
    }
}

// MARK: - Rsync Toggle Row

struct RsyncToggleRow: View {
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

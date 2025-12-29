//
//  FzfSettingsSection.swift
//  Zenith Commander
//
//  Settings section for fzf plugin
//

import SwiftUI

// MARK: - Fzf Settings Section

struct FzfSettingsSection: View {
    @Binding var settings: FzfSettings
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared

    private var isFzfAvailable: Bool {
        FzfService.shared.isFzfInstalled()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Fzf 可用性状态
            HStack(spacing: 8) {
                Circle()
                    .fill(isFzfAvailable ? Color.green : Color.red)
                    .frame(width: 8, height: 8)

                Text(isFzfAvailable ? L(.settingsFzf) + " installed" : L(.fzfNotInstalled))
                    .font(.system(size: 11))
                    .foregroundColor(themeManager.current.textSecondary)
            }

            // 启用 Fzf 集成
            FzfToggleRow(
                title: L(.fzfEnabled),
                description: L(.fzfEnabledDescription),
                isOn: $settings.enabled,
                isDisabled: !isFzfAvailable
            )
        }
    }

    private func L(_ key: LocalizedStringKey) -> String {
        localizationManager.localized(key)
    }
}

// MARK: - Fzf Toggle Row

struct FzfToggleRow: View {
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

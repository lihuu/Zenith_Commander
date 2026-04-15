//
//  AISettingsSection.swift
//  Zenith Commander
//
//  Settings UI for AI tools plugin
//

import SwiftUI

struct AISettingsSection: View {
    @Binding var settings: AISettings
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AIToggleRow(
                title: L(.settingsAIEnabled),
                description: L(.settingsAIEnabledDescription),
                isOn: $settings.enabled
            )

            Divider()
                .background(themeManager.current.borderLight)

            VStack(alignment: .leading, spacing: 12) {
                ForEach($settings.tools) { $tool in
                    AIToolEditorRow(
                        tool: $tool,
                        onDelete: {
                            removeTool(id: tool.id)
                        }
                    )
                }

                Button {
                    settings.tools.append(
                        AIToolConfig.makeCustom(index: settings.tools.count + 1)
                    )
                } label: {
                    Label(L(.aiAddTool), systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
            }
            .disabled(!settings.enabled)
            .opacity(settings.enabled ? 1 : 0.6)
        }
    }

    private func removeTool(id: String) {
        settings.tools.removeAll { $0.id == id }
    }

    private func L(_ key: LocalizedStringKey) -> String {
        localizationManager.localized(key)
    }
}

private struct AIToolEditorRow: View {
    @Binding var tool: AIToolConfig
    let onDelete: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared

    private var isInstalled: Bool {
        AIService.shared.isToolInstalled(tool)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: tool.icon)
                    .foregroundColor(themeManager.current.accent)

                Text(tool.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeManager.current.textPrimary)

                Spacer()

                Circle()
                    .fill(isInstalled ? Color.green : Color.red)
                    .frame(width: 8, height: 8)

                Text(isInstalled ? L(.aiToolInstalled) : L(.aiToolNotInstalled))
                    .font(.system(size: 11))
                    .foregroundColor(themeManager.current.textSecondary)

                Toggle("", isOn: $tool.enabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .scaleEffect(0.8)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L(.aiToolName))
                        .font(.system(size: 11))
                        .foregroundColor(themeManager.current.textSecondary)

                    TextField(L(.aiToolName), text: $tool.name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L(.aiToolCommand))
                        .font(.system(size: 11))
                        .foregroundColor(themeManager.current.textSecondary)

                    TextField(L(.aiToolCommand), text: $tool.command)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .padding(12)
        .background(themeManager.current.backgroundSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(themeManager.current.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func L(_ key: LocalizedStringKey) -> String {
        localizationManager.localized(key)
    }
}

private struct AIToggleRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool

    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeManager.current.textPrimary)

                Text(description)
                    .font(.system(size: 10))
                    .foregroundColor(themeManager.current.textMuted)
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .scaleEffect(0.8)
        }
    }
}

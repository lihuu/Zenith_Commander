//
//  RsyncSyncSheetView.swift
//  Zenith Commander
//
//  Rsync 同步配置弹窗 - 完全主题适配版本
//

import SwiftUI

// Helper function to access localization
private func L(_ key: LocalizedStringKey) -> String {
    return LocalizationManager.shared.localized(key)
}

struct RsyncSyncSheetView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var localConfig: RsyncSyncConfig
    @State private var excludePatternsText: String = ""
    @State private var customFlagsText: String = ""
    
    init(config: RsyncSyncConfig) {
        _localConfig = State(initialValue: config)
        _excludePatternsText = State(initialValue: config.excludePatterns.joined(separator: ", "))
        _customFlagsText = State(initialValue: config.customFlags.joined(separator: " "))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header with Profile Badge
            headerView
            
            // MARK: - Path Visualizer
            pathVisualizerView
            
            // MARK: - Main Content Area
            if appState.rsyncUIState.isRunningSync {
                progressView
            } else if let previewResult = appState.rsyncUIState.previewResult {
                previewView(result: previewResult)
            } else if let syncResult = appState.rsyncUIState.syncResult {
                resultView(result: syncResult)
            } else {
                configView
            }
            
            // MARK: - Footer Controls
            footerView
        }
        .background(Theme.background)
        .frame(width: 700, height: 600)
        .onChange(of: localConfig) { oldValue, newValue in
            appState.updateRsyncConfig(newValue)
        }
    }
    
    // MARK: - Header View
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.accent)
                    .rotationEffect(appState.rsyncUIState.isRunningSync ? .degrees(360) : .degrees(0))
                    .animation(appState.rsyncUIState.isRunningSync ? 
                        Animation.linear(duration: 2).repeatForever(autoreverses: false) : .default, 
                        value: appState.rsyncUIState.isRunningSync)
                
                Text("Directory Synchronization (Rsync)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
            }
            
            Spacer()
            
            // Profile Badge
            HStack(spacing: 4) {
                Text("Profile:")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary)
                Text("Mirror Backup")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.info.opacity(0.2))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Theme.info.opacity(0.4), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.backgroundSecondary)
        .overlay(
            Divider()
                .foregroundColor(Theme.border),
            alignment: .bottom
        )
    }
    
    // MARK: - Path Visualizer
    
    @ViewBuilder
    private var pathVisualizerView: some View {
        HStack(spacing: 16) {
            // Source Path
            VStack(alignment: .leading, spacing: 4) {
                Text("SOURCE (ACTIVE)")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(Theme.textTertiary)
                
                Text(localConfig.source.path)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Theme.success)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Arrow
            Image(systemName: "arrow.right")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.textTertiary)
            
            // Destination Path
            VStack(alignment: .trailing, spacing: 4) {
                Text("DESTINATION")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(Theme.textTertiary)
                
                Text(localConfig.destination.path)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Theme.info)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .background(Theme.backgroundTertiary.opacity(0.5))
        .overlay(
            Divider()
                .foregroundColor(Theme.border),
            alignment: .bottom
        )
    }
    
    // MARK: - Configuration View
    
    @ViewBuilder
    private var configView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    // Left Column - Mode
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mode")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.bottom, 4)
                            .overlay(
                                Divider()
                                    .foregroundColor(Theme.border),
                                alignment: .bottom
                            )
                        
                        modeRadioButton(.mirror, "Mirror (Delete extraneous files)")
                        modeRadioButton(.update, "Update (Skip newer files)")
                        modeRadioButton(.copyAll, "Copy All (Overwrite everything)")
                        modeRadioButton(.custom, "Custom")
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Right Column - Options
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Options")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.bottom, 4)
                            .overlay(
                                Divider()
                                    .foregroundColor(Theme.border),
                                alignment: .bottom
                            )
                        
                        Toggle(isOn: $localConfig.preserveAttributes) {
                            Text("Recursive (-r)")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textPrimary)
                        }
                        .toggleStyle(.checkbox)
                        
                        Toggle(isOn: $localConfig.preserveAttributes) {
                            Text("Preserve times (-t)")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textPrimary)
                        }
                        .toggleStyle(.checkbox)
                        
                        Toggle(isOn: Binding.constant(true)) {
                            Text("Compress (-z)")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textPrimary)
                        }
                        .toggleStyle(.checkbox)
                        
                        Toggle(isOn: $localConfig.deleteExtras) {
                            Text("Force Delete (--delete)")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.error)
                        }
                        .toggleStyle(.checkbox)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Command Preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("# Generated Command Preview:")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.textTertiary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            Text("rsync")
                                .foregroundColor(Theme.warning)
                            Text(localConfig.effectiveFlags().joined(separator: " "))
                                .foregroundColor(Theme.textPrimary)
                            Text("\"\(localConfig.source.path)\"")
                                .foregroundColor(Theme.success)
                            Text("\"\(localConfig.destination.path)\"")
                                .foregroundColor(Theme.info)
                        }
                        .font(.system(size: 11, design: .monospaced))
                    }
                }
                .padding(12)
                .background(Theme.backgroundTertiary.opacity(0.8))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Theme.border, lineWidth: 1)
                )
                
                // Error Display
                if let error = appState.rsyncUIState.error {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Theme.error)
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.error)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.error.opacity(0.1))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Theme.error.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(16)
        }
        .background(Theme.background)
    }
    
    @ViewBuilder
    private func modeRadioButton(_ mode: RsyncMode, _ label: String) -> some View {
        Button(action: {
            localConfig.mode = mode
        }) {
            HStack(spacing: 8) {
                Image(systemName: localConfig.mode == mode ? "circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(localConfig.mode == mode ? Theme.accent : Theme.textTertiary)
                
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
            .background(
                localConfig.mode == mode ? 
                    Theme.backgroundTertiary.opacity(0.5) : Color.clear
            )
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Preview View
    
    @ViewBuilder
    private func previewView(result: RsyncPreviewResult) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Stats Summary
                    HStack(spacing: 12) {
                        statBadge("ADD", result.copied.count, Theme.success)
                        statBadge("UPDATE", result.updated.count, Theme.info)
                        statBadge("DELETE", result.deleted.count, Theme.error)
                        if !result.skipped.isEmpty {
                            statBadge("SKIP", result.skipped.count, Theme.warning)
                        }
                    }
                    
                    Divider()
                        .foregroundColor(Theme.border)
                        .padding(.vertical, 4)
                    
                    // File List Table
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Text("Change")
                                .frame(width: 80, alignment: .leading)
                            Text("File Path")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Size")
                                .frame(width: 80, alignment: .trailing)
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textTertiary)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(Theme.backgroundTertiary.opacity(0.3))
                        
                        Divider()
                            .foregroundColor(Theme.border)
                        
                        // Rows
                        ForEach(Array((result.copied + result.updated + result.deleted).prefix(20).enumerated()), id: \.offset) { index, item in
                            HStack {
                                // Change Type Badge
                                Text(getChangeType(item, from: result))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(getChangeColor(item, from: result))
                                    .cornerRadius(3)
                                    .frame(width: 80, alignment: .leading)
                                
                                // File Path
                                Text(item.relativePath)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(Theme.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Size
                                Text(formatFileSize(item))
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textSecondary)
                                    .frame(width: 80, alignment: .trailing)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(index % 2 == 0 ? Color.clear : Theme.backgroundTertiary.opacity(0.1))
                            
                            if index < 19 {
                                Divider()
                                    .foregroundColor(Theme.border.opacity(0.3))
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.background)
        }
    }
    
    @ViewBuilder
    private func statBadge(_ label: String, _ count: Int, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func getChangeType(_ item: RsyncItem, from result: RsyncPreviewResult) -> String {
        if result.copied.contains(where: { $0.id == item.id }) { return "ADD" }
        if result.updated.contains(where: { $0.id == item.id }) { return "UPDATE" }
        if result.deleted.contains(where: { $0.id == item.id }) { return "DELETE" }
        return "SKIP"
    }
    
    private func getChangeColor(_ item: RsyncItem, from result: RsyncPreviewResult) -> Color {
        if result.copied.contains(where: { $0.id == item.id }) { return Theme.success }
        if result.updated.contains(where: { $0.id == item.id }) { return Theme.info }
        if result.deleted.contains(where: { $0.id == item.id }) { return Theme.error }
        return Theme.warning
    }
    
    private func formatFileSize(_ item: RsyncItem) -> String {
        // Mock size formatting
        return "\(Int.random(in: 1...999)) KB"
    }
    
    // MARK: - Progress View
    
    @ViewBuilder
    private var progressView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 16) {
                if let progress = appState.rsyncUIState.syncProgress {
                    // Spinner and Text
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(Theme.accent)
                        
                        Text("Synchronizing files...")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textPrimary)
                    }
                    
                    // Progress Bar
                    VStack(spacing: 8) {
                        HStack {
                            Text("Progress")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text(String(format: "%.0f%%", progress.percentage))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.accent)
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Theme.backgroundTertiary)
                                    .frame(height: 8)
                                    .cornerRadius(4)
                                
                                Rectangle()
                                    .fill(Theme.accent)
                                    .frame(width: geometry.size.width * CGFloat(progress.percentage / 100.0), height: 8)
                                    .cornerRadius(4)
                            }
                        }
                        .frame(height: 8)
                    }
                    .frame(width: 300)
                } else {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(Theme.accent)
                    
                    Text("Initializing...")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
    
    // MARK: - Result View
    
    @ViewBuilder
    private func resultView(result: RsyncRunResult) -> some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 20) {
                // Success/Error Icon
                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(result.success ? Theme.success : Theme.error)
                
                // Status Text
                Text(result.success ? "Synchronization Complete" : "Synchronization Failed")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                
                // Summary
                if result.success {
                    Text("\(result.summary.copy + result.summary.update) files transferred")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                }
                
                // Error List
                if !result.errors.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(result.errors.prefix(3), id: \.self) { error in
                            Text(error)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Theme.error)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: 400)
                    .background(Theme.error.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
    
    // MARK: - Footer View
    
    @ViewBuilder
    private var footerView: some View {
        HStack {
            // Left Info
            if let previewResult = appState.rsyncUIState.previewResult {
                Text("\(previewResult.copied.count + previewResult.updated.count + previewResult.deleted.count) changes detected")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
            
            // Buttons
            HStack(spacing: 12) {
                // Cancel/Close Button
                Button(action: {
                    if appState.rsyncUIState.syncResult != nil {
                        appState.dismissRsyncSheet()
                    } else {
                        appState.dismissRsyncSheet()
                    }
                }) {
                    Text(appState.rsyncUIState.syncResult != nil ? "Close" : "Cancel")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                        .frame(minWidth: 80, minHeight: 32)
                }
                .buttonStyle(.borderless)
                .background(Theme.backgroundTertiary)
                .cornerRadius(4)
                
                // Back Button (Preview only)
                if appState.rsyncUIState.previewResult != nil && appState.rsyncUIState.syncResult == nil {
                    Button(action: {
                        appState.rsyncUIState.previewResult = nil
                    }) {
                        Text("Back")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                            .frame(minWidth: 80, minHeight: 32)
                    }
                    .buttonStyle(.borderless)
                    .background(Theme.backgroundTertiary)
                    .cornerRadius(4)
                }
                
                // Primary Action Button
                if appState.rsyncUIState.syncResult == nil {
                    if appState.rsyncUIState.previewResult != nil {
                        // Confirm & Sync
                        Button(action: {
                            Task {
                                await appState.runSync()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10))
                                Text("Confirm & Sync")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(minWidth: 120, minHeight: 32)
                        }
                        .buttonStyle(.borderless)
                        .background(Theme.success)
                        .cornerRadius(4)
                        .disabled(appState.rsyncUIState.isRunningSync)
                    } else if !appState.rsyncUIState.isRunningSync {
                        // Dry Run
                        Button(action: {
                            Task {
                                await appState.runPreview()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 10))
                                Text("Dry Run")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(minWidth: 100, minHeight: 32)
                        }
                        .buttonStyle(.borderless)
                        .background(Theme.backgroundTertiary.opacity(0.8))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                        .disabled(!localConfig.isValid())
                        
                        // Start Sync
                        Button(action: {
                            Task {
                                await appState.runSync()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10))
                                Text("Start Sync")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(minWidth: 100, minHeight: 32)
                        }
                        .buttonStyle(.borderless)
                        .background(Theme.accent)
                        .cornerRadius(4)
                        .disabled(!localConfig.isValid())
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.backgroundSecondary)
        .overlay(
            Divider()
                .foregroundColor(Theme.border),
            alignment: .top
        )
    }
}

// MARK: - Preview

#Preview {
    let config = RsyncSyncConfig(
        source: URL(fileURLWithPath: "/Macintosh HD/Users/Dev"),
        destination: URL(fileURLWithPath: "/Samsung T7/Backups/2024"),
        mode: .mirror,
        dryRun: true,
        preserveAttributes: true,
        deleteExtras: false,
        excludePatterns: ["*.tmp", ".DS_Store"],
        customFlags: []
    )
    
    RsyncSyncSheetView(config: config)
        .environmentObject(AppState())
}

//
//  RsyncSyncSheetView.swift
//  Zenith Commander
//
//  Rsync 同步配置弹窗
//

import SwiftUI

// Helper function to access localization (using our custom enum, not SwiftUI's LocalizedStringKey)
private typealias LocalizationKey = Zenith_Commander.LocalizedStringKey
private func L(_ key: LocalizationKey) -> String {
    return LocalizationManager.shared.localized(key)
}

struct RsyncSyncSheetView: View {
    @EnvironmentObject var appState: AppState
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
            // 标题栏
            HStack {
                Text(L(.rsyncSyncTitle))
                    .font(.headline)
                Spacer()
                Button(action: {
                    appState.dismissRsyncSheet()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // 主内容区
            if let previewResult = appState.rsyncUIState.previewResult {
                // 预览视图
                previewView(result: previewResult)
            } else if let syncResult = appState.rsyncUIState.syncResult {
                // 结果视图
                resultView(result: syncResult)
            } else {
                // 配置视图
                configView
            }
        }
        .frame(width: 600, height: 500)
        .onChange(of: localConfig) { oldValue, newValue in
            appState.updateRsyncConfig(newValue)
        }
    }
    
    // MARK: - 配置视图
    
    @ViewBuilder
    private var configView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 源和目标路径
                pathsSection
                
                Divider()
                
                // 模式选择
                modeSection
                
                Divider()
                
                // 选项
                optionsSection
                
                Divider()
                
                // 排除模式
                excludePatternsSection
                
                // 自定义参数（仅在 Custom 模式下显示）
                if localConfig.mode == .custom {
                    Divider()
                    customFlagsSection
                }
                
                // 命令预览
                Divider()
                commandPreviewSection
                
                // 错误信息
                if let error = appState.rsyncUIState.error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding()
        }
        
        Divider()
        
        // 底部按钮
        HStack {
            Button(L(.cancel)) {
                appState.dismissRsyncSheet()
            }
            .keyboardShortcut(.cancelAction)
            
            Spacer()
            
            Button(L(.rsyncContinue)) {
                Task {
                    await appState.runPreview()
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!localConfig.isValid() || appState.rsyncUIState.isPreviewingDryRun)
        }
        .padding()
    }
    
    // MARK: - 路径部分
    
    @ViewBuilder
    private var pathsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L(.rsyncSource))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(localConfig.source.path)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            HStack {
                Text(L(.rsyncDestination))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(localConfig.destination.path)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
    
    // MARK: - 模式选择部分
    
    @ViewBuilder
    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(.rsyncMode))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                modeRadioButton(.update, L(.rsyncModeUpdate))
                modeRadioButton(.mirror, L(.rsyncModeMirror))
                modeRadioButton(.copyAll, L(.rsyncModeCopyAll))
                modeRadioButton(.custom, L(.rsyncModeCustom))
            }
        }
    }
    
    @ViewBuilder
    private func modeRadioButton(_ mode: RsyncMode, _ label: String) -> some View {
        Button(action: {
            localConfig.mode = mode
        }) {
            HStack {
                Image(systemName: localConfig.mode == mode ? "largecircle.fill.circle" : "circle")
                Text(label)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .foregroundColor(localConfig.mode == mode ? .accentColor : .primary)
    }
    
    // MARK: - 选项部分
    
    @ViewBuilder
    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(L(.rsyncPreserveAttributes), isOn: $localConfig.preserveAttributes)
            Toggle(L(.rsyncDeleteExtras), isOn: $localConfig.deleteExtras)
        }
    }
    
    // MARK: - 排除模式部分
    
    @ViewBuilder
    private var excludePatternsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(.rsyncExcludePatterns))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextField("e.g., *.tmp, .DS_Store, node_modules", text: $excludePatternsText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: excludePatternsText) { oldValue, newValue in
                    localConfig.excludePatterns = newValue
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                }
        }
    }
    
    // MARK: - 自定义参数部分
    
    @ViewBuilder
    private var customFlagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(.rsyncCustomFlags))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextField("e.g., -v --progress", text: $customFlagsText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: customFlagsText) { oldValue, newValue in
                    localConfig.customFlags = newValue
                        .split(separator: " ")
                        .map { String($0) }
                        .filter { !$0.isEmpty }
                }
        }
    }
    
    // MARK: - 命令预览部分
    
    @ViewBuilder
    private var commandPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(.rsyncCommandPreview))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                Text("rsync \(localConfig.effectiveFlags().joined(separator: " ")) \"\(localConfig.source.path)/\" \"\(localConfig.destination.path)/\"")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
        }
    }
    
    // MARK: - 预览视图
    
    @ViewBuilder
    private func previewView(result: RsyncPreviewResult) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 摘要
                    Text(L(.rsyncPreview))
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        previewStat(L(.rsyncCopied), result.copied.count, .green)
                        previewStat(L(.rsyncUpdated), result.updated.count, .blue)
                        previewStat(L(.rsyncDeleted), result.deleted.count, .red)
                        previewStat(L(.rsyncSkipped), result.skipped.count, .secondary)
                    }
                    
                    Divider()
                    
                    // 分组列表
                    if !result.copied.isEmpty {
                        previewSection(L(.rsyncCopied), result.copied, .green)
                    }
                    if !result.updated.isEmpty {
                        previewSection(L(.rsyncUpdated), result.updated, .blue)
                    }
                    if !result.deleted.isEmpty {
                        previewSection(L(.rsyncDeleted), result.deleted, .red)
                    }
                    if !result.skipped.isEmpty {
                        previewSection(L(.rsyncSkipped), result.skipped, .secondary)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // 底部按钮
            HStack {
                Button(L(.rsyncBack)) {
                    appState.rsyncUIState.previewResult = nil
                }
                
                Spacer()
                
                Button(L(.rsyncRun)) {
                    Task {
                        await appState.runSync()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(appState.rsyncUIState.isRunningSync)
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func previewStat(_ label: String, _ count: Int, _ color: Color) -> some View {
        VStack {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private func previewSection(_ title: String, _ items: [RsyncItem], _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            ForEach(items) { item in
                Text(item.relativePath)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - 结果视图
    
    @ViewBuilder
    private func resultView(result: RsyncRunResult) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if result.success {
                        Label(L(.rsyncComplete), systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundColor(.green)
                    } else {
                        Label(L(.error), systemImage: "xmark.circle.fill")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                    
                    Divider()
                    
                    // 摘要
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L(.rsyncSummary))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 20) {
                            resultStat(L(.rsyncCopied), result.summary.copied, .green)
                            resultStat(L(.rsyncUpdated), result.summary.updated, .blue)
                            resultStat(L(.rsyncDeleted), result.summary.deleted, .red)
                        }
                    }
                    
                    // 错误信息
                    if !result.errors.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L(.rsyncErrors))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            ForEach(result.errors, id: \.self) { error in
                                Text(error)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .padding()
            }
            
            Divider()
            
            // 底部按钮
            HStack {
                Spacer()
                Button(L(.done)) {
                    appState.dismissRsyncSheet()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func resultStat(_ label: String, _ count: Int, _ color: Color) -> some View {
        VStack {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    let config = RsyncSyncConfig(
        source: URL(fileURLWithPath: "/Users/test/source"),
        destination: URL(fileURLWithPath: "/Users/test/destination"),
        mode: .update,
        dryRun: true,
        preserveAttributes: true,
        deleteExtras: false,
        excludePatterns: ["*.tmp", ".DS_Store"],
        customFlags: []
    )
    
    RsyncSyncSheetView(config: config)
        .environmentObject(AppState())
}

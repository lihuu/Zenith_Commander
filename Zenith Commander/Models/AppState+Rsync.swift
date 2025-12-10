//
//  AppState+Rsync.swift
//  Zenith Commander
//
//  Rsync 同步功能状态管理扩展
//

import Foundation

// Helper function to access localization
private func L(_ key: LocalizedStringKey) -> String {
    return LocalizationManager.shared.localized(key)
}

// MARK: - Rsync UI State

/// Rsync 界面状态
struct RsyncUIState {
    /// 是否显示配置弹窗
    var showConfigSheet: Bool = false
    
    /// 当前配置
    var config: RsyncSyncConfig?
    
    /// 错误信息
    var error: String?
    
    /// 预览结果
    var previewResult: RsyncPreviewResult?
    
    /// 是否正在预览
    var isPreviewingDryRun: Bool = false
    
    /// 是否正在执行同步
    var isRunningSync: Bool = false
    
    /// 同步进度
    var syncProgress: RsyncProgress?
    
    /// 同步结果
    var syncResult: RsyncRunResult?
}

// MARK: - AppState Rsync Extension

extension AppState {
    /// 打开 Rsync 配置弹窗
    /// - Parameter sourceIsLeft: 源目录是否为左侧面板（true 为左侧，false 为右侧）
    func presentRsyncSheet(sourceIsLeft: Bool) {
        let sourcePane = sourceIsLeft ? leftPane : rightPane
        let destinationPane = sourceIsLeft ? rightPane : leftPane
        
        let sourceURL = sourcePane.activeTab.currentPath
        let destinationURL = destinationPane.activeTab.currentPath
        
        let config = RsyncSyncConfig(
            source: sourceURL,
            destination: destinationURL,
            mode: .update,
            dryRun: true,
            preserveAttributes: true,
            deleteExtras: false,
            excludePatterns: [],
            customFlags: []
        )
        
        rsyncUIState.config = config
        rsyncUIState.error = nil
        rsyncUIState.previewResult = nil
        rsyncUIState.syncResult = nil
        rsyncUIState.showConfigSheet = true
    }
    
    /// 更新 Rsync 配置
    /// - Parameter config: 新的配置
    func updateRsyncConfig(_ config: RsyncSyncConfig) {
        rsyncUIState.config = config
        rsyncUIState.error = nil
        // 配置改变时清除预览结果
        rsyncUIState.previewResult = nil
    }
    
    /// 关闭 Rsync 配置弹窗
    func dismissRsyncSheet() {
        rsyncUIState.showConfigSheet = false
        rsyncUIState.config = nil
        rsyncUIState.error = nil
        rsyncUIState.previewResult = nil
        rsyncUIState.syncResult = nil
        rsyncUIState.isPreviewingDryRun = false
        rsyncUIState.isRunningSync = false
        rsyncUIState.syncProgress = nil
    }
    
    /// 运行预览（dry-run）
    func runPreview() async {
        guard let config = rsyncUIState.config else {
            rsyncUIState.error = L(.rsyncErrorValidation)
            return
        }
        
        rsyncUIState.isPreviewingDryRun = true
        rsyncUIState.error = nil
        
        do {
            let result = try await RsyncService.shared.preview(config: config)
            rsyncUIState.previewResult = result
        } catch {
            rsyncUIState.error = error.localizedDescription
        }
        
        rsyncUIState.isPreviewingDryRun = false
    }
    
    /// 执行同步
    func runSync() async {
        guard let config = rsyncUIState.config else {
            rsyncUIState.error = L(.rsyncErrorValidation)
            return
        }
        
        rsyncUIState.isRunningSync = true
        rsyncUIState.error = nil
        rsyncUIState.syncProgress = nil
        
        do {
            // 创建进度流
            let (stream, continuation) = AsyncStream<RsyncProgress>.makeStream()
            
            // 启动同步任务
            Task {
                do {
                    let result = try await RsyncService.shared.run(
                        config: config,
                        progress: stream
                    )
                    await MainActor.run {
                        rsyncUIState.syncResult = result
                        rsyncUIState.isRunningSync = false
                    }
                } catch {
                    await MainActor.run {
                        rsyncUIState.error = error.localizedDescription
                        rsyncUIState.isRunningSync = false
                    }
                }
            }
            
            // 监听进度更新
            for await progress in stream {
                rsyncUIState.syncProgress = progress
            }
            
        } catch {
            rsyncUIState.error = error.localizedDescription
            rsyncUIState.isRunningSync = false
        }
    }
}

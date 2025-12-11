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

extension AppState {
    /// 打开 Rsync 配置弹窗
    /// - Parameter sourceIsLeft: 源目录是否为左侧面板（true 为左侧，false 为右侧）
    func presentRsyncSheet(sourceIsLeft: Bool) {
        guard SettingsManager.shared.settings.rsync.enabled else {
            showToast(L(.toastRsyncDisabled))
            return
        }
        
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
        rsyncUIState.syncResult = nil
        
        // 创建进度流
        let (stream, continuation) = AsyncStream<RsyncProgress>.makeStream()
        
        // 在后台任务中执行同步
        let syncTask = Task {
            do {
                let result = try await RsyncService.shared.run(
                    config: config,
                    progressContinuation: continuation
                )
                return result
            } catch {
                throw error
            }
        }
        
        // 监听进度更新并在主线程更新 UI
        for await progress in stream {
            await MainActor.run {
                rsyncUIState.syncProgress = progress
            }
        }
        
        // 等待同步任务完成并获取最终结果
        do {
            let result = try await syncTask.value
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
}

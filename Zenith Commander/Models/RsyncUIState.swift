//
//  RsyncUIState.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/10/25.
//


import Foundation

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
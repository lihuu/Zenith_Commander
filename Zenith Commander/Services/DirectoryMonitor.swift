//
//  DirectoryMonitor.swift
//  Zenith Commander
//
//  目录变化监控服务
//  使用 DispatchSource 监控特定目录（轻量级方案）
//

import Foundation
import os.log

// MARK: - DispatchSource 目录监控器（轻量级方案）

/// 基于 DispatchSource 的目录监控器
/// 只监控指定目录本身的变化，不会收到其他目录的事件
/// 优点：轻量级、精确、只监控指定目录、资源消耗极低
class DispatchSourceDirectoryMonitor {
    
    // MARK: - Properties
    
    /// 监控的目录 URL
    private let directoryURL: URL
    
    /// 文件描述符
    private var fileDescriptor: Int32 = -1
    
    /// DispatchSource
    private var source: DispatchSourceFileSystemObject?
    
    /// 变化回调
    private var onChange: (() -> Void)?
    
    /// 目录被删除/移动/重命名时的回调
    private var onDirectoryInvalidated: (() -> Void)?
    
    /// 是否正在监控
    private(set) var isMonitoring: Bool = false
    
    /// 防抖相关
    private var debounceWorkItem: DispatchWorkItem?
    private let debounceDelay: TimeInterval = 0.3
    private let monitorQueue = DispatchQueue(label: "com.zenithcommander.directorymonitor", qos: .utility)
    
    // MARK: - Initialization
    
    /// 初始化目录监控器
    /// - Parameter url: 要监控的目录 URL
    init(url: URL) {
        self.directoryURL = url
    }
    
    /// 兼容旧 API
    init(urls: [URL]) {
        self.directoryURL = urls.first ?? URL(fileURLWithPath: "/")
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Public Methods
    
    /// 开始监控
    /// - Parameters:
    ///   - onChange: 当目录内容变化时的回调（在主线程调用）
    ///   - onDirectoryInvalidated: 当目录被删除/移动/重命名时的回调（在主线程调用），可选
    func start(onChange: @escaping () -> Void, onDirectoryInvalidated: (() -> Void)? = nil) {
        if isMonitoring {
            stop()
        }
        
        self.onChange = onChange
        self.onDirectoryInvalidated = onDirectoryInvalidated
        
        // 打开目录获取文件描述符
        fileDescriptor = open(directoryURL.path, O_EVTONLY)
        
        guard fileDescriptor >= 0 else {
            Logger.monitor.error("DirectoryMonitor: Failed to open directory: \(self.directoryURL.path, privacy: .public)")
            return
        }
        
        // 创建 DispatchSource 监控文件系统对象
        // .write 事件会在目录内容变化时触发（文件创建、删除、重命名）
        // .delete, .rename, .revoke 会在目录本身被删除/重命名/卸载时触发
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .revoke],
            queue: monitorQueue
        )
        
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            let data = source.data
            
            // 检查是否是目录本身被删除/重命名/卸载
            if data.contains(.delete) || data.contains(.rename) || data.contains(.revoke) {
                self.handleDirectoryInvalidated(event: data)
            } else if data.contains(.write) {
                // 目录内容变化，但需要验证目录是否仍然存在
                if self.isDirectoryValid() {
                    self.handleDirectoryChange()
                } else {
                    self.handleDirectoryInvalidated(event: data)
                }
            }
        }
        
        source.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }
        
        self.source = source
        source.resume()
        isMonitoring = true
        
        Logger.monitor.info("DirectoryMonitor: Started monitoring \(self.directoryURL.path, privacy: .public)")
    }
    
    /// 停止监控
    func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        
        if let source = source {
            source.cancel()
            self.source = nil
        }
        
        isMonitoring = false
        onChange = nil
        onDirectoryInvalidated = nil
        
        Logger.monitor.info("DirectoryMonitor: Stopped monitoring")
    }
    
    // MARK: - Private Methods
    
    /// 检查目录是否仍然有效（存在且是目录）
    private func isDirectoryValid() -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }
    
    /// 处理目录被删除/移动/重命名
    private func handleDirectoryInvalidated(event: DispatchSource.FileSystemEvent) {
        Logger.monitor.warning("DirectoryMonitor: Directory invalidated - \(self.directoryURL.path, privacy: .public), event: \(String(describing: event))")
        
        // 取消防抖任务
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        
        // 保存回调引用
        let callback = onDirectoryInvalidated
        
        // 停止监控并释放资源
        stop()
        
        // 在主线程通知调用方
        if let callback = callback {
            DispatchQueue.main.async {
                callback()
            }
        }
    }
    
    /// 处理目录变化（带防抖）
    private func handleDirectoryChange() {
        Logger.monitor.debug("DirectoryMonitor: Change detected in \(self.directoryURL.path, privacy: .public)")
        
        // 防抖处理 - 短时间内多次变化只触发一次回调
        debounceWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, let onChange = self.onChange else { return }
            
            Logger.monitor.info("DirectoryMonitor: Triggering refresh for \(self.directoryURL.path, privacy: .public)")
            
            DispatchQueue.main.async {
                onChange()
            }
        }
        
        debounceWorkItem = workItem
        monitorQueue.asyncAfter(deadline: .now() + debounceDelay, execute: workItem)
    }
}

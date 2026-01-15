//
//  DirectoryMonitor.swift
//  Zenith Commander
//
//  目录变化监控服务
//  使用 DispatchSource 监控特定目录（轻量级方案）
//

@preconcurrency import Foundation
import os.log

// MARK: - DispatchSource 目录监控器（轻量级方案）

/// 基于 DispatchSource 的目录监控器
/// 只监控指定目录本身的变化，不会收到其他目录的事件
/// 优点：轻量级、精确、只监控指定目录、资源消耗极低
class DispatchSourceDirectoryMonitor {
    // MARK: - Properties

    /// 监控的目录 URL
    private let directoryURL: URL

    /// 文件描述符 - nonisolated(unsafe) since all access is serialized on monitorQueue
    private nonisolated(unsafe) var fileDescriptor: Int32 = -1

    /// DispatchSource - nonisolated(unsafe) since all access is serialized on monitorQueue
    private nonisolated(unsafe) var source: DispatchSourceFileSystemObject?

    /// 变化回调 - nonisolated(unsafe) to allow deinit access
    private nonisolated(unsafe) var onChange: (@Sendable () -> Void)?

    /// 目录被删除/移动/重命名时的回调 - nonisolated(unsafe) to allow deinit access
    private nonisolated(unsafe) var onDirectoryInvalidated: (@Sendable () -> Void)?

    /// 是否正在监控 - nonisolated(unsafe) since all access is serialized on monitorQueue
    private(set) nonisolated(unsafe) var isMonitoring = false

    /// 防抖相关 - nonisolated(unsafe) to allow deinit access
    private nonisolated(unsafe) var debounceWorkItem: DispatchWorkItem?
    private let debounceDelay: TimeInterval = 0.3
    private let monitorQueue = DispatchQueue(label: "com.zenithcommander.directorymonitor", qos: .utility)

    // MARK: - Initialization

    /// 初始化目录监控器
    /// - Parameter url: 要监控的目录 URL
    init(url: URL) {
        directoryURL = url
    }

    /// 兼容旧 API
    init(urls: [URL]) {
        directoryURL = urls.first ?? URL(fileURLWithPath: "/")
    }

    deinit {
        // Inline cleanup to avoid calling potentially MainActor-isolated methods from deinit
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        source?.cancel()
        source = nil
        isMonitoring = false
        onChange = nil
        onDirectoryInvalidated = nil
    }

    // MARK: - Public Methods

    func start(onChange: @escaping @Sendable () -> Void, onDirectoryInvalidated: (@Sendable () -> Void)? = nil) {
        monitorQueue.async { [weak self] in
            guard let self else { return }
            self.startOnQueue(onChange: onChange, onDirectoryInvalidated: onDirectoryInvalidated)
        }
    }

    func stop() {
        monitorQueue.async { [weak self] in
            guard let self else { return }
            self.stopOnQueue()
        }
    }

    // MARK: - Private Methods

    /// Must be called on `monitorQueue`.
    private nonisolated func startOnQueue(onChange: @escaping @Sendable () -> Void, onDirectoryInvalidated: (@Sendable () -> Void)? = nil) {
        if isMonitoring {
            stopOnQueue()
        }

        self.onChange = onChange
        self.onDirectoryInvalidated = onDirectoryInvalidated

        // 打开目录获取文件描述符
        fileDescriptor = open(directoryURL.path, O_EVTONLY)
        let fd = fileDescriptor

        guard fd >= 0 else {
            Logger.monitor.error("DirectoryMonitor: Failed to open directory: \(self.directoryURL.path, privacy: .public)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .revoke],
            queue: monitorQueue
        )

        let eventHandler: @Sendable () -> Void = { [weak self, weak source] in
            guard let self, let source else { return }
            let data = source.data

            if data.contains(.delete) || data.contains(.rename) || data.contains(.revoke) {
                self.handleDirectoryInvalidated(event: data)
            } else if data.contains(.write) {
                if self.isDirectoryValid() {
                    self.handleDirectoryChange()
                } else {
                    self.handleDirectoryInvalidated(event: data)
                }
            }
        }

        // Cancel handler must not touch shared mutable state; just close the captured fd.
        let cancelHandler: @Sendable () -> Void = {
            if fd >= 0 {
                close(fd)
            }
        }

        source.setEventHandler(handler: eventHandler)
        source.setCancelHandler(handler: cancelHandler)

        self.source = source
        source.resume()
        isMonitoring = true

        Logger.monitor.debug("DirectoryMonitor: Started monitoring \(self.directoryURL.path, privacy: .public)")
    }

    /// Must be called on `monitorQueue`.
    private nonisolated func stopOnQueue() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil

        if let source {
            source.cancel()
            self.source = nil
        }

        isMonitoring = false
        onChange = nil
        onDirectoryInvalidated = nil

        Logger.monitor.debug("DirectoryMonitor: Stopped monitoring")
    }

    /// 检查目录是否仍然有效（存在且是目录）
    private nonisolated func isDirectoryValid() -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }

    /// 处理目录被删除/移动/重命名
    private nonisolated func handleDirectoryInvalidated(event: DispatchSource.FileSystemEvent) {
        Logger.monitor.warning("DirectoryMonitor: Directory invalidated - \(self.directoryURL.path, privacy: .public), event: \(String(describing: event))")

        // 取消防抖任务
        debounceWorkItem?.cancel()
        debounceWorkItem = nil

        // 保存回调引用
        let callback = onDirectoryInvalidated

        // 停止监控并释放资源
        stopOnQueue()

        // 在主线程通知调用方
        if let callback {
            DispatchQueue.main.async {
                callback()
            }
        }
    }

    /// 处理目录变化（带防抖）
    private nonisolated func handleDirectoryChange() {
        Logger.monitor.debug("DirectoryMonitor: Change detected in \(self.directoryURL.path, privacy: .public)")

        // 防抖处理 - 短时间内多次变化只触发一次回调
        debounceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, let onChange = self.onChange else { return }

            Logger.monitor.debug("DirectoryMonitor: Triggering refresh for \(self.directoryURL.path, privacy: .public)")

            DispatchQueue.main.async {
                onChange()
            }
        }

        debounceWorkItem = workItem
        monitorQueue.asyncAfter(deadline: .now() + debounceDelay, execute: workItem)
    }
}

// MARK: - Concurrency
// This type is used from Swift Concurrency contexts but internally serializes all mutations on `monitorQueue`.
// We mark it as @unchecked Sendable to avoid Swift 6 inferring MainActor isolation for GCD @Sendable handlers.
extension DispatchSourceDirectoryMonitor: @unchecked Sendable {}

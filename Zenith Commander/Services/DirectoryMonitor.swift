//
//  DirectoryMonitor.swift
//  Zenith Commander
//
//  目录变化监控服务
//  主要使用 FSEvents API（macOS 推荐方案），DispatchSource 作为备选
//

import Foundation
import CoreServices
import os.log

// MARK: - FSEvents 监控器（推荐方案）

/// 基于 FSEvents 的目录监控器
/// FSEvents 是 macOS 文件系统监控的标准 API，Finder 等系统应用都使用它
/// 优点：可靠、支持递归监控、系统级优化、低资源消耗
class FSEventsDirectoryMonitor {
    
    // MARK: - Properties
    
    /// 监控的目录路径
    private let paths: [String]
    
    /// FSEvents 流
    private var eventStream: FSEventStreamRef?
    
    /// 变化回调
    private var onChange: (() -> Void)?
    
    /// 是否正在监控
    private(set) var isMonitoring: Bool = false
    
    /// 防抖相关
    private var debounceWorkItem: DispatchWorkItem?
    private let debounceDelay: TimeInterval = 0.3
    private let callbackQueue = DispatchQueue(label: "com.zenithcommander.fsevents", qos: .utility)
    
    // MARK: - Initialization
    
    /// 初始化 FSEvents 监控器
    /// - Parameter url: 要监控的目录 URL
    init(url: URL) {
        self.paths = [url.path]
    }
    
    /// 初始化 FSEvents 监控器（多目录）
    /// - Parameter urls: 要监控的目录 URL 数组
    init(urls: [URL]) {
        self.paths = urls.map { $0.path }
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Public Methods
    
    /// 开始监控
    /// - Parameter onChange: 当目录内容变化时的回调（在主线程调用）
    func start(onChange: @escaping () -> Void) {
        if isMonitoring {
            stop()
        }
        
        self.onChange = onChange
        
        // 设置回调上下文
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        // 创建 FSEvents 流
        // 使用 kFSEventStreamCreateFlagUseCFTypes 获取更多事件信息
        // 使用 kFSEventStreamCreateFlagFileEvents 监控文件级别的变化
        let flags: FSEventStreamCreateFlags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer
        )
        
        guard let stream = FSEventStreamCreate(
            nil,                                    // allocator
            fsEventsCallback,                       // callback
            &context,                               // context
            paths as CFArray,                       // pathsToWatch
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),  // sinceWhen
            0.1,                                    // latency (秒) - FSEvents 内置延迟
            flags                                   // flags
        ) else {
            Logger.monitor.error("FSEventsDirectoryMonitor: Failed to create event stream")
            return
        }
        
        eventStream = stream
        
        // 将流调度到后台队列
        FSEventStreamSetDispatchQueue(stream, callbackQueue)
        
        // 启动流
        if FSEventStreamStart(stream) {
            isMonitoring = true
            Logger.monitor.debug("FSEventsDirectoryMonitor: Started monitoring: \(self.paths)")
        } else {
            Logger.monitor.error("FSEventsDirectoryMonitor: Failed to start event stream")
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }
    }
    
    /// 停止监控
    func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }
        
        isMonitoring = false
        onChange = nil
        Logger.monitor.debug("FSEventsDirectoryMonitor: Stopped monitoring")
    }
    
    // MARK: - Private Methods
    
    /// 处理 FSEvents 回调（带防抖）
    fileprivate func handleEvent() {
        debounceWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, let onChange = self.onChange else { return }
            DispatchQueue.main.async {
                onChange()
            }
        }
        
        debounceWorkItem = workItem
        callbackQueue.asyncAfter(deadline: .now() + debounceDelay, execute: workItem)
    }
}

// MARK: - FSEvents Callback

/// FSEvents 回调函数（C 函数指针）
private func fsEventsCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }
    let monitor = Unmanaged<FSEventsDirectoryMonitor>.fromOpaque(info).takeUnretainedValue()
    monitor.handleEvent()
}

// MARK: - DispatchSource 监控器（备选方案）

/// 基于 DispatchSource 的目录监控器
/// 轻量级方案，适合简单场景，但可能漏掉一些事件
class DirectoryMonitor {
    
    // MARK: - Properties
    
    /// 监控的目录 URL
    private let url: URL
    
    /// 文件描述符
    private var fileDescriptor: Int32 = -1
    
    /// DispatchSource 用于监控
    private var source: DispatchSourceFileSystemObject?
    
    /// 监控队列
    private let monitorQueue = DispatchQueue(label: "com.zenithcommander.directorymonitor", qos: .utility)
    
    /// 变化回调
    private var onChange: (() -> Void)?
    
    /// 防抖定时器
    private var debounceWorkItem: DispatchWorkItem?
    
    /// 防抖延迟（秒）
    private let debounceDelay: TimeInterval = 0.3
    
    /// 是否正在监控
    private(set) var isMonitoring: Bool = false
    
    // MARK: - Initialization
    
    /// 初始化目录监控器
    /// - Parameter url: 要监控的目录 URL
    init(url: URL) {
        self.url = url
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Public Methods
    
    /// 开始监控目录变化
    /// - Parameter onChange: 当目录内容变化时的回调
    func start(onChange: @escaping () -> Void) {
        // 如果已经在监控，先停止
        if isMonitoring {
            stop()
        }
        
        self.onChange = onChange
        
        // 打开目录获取文件描述符
        fileDescriptor = open(url.path, O_EVTONLY)
        
        guard fileDescriptor >= 0 else {
            Logger.monitor.error("DirectoryMonitor: Failed to open directory: \(self.url.path)")
            return
        }
        
        // 创建 DispatchSource 监控文件系统事件
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .extend, .attrib, .link, .revoke],
            queue: monitorQueue
        )
        
        // 设置事件处理
        source?.setEventHandler { [weak self] in
            self?.handleDirectoryChange()
        }
        
        // 设置取消处理
        source?.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }
        
        // 开始监控
        source?.resume()
        isMonitoring = true
        
        Logger.monitor.debug("DirectoryMonitor: Started monitoring: \(self.url.path)")
    }
    
    /// 停止监控
    func stop() {
        // 取消防抖任务
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        
        // 取消 DispatchSource
        source?.cancel()
        source = nil
        
        isMonitoring = false
        onChange = nil
        
        Logger.monitor.debug("DirectoryMonitor: Stopped monitoring")
    }
    
    // MARK: - Private Methods
    
    /// 处理目录变化事件（带防抖）
    private func handleDirectoryChange() {
        // 取消之前的防抖任务
        debounceWorkItem?.cancel()
        
        // 创建新的防抖任务
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, let onChange = self.onChange else { return }
            
            // 在主线程回调
            DispatchQueue.main.async {
                onChange()
            }
        }
        
        debounceWorkItem = workItem
        
        // 延迟执行
        monitorQueue.asyncAfter(deadline: .now() + debounceDelay, execute: workItem)
    }
}

// MARK: - DirectoryMonitorManager

/// 目录监控管理器，管理多个目录的监控
class DirectoryMonitorManager {
    
    /// 单例
    static let shared = DirectoryMonitorManager()
    
    /// 活跃的监控器字典，key 为目录路径
    private var monitors: [String: DirectoryMonitor] = [:]
    
    /// 线程安全锁
    private let lock = NSLock()
    
    private init() {}
    
    /// 开始监控目录
    /// - Parameters:
    ///   - url: 要监控的目录
    ///   - onChange: 变化回调
    func startMonitoring(url: URL, onChange: @escaping () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        
        let path = url.path
        
        // 如果已经在监控相同目录，先停止
        if let existingMonitor = monitors[path] {
            existingMonitor.stop()
            monitors.removeValue(forKey: path)
        }
        
        // 创建新的监控器
        let monitor = DirectoryMonitor(url: url)
        monitor.start(onChange: onChange)
        monitors[path] = monitor
    }
    
    /// 停止监控目录
    /// - Parameter url: 要停止监控的目录
    func stopMonitoring(url: URL) {
        lock.lock()
        defer { lock.unlock() }
        
        let path = url.path
        if let monitor = monitors[path] {
            monitor.stop()
            monitors.removeValue(forKey: path)
        }
    }
    
    /// 停止所有监控
    func stopAllMonitoring() {
        lock.lock()
        defer { lock.unlock() }
        
        for monitor in monitors.values {
            monitor.stop()
        }
        monitors.removeAll()
    }
    
    /// 检查是否正在监控指定目录
    func isMonitoring(url: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        return monitors[url.path]?.isMonitoring ?? false
    }
}

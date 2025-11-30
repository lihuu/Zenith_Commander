//
//  DirectoryMonitor.swift
//  Zenith Commander
//
//  目录变化监控服务，使用 DispatchSource 监听文件系统变化
//

import Foundation

/// 目录监控器，监听指定目录的文件变化
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
            print("DirectoryMonitor: Failed to open directory: \(url.path)")
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
        
        print("DirectoryMonitor: Started monitoring: \(url.path)")
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
        
        print("DirectoryMonitor: Stopped monitoring")
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

//
//  ConnectionManager.swift
//  Zenith Commander
//
//  Created by Zenith Commander on 2025/12/05.
//

import AppKit
import Foundation
import Combine
import os.log

class ConnectionManager: ObservableObject {
    static let shared = ConnectionManager()
    
    @Published var connections: [Connection] = []
    
    private let storageKey = "SavedConnections"
    
    private init() {
        loadConnections()
    }
    
    // MARK: - Storage
    
    func loadConnections() {
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            do {
                connections = try JSONDecoder().decode([Connection].self, from: data)
            } catch {
                Logger.fileSystem.error("Failed to load connections: \(error.localizedDescription)")
            }
        }
    }
    
    func saveConnection(_ connection: Connection) {
        if let index = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[index] = connection
        } else {
            connections.append(connection)
        }
        persist()
    }
    
    func deleteConnection(_ connection: Connection) {
        connections.removeAll { $0.id == connection.id }
        persist()
    }
    
    private func persist() {
        do {
            let data = try JSONEncoder().encode(connections)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            Logger.fileSystem.error("Failed to save connections: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Connection Actions
    
    /// 连接到远程服务器
    /// - Parameter connection: 连接配置
    /// - Returns: 如果是 SFTP 且使用内置实现，返回 SFTP URL；如果使用挂载方式，返回本地挂载路径；如果是其他协议，返回 nil
    func connect(_ connection: Connection) -> URL? {
        switch connection.protocolType {
        case .ftp, .smb:
            connectViaFinder(connection)
            return nil
        case .sftp:
            // 首先尝试使用 sshfs 挂载（如果可用）
            if let mountPath = tryMountWithSSHFS(connection) {
                return mountPath
            }
            // 回退到内置 SFTP 实现
            return connection.url
        }
    }
    
    private func connectViaFinder(_ connection: Connection) {
        guard let url = connection.url else { return }
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - SSHFS Mount Support
    
    /// 检查系统是否安装了 sshfs
    private func isSSHFSAvailable() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["sshfs"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    /// 尝试使用 sshfs 挂载 SFTP 连接
    /// - Parameter connection: 连接配置
    /// - Returns: 挂载成功返回本地挂载路径，失败返回 nil
    private func tryMountWithSSHFS(_ connection: Connection) -> URL? {
        // 检查 sshfs 是否可用
        guard isSSHFSAvailable() else {
            Logger.fileSystem.debug("sshfs not available, falling back to built-in SFTP")
            return nil
        }
        
        // 创建挂载点
        let mountBasePath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".zenith-mounts")
        let mountName = "\(connection.username)@\(connection.host)"
        let mountPath = mountBasePath.appendingPathComponent(mountName)
        
        // 确保挂载目录存在
        do {
            try FileManager.default.createDirectory(at: mountBasePath, withIntermediateDirectories: true)
        } catch {
            Logger.fileSystem.error("Failed to create mount base directory: \(error.localizedDescription)")
            return nil
        }
        
        // 检查是否已经挂载
        if isMounted(at: mountPath) {
            Logger.fileSystem.debug("Already mounted at \(mountPath.path)")
            return mountPath
        }
        
        // 创建挂载点目录
        do {
            try FileManager.default.createDirectory(at: mountPath, withIntermediateDirectories: true)
        } catch {
            Logger.fileSystem.error("Failed to create mount point: \(error.localizedDescription)")
            return nil
        }
        
        // 构建 sshfs 命令
        let port = Int(connection.port) ?? 22
        let remotePath = connection.path.isEmpty ? "/" : connection.path
        let sshfsSource = "\(connection.username)@\(connection.host):\(remotePath)"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/sshfs")
        process.arguments = [
            sshfsSource,
            mountPath.path,
            "-o", "port=\(port)",
            "-o", "volname=\(mountName)",
            "-o", "defer_permissions",
            "-o", "noappledouble",
            "-o", "noapplexattr"
        ]
        
        // 如果有密码，需要通过其他方式传递（sshfs 通常使用 SSH 密钥或交互式输入）
        // 这里暂时不处理密码，依赖 SSH 密钥认证
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                Logger.fileSystem.debug("Successfully mounted SFTP at \(mountPath.path)")
                return mountPath
            } else {
                Logger.fileSystem.error("sshfs mount failed with status \(process.terminationStatus)")
                // 清理空的挂载点目录
                try? FileManager.default.removeItem(at: mountPath)
                return nil
            }
        } catch {
            Logger.fileSystem.error("Failed to run sshfs: \(error.localizedDescription)")
            try? FileManager.default.removeItem(at: mountPath)
            return nil
        }
    }
    
    /// 检查路径是否已挂载
    private func isMounted(at path: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/mount")
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output.contains(path.path)
            }
        } catch {
            return false
        }
        return false
    }
    
    /// 卸载 SFTP 挂载点
    func unmountSSHFS(_ connection: Connection) {
        let mountBasePath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".zenith-mounts")
        let mountName = "\(connection.username)@\(connection.host)"
        let mountPath = mountBasePath.appendingPathComponent(mountName)
        
        guard isMounted(at: mountPath) else { return }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/umount")
        process.arguments = [mountPath.path]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                Logger.fileSystem.debug("Unmounted SFTP at \(mountPath.path)")
                // 清理挂载点目录
                try? FileManager.default.removeItem(at: mountPath)
            }
        } catch {
            Logger.fileSystem.error("Failed to unmount: \(error.localizedDescription)")
        }
    }
}

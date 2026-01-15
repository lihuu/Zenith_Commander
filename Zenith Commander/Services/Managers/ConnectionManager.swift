//
//  ConnectionManager.swift
//  Zenith Commander
//
//  Created by Zenith Commander on 2025/12/05.
//

import AppKit
import Combine
import Foundation
import NetFS
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
    /// - Returns: 如果是 SFTP/SMB 返回本地挂载路径或 SFTP URL；如果是 FTP 返回 nil
    func connect(_ connection: Connection) -> URL? {
        switch connection.protocolType {
        case .ftp:
            connectViaFinder(connection)
            return nil
        case .smb:
            return mountSMB(connection)
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
            "-o", "noapplexattr",
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
    
    // MARK: - SMB Mount Support
    
    /// 挂载 SMB 共享（与 Finder 行为一致）
    /// - 使用 NetFSMountURLSync
    /// - 挂载到 /Volumes/ShareName
    /// - 支持 Guest 访问（空用户名/密码）
    private func mountSMB(_ connection: Connection) -> URL? {
        guard let serverURL = connection.url else {
            Logger.fileSystem.error("Invalid SMB URL")
            return nil
        }
        
        // 1. 检查是否已挂载
        if let existingMount = findExistingSMBMount(for: serverURL, host: connection.host) {
            Logger.fileSystem.debug("SMB already mounted at \(existingMount.path)")
            return existingMount
        }
        
        // 2. 准备认证信息
        // Guest: user = nil, passwd = nil
        let user: CFString? = connection.username.isEmpty ? nil : connection.username as CFString
        let passwd: CFString? = connection.password.isEmpty ? nil : connection.password as CFString
        
        // 3. 调用 NetFSMountURLSync
        var mountPoints: Unmanaged<CFArray>?
        
        let result = NetFSMountURLSync(
            serverURL as CFURL,
            nil,  // nil = 使用 /Volumes (Finder 行为)
            user,
            passwd,
            nil,  // open_options
            nil,  // mount_options
            &mountPoints
        )
        
        // 4. 处理结果
        if result == 0, let points = mountPoints?.takeRetainedValue() as? [String], let first = points.first {
            let mountURL = URL(fileURLWithPath: first)
            Logger.fileSystem.debug("SMB mounted at \(mountURL.path)")
            return mountURL
        } else {
            Logger.fileSystem.error("SMB mount failed with error code: \(result)")
            return nil
        }
    }
    
    /// 检查 SMB 共享是否已挂载
    private func findExistingSMBMount(for smbURL: URL, host: String) -> URL? {
        // 从 SMB URL 提取 share name
        // smb://server/share → share
        let shareName = smbURL.lastPathComponent
        guard !shareName.isEmpty else { return nil }
        
        // 检查 /Volumes 下是否存在
        let volumesURL = URL(fileURLWithPath: "/Volumes")
        let fm = FileManager.default
        
        guard let contents = try? fm.contentsOfDirectory(at: volumesURL, includingPropertiesForKeys: nil) else {
            return nil
        }
        
        // 查找匹配的挂载点
        for item in contents {
            if item.lastPathComponent == shareName || item.lastPathComponent.hasPrefix(shareName) {
                // 验证是否是此 SMB 服务器的挂载
                if isSMBMountFromServer(mountPoint: item, server: host) {
                    return item
                }
            }
        }
        
        return nil
    }
    
    /// 验证挂载点是否来自指定 SMB 服务器
    private func isSMBMountFromServer(mountPoint: URL, server: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/mount")
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // 查找格式: //user@server/share on /Volumes/share (smbfs, ...)
                // 或: //server/share on /Volumes/share
                let lines = output.components(separatedBy: "\n")
                for line in lines {
                    if line.contains(mountPoint.path) && line.contains(server) && line.contains("smbfs") {
                        return true
                    }
                }
            }
        } catch {
            return false
        }
        return false
    }
    
    /// 卸载 SMB 共享
    func unmountSMB(at mountPoint: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["unmount", mountPoint.path]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                Logger.fileSystem.debug("SMB unmounted at \(mountPoint.path)")
            } else {
                Logger.fileSystem.error("SMB unmount failed with status \(process.terminationStatus)")
            }
        } catch {
            Logger.fileSystem.error("Failed to unmount SMB: \(error.localizedDescription)")
        }
    }
}

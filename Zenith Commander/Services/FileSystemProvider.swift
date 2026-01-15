//
//  FileSystemProvider.swift
//  Zenith Commander
//
//  Created by Zenith Commander on 2025/12/05.
//

import Foundation

/// 文件系统提供者协议
/// 定义了所有文件系统（本地、SFTP等）必须实现的基本操作
protocol FileSystemProvider {
    /// 协议方案 (e.g., "file", "sftp", "ftp")
    var scheme: String { get }
}

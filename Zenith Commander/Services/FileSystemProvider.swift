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
    
    /// 加载目录内容
    func loadDirectory(at path: URL) async throws -> [FileItem]
    
    /// 创建目录
    func createDirectory(at path: URL, name: String) async throws -> FileItem
    
    /// 创建文件
    func createFile(at path: URL, name: String) async throws -> FileItem
    
    /// 删除项目
    func delete(items: [FileItem]) async throws
    
    /// 移动项目
    func move(items: [FileItem], to destination: URL) async throws
    
    /// 复制项目
    func copy(items: [FileItem], to destination: URL) async throws
    
    /// 获取父目录
    func parentDirectory(of path: URL) -> URL
    
    /// 打开文件 (通常是本地打开，对于远程文件可能需要先下载)
    func openFile(_ file: FileItem) async
}

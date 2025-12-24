//  重构：将AppState或者 State中依赖外部的能力隔离开来
//  AppEnvironment.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/24/25.
//


import Foundation
import Combine

// 1) FileSystem
protocol FileSysteming {
    func homeDirectory() -> URL
    func tempDirectory() -> URL
    func fileExists(_ url: URL) -> Bool
    func createDirectory(_ url: URL) throws
    func loadDirectory(at url: URL) async -> [FileItem]   // 或你自己的类型
    func copyFiles(_ files: [FileItem], to dest: URL) async throws
    func moveFiles(_ files: [FileItem], to dest: URL) async throws
}

// 2) Settings（先只抽你测试会改的那块）
protocol SettingsProviding: AnyObject {
    var rsyncEnabled: Bool { get set }
    // 后面你需要更多再加：theme、keymap、bookmark...
}

// 3) 外部命令（Rsync/Git/Process）
protocol ToolRunning {
    func run(_ command: ToolCommand) async throws -> ToolResult
}

struct ToolCommand {
    var executable: String
    var arguments: [String]
    var workingDirectory: URL?
}

struct ToolResult {
    var exitCode: Int32
    var stdout: String
    var stderr: String
}

// 4) 调度/主线程（最小：提供异步派发）
protocol MainScheduling {
    func async(_ work: @escaping @MainActor () -> Void)
    func asyncAfter(seconds: TimeInterval, _ work: @escaping @MainActor () -> Void)
}

// 5) 运行时开关：是否允许启动 watcher/task
struct RuntimePolicy: Sendable {
    var startSideEffects: Bool
}

// AppEnvironment：把以上东西绑在一起
struct AppEnvironment {
    var fileSystem: FileSysteming
    var settings: SettingsProviding
    var toolRunner: ToolRunning
    var main: MainScheduling
    var userDefaults: UserDefaults
    var runtime: RuntimePolicy
}

struct LiveFileSystem: FileSysteming{
    func homeDirectory() -> URL {
        <#code#>
    }

    func tempDirectory() -> URL {
        <#code#>
    }

    func fileExists(_ url: URL) -> Bool {
        <#code#>
    }

    func createDirectory(_ url: URL) throws {
        <#code#>
    }

    func loadDirectory(at url: URL) async -> [FileItem] {
        <#code#>
    }

    func copyFiles(_ files: [FileItem], to dest: URL) async throws {
        <#code#>
    }

    func moveFiles(_ files: [FileItem], to dest: URL) async throws {
        <#code#>
    }

    
}





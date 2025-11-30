//
//  CommandParser.swift
//  Zenith Commander
//
//  命令解析器 - 解析和验证命令模式输入
//

import Foundation

/// 命令类型
enum CommandType: String, CaseIterable {
    case mkdir
    case touch
    case move
    case mv
    case copy
    case cp
    case delete
    case rm
    case cd
    case open
    case term
    case terminal
    case quit
    case q
    case unknown
    
    /// 从字符串解析命令类型
    static func from(_ string: String) -> CommandType {
        CommandType(rawValue: string.lowercased()) ?? .unknown
    }
}

/// 解析后的命令
struct ParsedCommand {
    let type: CommandType
    let args: [String]
    let rawInput: String
    
    /// 获取第一个参数
    var firstArg: String? {
        args.first
    }
    
    /// 获取第二个参数
    var secondArg: String? {
        args.count > 1 ? args[1] : nil
    }
    
    /// 参数数量
    var argCount: Int {
        args.count
    }
    
    /// 将所有参数合并为一个字符串（用于文件名等）
    var joinedArgs: String {
        args.joined(separator: " ")
    }
}

/// 命令解析器
struct CommandParser {
    
    /// 解析命令行输入
    /// - Parameter input: 原始命令输入
    /// - Returns: 解析后的命令
    static func parse(_ input: String) -> ParsedCommand {
        let trimmedInput = input.trimmingCharacters(in: .whitespaces)
        let parts = parseCommandLine(trimmedInput)
        
        guard let commandString = parts.first else {
            return ParsedCommand(type: .unknown, args: [], rawInput: input)
        }
        
        let type = CommandType.from(commandString)
        let args = Array(parts.dropFirst())
        
        return ParsedCommand(type: type, args: args, rawInput: input)
    }
    
    /// 解析命令行，支持引号包裹的参数
    /// - Parameter input: 命令行输入
    /// - Returns: 分割后的参数数组
    static func parseCommandLine(_ input: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        var quoteChar: Character = "\""
        
        for char in input {
            if !inQuotes && (char == "\"" || char == "'") {
                inQuotes = true
                quoteChar = char
            } else if inQuotes && char == quoteChar {
                inQuotes = false
            } else if !inQuotes && char == " " {
                if !current.isEmpty {
                    result.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }
        }
        
        if !current.isEmpty {
            result.append(current)
        }
        
        return result
    }
    
    /// 解析路径（支持相对路径和绝对路径）
    /// - Parameters:
    ///   - path: 路径字符串
    ///   - base: 基础路径（当前目录）
    /// - Returns: 解析后的完整 URL
    static func resolvePath(_ path: String, relativeTo base: URL) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        } else if path.hasPrefix("~") {
            let home = FileManager.default.homeDirectoryForCurrentUser
            if path == "~" {
                return home
            } else {
                // 移除 "~/" 前缀
                let relativePath = String(path.dropFirst(path.hasPrefix("~/") ? 2 : 1))
                return home.appendingPathComponent(relativePath)
            }
        } else {
            return base.appendingPathComponent(path)
        }
    }
    
    /// 验证 mkdir 命令
    static func validateMkdir(_ command: ParsedCommand) -> (valid: Bool, name: String) {
        let name = command.joinedArgs.isEmpty ? "New Folder" : command.joinedArgs
        return (true, name)
    }
    
    /// 验证 touch 命令
    static func validateTouch(_ command: ParsedCommand) -> (valid: Bool, name: String) {
        let name = command.joinedArgs.isEmpty ? "New File.txt" : command.joinedArgs
        return (true, name)
    }
    
    /// 验证 move/copy 命令
    /// - Returns: (valid, source, destination) - source 为 nil 表示使用选中文件
    static func validateMoveOrCopy(_ command: ParsedCommand, currentPath: URL) -> (valid: Bool, source: URL?, destination: URL?, error: String?) {
        if command.argCount >= 2 {
            // move/copy <src> <dest>
            let src = resolvePath(command.args[0], relativeTo: currentPath)
            let dest = resolvePath(command.args[1], relativeTo: currentPath)
            return (true, src, dest, nil)
        } else if command.argCount == 1 {
            // move/copy <dest> - 使用选中文件作为源
            let dest = resolvePath(command.args[0], relativeTo: currentPath)
            return (true, nil, dest, nil)
        } else {
            return (false, nil, nil, "Usage: \(command.type.rawValue) <dest> or \(command.type.rawValue) <src> <dest>")
        }
    }
    
    /// 验证 delete 命令
    /// - Returns: (valid, targetPath) - targetPath 为 nil 表示使用选中文件
    static func validateDelete(_ command: ParsedCommand, currentPath: URL) -> (valid: Bool, targetPath: URL?) {
        if command.args.isEmpty {
            // 删除选中文件
            return (true, nil)
        } else {
            // 删除指定文件
            let target = resolvePath(command.joinedArgs, relativeTo: currentPath)
            return (true, target)
        }
    }
    
    /// 验证 cd 命令
    static func validateCd(_ command: ParsedCommand, currentPath: URL) -> (valid: Bool, targetPath: URL?, error: String?) {
        guard let pathArg = command.firstArg else {
            return (false, nil, "Usage: cd <path>")
        }
        
        let targetPath = resolvePath(pathArg, relativeTo: currentPath)
        
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: targetPath.path, isDirectory: &isDir) && isDir.boolValue {
            return (true, targetPath, nil)
        } else {
            return (false, nil, "Directory not found: \(pathArg)")
        }
    }
}

//
//  ToolRunner.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/19/25.
//

import Foundation


struct ToolRequest {
    let executable: String
    let args: [String]
    let workingDirectory: String?
}

struct ToolResponse {
    let exitCode: Int32
    let stdout: [String]
    let stderr: [String]
}

protocol ToolRunner: PluginCapability {
    func run(_ request: ToolRequest) async throws -> ToolResponse
}

extension ToolRunner {
    var type: CapabilityType {
        .toolRunner
    }
}


final class ProcessToolRunner: ToolRunner {
    func run(_ request: ToolRequest) async throws -> ToolResponse {
        try await withCheckedThrowingContinuation { cont in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            p.arguments = [request.executable] + request.args
            if let wd = request.workingDirectory {
                p.currentDirectoryURL = URL(fileURLWithPath: wd)
            }

            let out = Pipe()
            let err = Pipe()
            p.standardOutput = out
            p.standardError = err

            p.terminationHandler = { proc in
                let outData = out.fileHandleForReading.readDataToEndOfFile()
                let errData = err.fileHandleForReading.readDataToEndOfFile()

                let outStr = String(data: outData, encoding: .utf8) ?? ""
                let errStr = String(data: errData, encoding: .utf8) ?? ""

                let stdout = outStr.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                let stderr = errStr.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

                cont
                    .resume(
                        returning: ToolResponse(
                            exitCode: proc.terminationStatus,
                            stdout: stdout,
                            stderr: stderr
                        )
                    )
            }

            do {
                try p.run()
            } catch {
                cont.resume(throwing: error)
            }
        }
    }
}

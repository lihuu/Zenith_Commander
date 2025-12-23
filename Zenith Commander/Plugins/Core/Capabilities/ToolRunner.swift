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
    func runSync(_ request: ToolRequest) throws -> ToolResponse
}

extension ToolRunner {
    var type: CapabilityType {
        .toolRunner
    }
}

final class ProcessToolRunner: ToolRunner {
    private func setupProcess(for request: ToolRequest) -> (
        process: Process, stdout: Pipe, stderr: Pipe
    ) {
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

        return (p, out, err)
    }

    private func parseOutput(stdout: Pipe, stderr: Pipe, exitCode: Int32) -> ToolResponse {
        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()

        let outStr = String(data: outData, encoding: .utf8) ?? ""
        let errStr = String(data: errData, encoding: .utf8) ?? ""

        let stdoutLines = outStr.split(separator: "\n", omittingEmptySubsequences: false).map(
            String.init)
        let stderrLines = errStr.split(separator: "\n", omittingEmptySubsequences: false).map(
            String.init)

        return ToolResponse(
            exitCode: exitCode,
            stdout: stdoutLines,
            stderr: stderrLines
        )
    }

    func run(_ request: ToolRequest) async throws -> ToolResponse {
        try await withCheckedThrowingContinuation { cont in
            let (p, out, err) = setupProcess(for: request)

            p.terminationHandler = { [weak self] proc in
                guard let self = self else { return }
                let response = self.parseOutput(
                    stdout: out, stderr: err, exitCode: proc.terminationStatus)
                cont.resume(returning: response)
            }

            do {
                try p.run()
            } catch {
                cont.resume(throwing: error)
            }
        }
    }

    func runSync(_ request: ToolRequest) throws -> ToolResponse {
        let (p, out, err) = setupProcess(for: request)

        try p.run()
        p.waitUntilExit()

        return parseOutput(stdout: out, stderr: err, exitCode: p.terminationStatus)
    }
}

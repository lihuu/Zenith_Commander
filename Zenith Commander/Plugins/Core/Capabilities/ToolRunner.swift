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
        p.executableURL = URL(fileURLWithPath: request.executable)
        print("[ToolRunner] Executable URL: \(p.executableURL!.path)")
        p.arguments = request.args
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
        print(
            "[ToolRunner] Running command: \(request.executable) \(request.args.joined(separator: " "))"
        )
        if let wd = request.workingDirectory {
            print("[ToolRunner] Working directory: \(wd)")
        }

        let (p, out, err) = setupProcess(for: request)

        try p.run()
        print("[ToolRunner] Process started, waiting for exit...")
        p.waitUntilExit()
        print("[ToolRunner] Process exited with code: \(p.terminationStatus)")

        let response = parseOutput(stdout: out, stderr: err, exitCode: p.terminationStatus)
        print("[ToolRunner] stdout lines: \(response.stdout.count)")
        print("[ToolRunner] stderr lines: \(response.stderr.count)")
        if !response.stdout.isEmpty {
            print("[ToolRunner] stdout: \(response.stdout.joined(separator: "\\n"))")
        }
        if !response.stderr.isEmpty {
            print("[ToolRunner] stderr: \(response.stderr.joined(separator: "\\n"))")
        }

        return response
    }
}

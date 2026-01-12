//
//  ToolRunner.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/19/25.
//

import Foundation
import Synchronization
import os.log

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

protocol ToolRunner: PluginCapability, Sendable {
    func run(_ request: ToolRequest) async throws -> ToolResponse
    nonisolated func runSync(_ request: ToolRequest) throws -> ToolResponse
}

extension ToolRunner {
    var type: CapabilityType {
        .toolRunner
    }
}

struct ProcessToolRunner: ToolRunner {

    private nonisolated func setupProcess(for request: ToolRequest) -> (
        process: Process, stdout: Pipe, stderr: Pipe
    ) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: request.executable)
        Logger.tools.debug("[ToolRunner] Executable URL: \(p.executableURL!.path)")
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

    private nonisolated static func parseOutput(stdout: Pipe, stderr: Pipe, exitCode: Int32)
        -> ToolResponse
    {
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
            let lock = NSLock()
            let didResume = Atomic<Bool>(false)
            @Sendable func resumeOnce(_ body: () -> Void) {
                lock.lock()
                defer { lock.unlock() }
                guard !didResume.load(ordering: .acquiring) else { return }
                didResume.store(true, ordering: .releasing)
                body()
            }

            let (p, out, err) = setupProcess(for: request)

            p.terminationHandler = { proc in
                // Release handler promptly to avoid retaining cycles / late fires.
                proc.terminationHandler = nil

                let response = ProcessToolRunner.parseOutput(
                    stdout: out,
                    stderr: err,
                    exitCode: proc.terminationStatus
                )

                resumeOnce {
                    cont.resume(returning: response)
                }
            }

            do {
                try p.run()
            } catch {
                p.terminationHandler = nil
                resumeOnce {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    nonisolated func runSync(_ request: ToolRequest) throws -> ToolResponse {
        if let wd = request.workingDirectory {
            Logger.tools.debug("[ToolRunner] Working directory: \(wd)")
        }

        let (p, out, err) = setupProcess(for: request)

        try p.run()
        p.waitUntilExit()

        let response = ProcessToolRunner.parseOutput(
            stdout: out, stderr: err, exitCode: p.terminationStatus)
        if !response.stdout.isEmpty {
            Logger.tools.debug("[ToolRunner] stdout: \(response.stdout.joined(separator: "\\n"))")
        }
        if !response.stderr.isEmpty {
            Logger.tools.debug("[ToolRunner] stderr: \(response.stderr.joined(separator: "\\n"))")
        }

        Logger.tools.debug("[ToolRunner] Process exited with code: \(response.exitCode)")

        return response
    }
}

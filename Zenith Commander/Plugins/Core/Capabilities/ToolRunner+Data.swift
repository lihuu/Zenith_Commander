//
//  ToolRunner+Data.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/19/25.
//

import Foundation
import Synchronization

// MARK: - Extended ToolRunner APIs (non-breaking additions)

/// A binary-friendly response (keeps raw bytes). Useful for tools that emit large output or NUL-separated output.
struct ToolResponseData {
    let exitCode: Int32
    let stdout: Data
    let stderr: Data

    var stdoutString: String { String(decoding: stdout, as: UTF8.self) }
    var stderrString: String { String(decoding: stderr, as: UTF8.self) }

    var stdoutLines: [String] {
        stdoutString.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    var stderrLines: [String] {
        stderrString.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }
}

extension ToolRunner {

    /// Run a process and capture raw stdout/stderr bytes.
    /// This is implemented here to avoid changing existing `ToolRunner` requirements.
    func runData(_ request: ToolRequest) async throws -> ToolResponseData {
        try await runData(request, stdin: nil)
    }

    /// Run a process with stdin bytes and capture raw stdout/stderr bytes.
    /// This enables patterns like: `candidates -> fzf --filter query`.
    func runData(_ request: ToolRequest, stdin: Data?) async throws -> ToolResponseData {
        try await withCheckedThrowingContinuation { cont in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: request.executable)
            p.arguments = request.args
            if let wd = request.workingDirectory {
                p.currentDirectoryURL = URL(fileURLWithPath: wd)
            }

            let out = Pipe()
            let err = Pipe()
            p.standardOutput = out
            p.standardError = err

            if let stdin {
                let inPipe = Pipe()
                // Write all input up-front.
                inPipe.fileHandleForWriting.write(stdin)
                try? inPipe.fileHandleForWriting.close()
                p.standardInput = inPipe
            }

            let lock = NSLock()
            let didResume = Atomic<Bool>(false)
            @Sendable func resumeOnce(_ body: () -> Void) {
                lock.lock()
                defer { lock.unlock() }
                guard !didResume.load(ordering: .acquiring) else { return }
                didResume.store(true, ordering: .releasing)
                body()
            }

            p.terminationHandler = { proc in
                // Release handler promptly to avoid retaining cycles / late fires.
                proc.terminationHandler = nil

                let outData = out.fileHandleForReading.readDataToEndOfFile()
                let errData = err.fileHandleForReading.readDataToEndOfFile()
                let resp = ToolResponseData(exitCode: proc.terminationStatus, stdout: outData, stderr: errData)
                resumeOnce {
                    cont.resume(returning: resp)
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

    /// Sync variant of `runData(_:stdin:)`.
    func runDataSync(_ request: ToolRequest) throws -> ToolResponseData {
        try runDataSync(request, stdin: nil)
    }

    /// Sync variant with stdin.
    func runDataSync(_ request: ToolRequest, stdin: Data?) throws -> ToolResponseData {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: request.executable)
        p.arguments = request.args
        if let wd = request.workingDirectory {
            p.currentDirectoryURL = URL(fileURLWithPath: wd)
        }

        let out = Pipe()
        let err = Pipe()
        p.standardOutput = out
        p.standardError = err

        if let stdin {
            let inPipe = Pipe()
            inPipe.fileHandleForWriting.write(stdin)
            try? inPipe.fileHandleForWriting.close()
            p.standardInput = inPipe
        }

        try p.run()
        p.waitUntilExit()

        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        return ToolResponseData(exitCode: p.terminationStatus, stdout: outData, stderr: errData)
    }

    /// Convenience: run and parse output into the existing line-based `ToolResponse`.
    func runWithInput(_ request: ToolRequest, stdin: Data) async throws -> ToolResponse {
        let resp = try await runData(request, stdin: stdin)
        return ToolResponse(exitCode: resp.exitCode, stdout: resp.stdoutLines, stderr: resp.stderrLines)
    }

    /// Convenience: sync run and parse output into the existing line-based `ToolResponse`.
    func runWithInputSync(_ request: ToolRequest, stdin: Data) throws -> ToolResponse {
        let resp = try runDataSync(request, stdin: stdin)
        return ToolResponse(exitCode: resp.exitCode, stdout: resp.stdoutLines, stderr: resp.stderrLines)
    }
}

#!/usr/bin/env swift

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

func setupProcess(for request: ToolRequest) -> (process: Process, stdout: Pipe, stderr: Pipe) {
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

func parseOutput(stdout: Pipe, stderr: Pipe, exitCode: Int32) -> ToolResponse {
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

func runSync(_ request: ToolRequest) throws -> ToolResponse {
    print("[Test] Running command: \(request.executable) \(request.args.joined(separator: " "))")

    let (p, out, err) = setupProcess(for: request)

    try p.run()
    print("[Test] Process started, waiting for exit...")
    p.waitUntilExit()
    print("[Test] Process exited with code: \(p.terminationStatus)")

    let response = parseOutput(stdout: out, stderr: err, exitCode: p.terminationStatus)
    print("[Test] stdout lines: \(response.stdout.count)")
    print("[Test] stderr lines: \(response.stderr.count)")
    if !response.stdout.isEmpty {
        print("[Test] stdout: \(response.stdout.joined(separator: "\\n"))")
    }
    if !response.stderr.isEmpty {
        print("[Test] stderr: \(response.stderr.joined(separator: "\\n"))")
    }

    return response
}

// Test git --version
print("=== Testing git --version ===")
let gitPaths = ["/opt/homebrew/bin/git", "/usr/bin/git", "/usr/local/bin/git"]

for gitPath in gitPaths {
    if FileManager.default.isExecutableFile(atPath: gitPath) {
        print("\n--- Found git at: \(gitPath) ---")
        let request = ToolRequest(
            executable: gitPath,
            args: ["--version"],
            workingDirectory: nil
        )

        do {
            let response = try runSync(request)
            print("Exit code: \(response.exitCode)")
            print("Success: \(response.exitCode == 0)")
        } catch {
            print("Error: \(error)")
        }
        break
    }
}

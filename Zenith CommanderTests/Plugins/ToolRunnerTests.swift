//
//  ToolRunnerTests.swift
//  Zenith CommanderTests
//
//  验证 ProcessToolRunner.runSync 的有界执行语义：
//  子进程卡死时必须在 timeout 内返回，而不是无限阻塞。
//

import Foundation
import Testing

@testable import Zenith_Commander

@MainActor
struct ToolRunnerTests {

    @Test func runSyncReturnsNormallyForFastCommand() throws {
        let runner = ProcessToolRunner()
        let response = try runner.runSync(
            ToolRequest(
                executable: "/bin/echo",
                args: ["hello"],
                workingDirectory: "/tmp",
                timeout: 5.0
            )
        )
        #expect(response.exitCode == 0)
        #expect(response.stdout.joined() == "hello")
    }

    @Test func runSyncTimesOutAndTerminatesHungCommand() throws {
        let runner = ProcessToolRunner()
        let start = Date()
        let response = try runner.runSync(
            ToolRequest(
                executable: "/bin/sleep",
                args: ["30"],
                workingDirectory: "/tmp",
                timeout: 1.0
            )
        )
        let elapsed = Date().timeIntervalSince(start)

        // 超时后进程被终止：1 秒时限下整体返回应远小于 30 秒
        #expect(elapsed < 5.0)
        // 收到终止信号，退出码非 0
        #expect(response.exitCode != 0)
    }
}
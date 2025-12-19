//
//  ToolRunner.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/19/25.
//

struct ToolRequest {
    let executable: String
    let args: [String]
    let workingDirectory: String?
}

struct ToolResponse {
    let exitCode: Int
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

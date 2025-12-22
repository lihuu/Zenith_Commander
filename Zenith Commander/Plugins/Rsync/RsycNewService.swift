import Foundation

struct RsyncNewConfig: Sendable {
    var sourcePath: String
    var targetPath: String
    var deleteExtraFiles: Bool = false
    var preserveAttributes: Bool = true
    var dryRun: Bool = true
    var excludePatterns: [String] = []
}

final class RsyncNewService: Sendable {
    static let shared = RsyncNewService()

    func bindArgs(config: RsyncNewConfig) -> [String] {
        var args: [String] = []
        if config.preserveAttributes {
            args.append("-a")
        }

        if config.dryRun {
            args.append("--dry-run")
        }

        for pattern in config.excludePatterns {
            args.append("--exclude=\(pattern)")
        }

        if config.deleteExtraFiles {
            args.append("--delete")
        }

        args.append(config.sourcePath.hasSuffix("/") ? config.sourcePath : config.sourcePath + "/")
        args.append(config.targetPath)

        return args
    }

    func preview(config: RsyncNewConfig, toolRunner: ToolRunner) async throws -> ToolResponse {
        let req = ToolRequest(
            executable: "rsync",
            args: bindArgs(config: config),
            workingDirectory: nil
        )

        return try await toolRunner.run(req)
    }

    func run(config: RsyncNewConfig, toolRunner: ToolRunner) async throws -> ToolResponse {
        var args = bindArgs(config: config)
        if config.dryRun {
            args.removeAll { $0 == "--dry-run" }
        }

        let req = ToolRequest(
            executable: "rsync",
            args: args,
            workingDirectory: nil
        )

        return try await toolRunner.run(req)
    }

}

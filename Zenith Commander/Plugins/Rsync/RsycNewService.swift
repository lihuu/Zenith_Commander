import Foundation

struct RsyncNewConfig: Sendable {
    var sourcePath: String
    var targetPath: String
    var deleteExtraFiles: Bool = false
    var preserveAttributes: Bool = true
    var dryRun: Bool = true
    var excludePatterns: [String] = []

    /// Convert to RsyncSyncConfig for RsyncService
    func toRsyncSyncConfig() -> RsyncSyncConfig {
        RsyncSyncConfig(
            source: URL(fileURLWithPath: sourcePath),
            destination: URL(fileURLWithPath: targetPath),
            mode: deleteExtraFiles ? .mirror : .update,
            dryRun: dryRun,
            preserveAttributes: preserveAttributes,
            deleteExtras: deleteExtraFiles,
            excludePatterns: excludePatterns,
            customFlags: []
        )
    }
}

final class RsyncNewService: Sendable {
    static let shared = RsyncNewService()

    private let rsyncService: RsyncService

    init(rsyncService: RsyncService = .shared) {
        self.rsyncService = rsyncService
    }

    /// Build rsync arguments from config (delegates to RsyncService)
    func bindArgs(config: RsyncNewConfig) -> [String] {
        let syncConfig = config.toRsyncSyncConfig()
        return rsyncService.buildArgs(config: syncConfig)
    }

    /// Preview rsync operation (delegates to RsyncService)
    func preview(config: RsyncNewConfig, toolRunner: ToolRunner) async throws -> ToolResponse {
        let req = ToolRequest(
            executable: "/usr/bin/rsync",
            args: bindArgs(config: config),
            workingDirectory: nil
        )

        return try await toolRunner.run(req)
    }

    /// Run rsync operation (delegates to RsyncService)
    func run(config: RsyncNewConfig, toolRunner: ToolRunner) async throws -> ToolResponse {
        var modifiedConfig = config
        modifiedConfig.dryRun = false

        let req = ToolRequest(
            executable: "/usr/bin/rsync",
            args: bindArgs(config: modifiedConfig),
            workingDirectory: nil
        )

        return try await toolRunner.run(req)
    }
}

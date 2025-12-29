import Foundation

/// Resolve external tools and pick the best available one.
struct ExternalToolchain: Sendable {
    let rgPath: String?
    let fdPath: String?
    let findPath: String
    let fzfPath: String?

    init() {
        self.rgPath = Self.resolveTool("rg")
        self.fdPath = Self.resolveTool("fd")
        self.fzfPath = Self.resolveTool("fzf")
        self.findPath = Self.resolveTool("find") ?? "/usr/bin/find"
    }

    var preferredListTool: FileListTool {
        if rgPath != nil { return .rg }
        if fdPath != nil { return .fd }
        return .find
    }

    /// Resolve tool path using predefined paths first, fallback to which.
    private static func resolveTool(_ name: String) -> String? {
        // 1) Try predefined paths
        let candidates = ToolPathUtils.generateCandidatePaths(
            executableName: name,
            additionalPaths: ToolPathUtils.candidatePaths.map { "\($0)\(name)" }
        )
        if let found = ToolPathUtils.resolveFirstExecutablePath(candidatePaths: candidates) {
            return found
        }

        // 2) Fallback to which command
        return whichFallback(name)
    }

    /// Fallback: use which command to locate tool.
    private static func whichFallback(_ name: String) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["which", name]

        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()

        do { try p.run() } catch { return nil }
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return nil }

        let data = out.fileHandleForReading.readDataToEndOfFile()
        let path = String(decoding: data, as: UTF8.self).trimmingCharacters(
            in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }
}
import SwiftUI

struct RsyncNewSheetView: View {
    let context: PluginContext

    @State private var config: RsyncNewConfig
    @State private var output: [String] = []
    @State private var isRunning: Bool = false
    @State private var showDeleteConfirm: Bool = false

    init(context: PluginContext) {
        self.context = context
        let panes = context.panes()
        let source = (panes.active == .left) ? panes.leftPath : panes.rightPath
        let target = (panes.active == .left) ? panes.rightPath : panes.leftPath
        _config = State(initialValue: RsyncNewConfig(sourcePath: source, targetPath: target))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rsync Sync").font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Source: \(config.sourcePath)")
                Text("Target: \(config.targetPath)")
                Button("Swap") {
                    let tmp = config.sourcePath
                    config.sourcePath = config.targetPath
                    config.targetPath = tmp
                }
            }

            Toggle("Dry-run (preview only)", isOn: $config.dryRun)
            Toggle("Preserve attributes (-a)", isOn: $config.preserveAttributes)
            Toggle("Delete extra files in target (--delete)", isOn: $config.deleteExtraFiles)

            Text("Exclude patterns (one per line):")
            ExcludeEditor(
                patterns: Binding(
                    get: { config.excludePatterns.joined(separator: "\n") },
                    set: { config.excludePatterns = $0.split(separator: "\n").map(String.init) }
                ))

            HStack {
                Button("Preview") { Task { await runPreview() } }
                    .disabled(isRunning)

                Button("Run") {
                    if config.deleteExtraFiles {
                        showDeleteConfirm = true
                    } else {
                        Task { await runSync() }
                    }
                }
                .disabled(isRunning)
                .keyboardShortcut(.defaultAction)

                Spacer()

                Button("Close") {
                    Task {
                        await context.dispatch(.ui(.dismissSheet))
                    }
                }
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(output.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.system(.body, design: .monospaced))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 220)
        }
        .padding(16)
        .frame(width: 720, height: 520)
        .alert("Confirm delete", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Run", role: .destructive) { Task { await runSync() } }
        } message: {
            Text("This will delete files in target that are not present in source. Continue?")
        }
    }

    private func runPreview() async {
        isRunning = true
        output.removeAll(keepingCapacity: true)
        do {
            let svc = RsyncNewService(toolRunner: context.toolRunner)
            let resp = try await svc.preview(config: config)
            output = (resp.stdout + resp.stderr)
        } catch {
            output = ["[error] \(String(describing: error))"]
        }
        isRunning = false
    }

    private func runSync() async {
        isRunning = true
        output.removeAll(keepingCapacity: true)
        do {
            let svc = RsyncNewService(toolRunner: context.toolRunner)
            let resp = try await svc.run(config: config)
            output = (resp.stdout + resp.stderr)
        } catch {
            output = ["[error] \(String(describing: error))"]
        }
        isRunning = false
    }
}

private struct ExcludeEditor: View {
    @Binding var patterns: String
    var body: some View {
        TextEditor(text: $patterns)
            .font(.system(.body, design: .monospaced))
            .frame(height: 90)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))
    }
}

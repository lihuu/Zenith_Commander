import SwiftUI

struct GitPlugin: ZenithPlugin {
    let id = PluginID(rawValue: "git")
    let displayName = "Git"
    let version = "1.0.0"

    func makeCapabilities(context: PluginContext) -> [any PluginCapability] {
        let cmd = GitCommandProvider(context: context)
        let ui = GitUIContribution()
        return [cmd, ui]
    }
}

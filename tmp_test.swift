import SwiftUI
struct TestApp: App {
    var body: some Scene {
        WindowGroup { Text("hi") }
        .commands {
            CommandGroup(replacing: .newItem) {}
            Group {
                CommandGroup(replacing: .appInfo) {}
                CommandGroup(replacing: .appSettings) {}
            }
            CommandGroup(replacing: .appVisibility) {}
            CommandGroup(replacing: .appTermination) {}
            CommandGroup(replacing: .textEditing) {}
            CommandGroup(replacing: .pasteboard) {}
            CommandGroup(replacing: .undoRedo) {}
            CommandMenu("Nav") { }
            CommandMenu("View") { }
            CommandGroup(replacing: .help) {}
        }
    }
}

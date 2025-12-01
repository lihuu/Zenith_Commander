//
//  Zenith_CommanderApp.swift
//  Zenith Commander
//
//  Created by Hu Li on 11/27/25.
//

import SwiftUI
import AppKit

@main
struct Zenith_CommanderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState: AppState

    init() {
        var testDirectory: URL? = nil
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-testDirectory") {
            if arguments.count > index + 1 {
                testDirectory = URL(fileURLWithPath: arguments[index + 1])
            }
        }
        _appState = StateObject(wrappedValue: AppState(testDirectory: testDirectory))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
                .background(Theme.background)
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) { }
            
            CommandGroup(after: .appInfo) {
                Button("Settings...") {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            
            CommandMenu("Navigation") {
                Button("Go to Parent Directory") {
                    NotificationCenter.default.post(name: .goToParent, object: nil)
                }
                .keyboardShortcut("h", modifiers: [])
                
                Button("Enter Directory") {
                    NotificationCenter.default.post(name: .enterDirectory, object: nil)
                }
                .keyboardShortcut("l", modifiers: [])
                
                Divider()
                
                Button("Switch Pane") {
                    NotificationCenter.default.post(name: .switchPane, object: nil)
                }
                .keyboardShortcut(.tab, modifiers: [])
            }
            
            CommandMenu("View") {
                Button("New Tab") {
                    NotificationCenter.default.post(name: .newTab, object: nil)
                }
                .keyboardShortcut("t", modifiers: [])
                
                Button("Close Tab") {
                    NotificationCenter.default.post(name: .closeTab, object: nil)
                }
                .keyboardShortcut("w", modifiers: [])
            }
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 配置窗口外观
        if let window = NSApp.windows.first {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.backgroundColor = NSColor(Theme.background)
            window.isMovableByWindowBackground = false
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let goToParent = Notification.Name("goToParent")
    static let enterDirectory = Notification.Name("enterDirectory")
    static let switchPane = Notification.Name("switchPane")
    static let newTab = Notification.Name("newTab")
    static let closeTab = Notification.Name("closeTab")
    static let openSettings = Notification.Name("openSettings")
}

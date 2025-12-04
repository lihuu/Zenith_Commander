//
//  Zenith_CommanderApp.swift
//  Zenith Commander
//
//  Created by Hu Li on 11/27/25.
//

import SwiftUI
import AppKit

// MARK: - 应用启动前的语言设置
/// 在应用启动前设置语言，确保系统菜单等也使用应用语言


@main
struct Zenith_CommanderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState: AppState
    @ObservedObject private var localizationManager = LocalizationManager.shared

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
    
    private func L(_ key: LocalizedStringKey) -> String {
        LocalizationManager.shared.localized(key)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
                .background(Theme.background)
                .environmentObject(appState)
                .id(localizationManager.currentLanguage.id)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) { }
            
            // 应用菜单（About/Settings/Hide/Quit）使用应用内语言
            CommandGroup(replacing: .appInfo) {
                Button(L(.menuAbout)) {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }
            
            CommandGroup(replacing: .appSettings) {
                Button(L(.menuSettings)) {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            
            CommandGroup(replacing: .appVisibility) {
                Button(L(.menuHide)) {
                    NSApp.hide(nil)
                }
                .keyboardShortcut("h", modifiers: .command)
                
                Button(L(.menuHideOthers)) {
                    NSApp.hideOtherApplications(nil)
                }
                .keyboardShortcut("h", modifiers: [.command, .option])
                
                Button(L(.menuShowAll)) {
                    NSApp.unhideAllApplications(nil)
                }
            }
            
            CommandGroup(replacing: .appTermination) {
                Button(L(.menuQuit)) {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            
            // 替换系统默认的 Edit 菜单（使用应用内语言设置）
            CommandGroup(replacing: .textEditing) { }
            CommandGroup(replacing: .pasteboard) {
                Button(L(.menuCut)) {
                    NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("x", modifiers: .command)
                
                Button(L(.menuCopy)) {
                    NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("c", modifiers: .command)
                
                Button(L(.menuPaste)) {
                    NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("v", modifiers: .command)
                
                Button(L(.menuSelectAll)) {
                    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("a", modifiers: .command)
            }
            
            CommandGroup(replacing: .undoRedo) {
                Button(L(.menuUndo)) {
                    NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
                }
                .keyboardShortcut("z", modifiers: .command)
                
                Button(L(.menuRedo)) {
                    NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }
            
            CommandMenu(L(.menuNavigation)) {
                Button(L(.goToParent)) {
                    NotificationCenter.default.post(name: .goToParent, object: nil)
                }
                .keyboardShortcut("h", modifiers: [])
                
                Button(L(.enterDirectory)) {
                    NotificationCenter.default.post(name: .enterDirectory, object: nil)
                }
                .keyboardShortcut("l", modifiers: [])
                
                Divider()
                
                Button(L(.switchPanes)) {
                    NotificationCenter.default.post(name: .switchPane, object: nil)
                }
                .keyboardShortcut(.tab, modifiers: [])
            }
            
            CommandMenu(L(.menuView)) {
                Button(L(.newTab)) {
                    NotificationCenter.default.post(name: .newTab, object: nil)
                }
                .keyboardShortcut("t", modifiers: [])
                
                Button(L(.closeTab)) {
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
            window.backgroundColor = NSColor(named: "BackgroundColor") ?? .windowBackgroundColor
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
    static let showHelp = Notification.Name("showHelp")
}

//
//  PluginManagerTests.swift
//  Zenith CommanderTests
//
//  Regression tests for the "Add AI Tool renders two AI Tools sections" bug.
//
//  Root cause: `MainView.init` calls `PluginManager.shared.register(...)` for every
//  plugin on each `MainView` creation. `MainView` is rebuilt whenever the language
//  changes (see `ContentView().id(localizationManager.currentLanguage.id)` in
//  `Zenith_CommanderApp.swift`). The old `register` always appended to
//  `settingsProviders`, so duplicates accumulated and the Settings page rendered
//  one extra "AI Tools" (and Git/Rsync/Fzf) section per rebuild.
//
//  Fix: `register` is now idempotent — a plugin with an already-registered id is
//  skipped. These tests pin that invariant.
//

import XCTest

@testable import Zenith_Commander

@MainActor
final class PluginManagerTests: XCTestCase {
    /// Two registrations of the same plugin must yield exactly one settings provider.
    func testRegisteringSamePluginTwiceDoesNotDuplicateSettingsProviders() {
        let manager = PluginManager.shared

        // Snapshot current counts so the test is isolated from whatever the
        // app startup has already registered.
        let initialCount = manager.allSettingsProviders().count

        let context = makeContext()
        manager.register(AIPlugin(), context: context)
        let firstCount = manager.allSettingsProviders().count

        manager.register(AIPlugin(), context: context)
        let secondCount = manager.allSettingsProviders().count

        XCTAssertEqual(
            firstCount - initialCount, 1,
            "First registration should add exactly one AI settings provider"
        )
        XCTAssertEqual(
            secondCount, firstCount,
            "Re-registering the same plugin must not append another settings provider"
        )
    }

    /// The AI settings provider must appear at most once regardless of how many
    /// `MainView`-style re-registrations happen across all plugins.
    func testAISettingsProviderAppearsOnceAfterRepeatedFullRegistration() {
        let manager = PluginManager.shared
        let context = makeContext()

        let initialAICount = manager.allSettingsProviders()
            .filter { $0.pluginId == "ai" }
            .count

        // Simulate MainView being rebuilt several times (e.g. language switches).
        for _ in 0..<5 {
            manager.register(AIPlugin(), context: context)
        }

        let finalAICount = manager.allSettingsProviders()
            .filter { $0.pluginId == "ai" }
            .count

        XCTAssertEqual(
            finalAICount, max(initialAICount, 1),
            "AI settings provider should never duplicate, regardless of repeated registrations"
        )
    }

    private func makeContext() -> PluginContext {
        PluginContext(
            panes: {
                PanesSnapshot(leftPath: "/tmp", rightPath: "/tmp", active: .left)
            },
            dispatch: { _ in },
            logger: .plugin,
            toolRunner: ProcessToolRunner()
        )
    }
}
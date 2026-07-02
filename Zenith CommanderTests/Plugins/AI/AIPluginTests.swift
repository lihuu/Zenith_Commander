//
//  AIPluginTests.swift
//  Zenith CommanderTests
//

import XCTest

@testable import Zenith_Commander

@MainActor
final class AIPluginTests: XCTestCase {
    private var previousSettings: AppSettings!

    override func setUp() {
        super.setUp()
        previousSettings = SettingsManager.shared.settings
        SettingsManager.shared.settings = .default
    }

    override func tearDown() {
        SettingsManager.shared.settings = previousSettings
        super.tearDown()
    }

    func testAIPluginInitialization() {
        let plugin = AIPlugin()

        XCTAssertEqual(plugin.id.rawValue, "ai")
        XCTAssertEqual(plugin.displayName, "AI")
        XCTAssertEqual(plugin.version, "1.0.0")
    }

    func testContextMenuProviderOnlyShowsDirectoryItems() {
        let provider = AIContextMenuProvider(
            context: makeContext(path: "/tmp/project"),
            settingsProvider: {
                AISettings(enabled: true, tools: [AIToolConfig.defaultTools[0]])
            },
            service: StubAIService(installedToolIDs: ["gemini"])
        )

        XCTAssertTrue(
            provider.menuItems(for: ContextMenuContext(placement: .fileItem)).isEmpty
        )

        let items = provider.menuItems(for: ContextMenuContext(placement: .directory))
        XCTAssertEqual(items.count, 2)

        guard case .item(let menuItem) = items[1] else {
            XCTFail("Expected a menu item")
            return
        }

        XCTAssertEqual(
            menuItem.title,
            LocalizationManager.shared.localized(.aiOpenToolHere, "Gemini")
        )
        XCTAssertTrue(menuItem.isEnabled)
    }

    func testContextMenuProviderDoesNotProbeToolInstallationDuringMenuConstruction() {
        let service = StubAIService(installedToolIDs: [])
        let provider = AIContextMenuProvider(
            context: makeContext(path: "/tmp/project"),
            settingsProvider: {
                AISettings(enabled: true, tools: [AIToolConfig.defaultTools[0]])
            },
            service: service
        )

        let items = provider.menuItems(for: ContextMenuContext(placement: .directory))

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(service.installationProbeCount, 0)
    }

    func testCommandProviderLaunchesRequestedTool() async throws {
        let service = StubAIService(installedToolIDs: ["gemini"])
        let provider = AICommandProvider(
            context: makeContext(path: "/tmp/project"),
            settingsProvider: {
                AISettings(enabled: true, tools: [AIToolConfig.defaultTools[0]])
            },
            service: service
        )

        let result = try await provider.invoke(
            CommandInvocation(name: "ai", args: ["gemini"])
        )

        guard case .message(let message) = result else {
            XCTFail("Expected a message result")
            return
        }

        XCTAssertEqual(service.openedTool?.id, "gemini")
        XCTAssertEqual(service.openedDirectory?.path, "/tmp/project")
        XCTAssertEqual(
            message,
            LocalizationManager.shared.localized(.aiOpenedTool, "Gemini")
        )
    }

    func testAppSettingsDecodeUsesDefaultAISettingsWhenMissing() throws {
        let json = """
            {
              "appearance": {
                "themeMode": "auto",
                "fontSize": 12,
                "lineHeight": 1.4
              },
              "terminal": {
                "defaultTerminal": "terminal"
              },
              "git": {
                "enabled": true,
                "showUntrackedFiles": true,
                "showIgnoredFiles": false
              },
              "rsync": {
                "enabled": true
              },
              "fzf": {
                "enabled": true
              }
            }
            """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(AppSettings.self, from: json)

        XCTAssertEqual(decoded.ai, .default)
    }

    private func makeContext(path: String) -> PluginContext {
        PluginContext(
            panes: {
                PanesSnapshot(leftPath: path, rightPath: "/tmp/other", active: .left)
            },
            dispatch: { _ in },
            logger: .plugin,
            toolRunner: ProcessToolRunner()
        )
    }
}

private final class StubAIService: AIServiceProviding {
    let installedToolIDs: Set<String>
    var openedTool: AIToolConfig?
    var openedDirectory: URL?
    private(set) var installationProbeCount = 0

    init(installedToolIDs: Set<String>) {
        self.installedToolIDs = installedToolIDs
    }

    func openToolInTerminal(tool: AIToolConfig, at directory: URL) throws {
        openedTool = tool
        openedDirectory = directory
    }

    func isToolInstalled(_ tool: AIToolConfig) -> Bool {
        installationProbeCount += 1
        return installedToolIDs.contains(tool.id)
    }

    func errorMessage(for error: Error, tool: AIToolConfig) -> String {
        LocalizationManager.shared.localized(.aiLaunchFailed, tool.displayName)
    }
}

//
//  GitPluginTests.swift
//  Zenith CommanderTests
//
//  Created by Hu Li on 12/22/25.
//

import XCTest

@testable import Zenith_Commander

class GitPluginTests: XCTestCase {
    private var previousEnv: AppEnvironment!

    override func setUp() {
        super.setUp()
        previousEnv = AppEnvironment.current

        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("zc-tests-\(UUID())")
        AppEnvironment.current = .test(tempRoot: base)
    }

    override func tearDown() {
        AppEnvironment.current = previousEnv
        super.tearDown()
    }

    func testPluginInitialization() {
        let plugin = GitPlugin()
        XCTAssertEqual(plugin.id.rawValue, "git")
        XCTAssertEqual(plugin.displayName, "Git")
        XCTAssertEqual(plugin.version, "1.0.0")
    }

    func testGitCommandProvider() {
        let plugin = GitPlugin()
        let toolRunner = ProcessToolRunner()
        let context = PluginContext(
            panes: {
                PanesSnapshot(leftPath: "/", rightPath: "/", active: .left)
            },
            dispatch: { _ in },
            logger: .plugin,
            toolRunner: toolRunner
        )

        let capabilities = plugin.makeCapabilities(context: context)
        guard
            let commandProvider = capabilities.first(where: {
                $0.type == .commandProvider
            })
                as? CommandProvider
        else {
            XCTFail("Command provider not found")
            return
        }

        XCTAssertTrue(commandProvider.commands.contains { $0.name == "git" })
    }

    func testGitUIContribution() {
        let plugin = GitPlugin()
        let toolRunner = ProcessToolRunner()
        let context = PluginContext(
            panes: {
                PanesSnapshot(leftPath: "/", rightPath: "/", active: .left)
            },
            dispatch: { _ in },
            logger: .plugin,
            toolRunner: toolRunner
        )

        let capabilities = plugin.makeCapabilities(context: context)
        guard
            let uiContribution = capabilities.first(where: {
                $0.type == .uiContribution
            })
                as? UIContribution
        else {
            XCTFail("UI contribution not found")
            return
        }

        // Test that it returns a view for gitPanel
        let view = uiContribution.makeView(for: .gitPanel)
        XCTAssertNotNil(view)

        // Test that it returns nil for other requests
        let otherView = uiContribution.makeView(for: .rsyncSheet)
        XCTAssertNil(otherView)
    }
}

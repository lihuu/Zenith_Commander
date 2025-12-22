//
//  GitPluginTests.swift
//  Zenith CommanderTests
//
//  Created by Hu Li on 12/22/25.
//

import XCTest
@testable import Zenith_Commander

class GitPluginTests: XCTestCase {
    
    func testPluginInitialization() {
        let plugin = GitPlugin()
        XCTAssertEqual(plugin.id.rawValue, "git")
        XCTAssertEqual(plugin.displayName, "Git")
        XCTAssertEqual(plugin.version, "1.0.0")
    }
    
    func testCapabilities() {
        let plugin = GitPlugin()
        let context = PluginContext(
            panes: { PanesSnapshot(leftPath: "/", rightPath: "/", active: .left) },
            dispatch: { _ in },
            logger: .plugin,
            toolRunner: ProcessToolRunner()
        )
        
        let capabilities = plugin.makeCapabilities(context: context)
        
        XCTAssertEqual(capabilities.count, 2)
        
        let hasCommandProvider = capabilities.contains { $0.type == .commandProvider }
        let hasUIContribution = capabilities.contains { $0.type == .uiContribution }
        
        XCTAssertTrue(hasCommandProvider)
        XCTAssertTrue(hasUIContribution)
    }
    
    func testGitCommandProvider() {
        let plugin = GitPlugin()
        let context = PluginContext(
            panes: { PanesSnapshot(leftPath: "/", rightPath: "/", active: .left) },
            dispatch: { _ in },
            logger: .plugin,
            toolRunner: ProcessToolRunner()
        )
        
        let capabilities = plugin.makeCapabilities(context: context)
        guard let commandProvider = capabilities.first(where: { $0.type == .commandProvider }) as? CommandProvider else {
            XCTFail("Command provider not found")
            return
        }
        
        XCTAssertTrue(commandProvider.commands.contains { $0.name == "git" })
    }
    
    func testGitUIContribution() {
        let plugin = GitPlugin()
        let context = PluginContext(
            panes: { PanesSnapshot(leftPath: "/", rightPath: "/", active: .left) },
            dispatch: { _ in },
            logger: .plugin,
            toolRunner: ProcessToolRunner()
        )
        
        let capabilities = plugin.makeCapabilities(context: context)
        guard let uiContribution = capabilities.first(where: { $0.type == .uiContribution }) as? UIContribution else {
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

//
//  FzfCommandProvider.swift
//  Zenith Commander
//
//  Command provider for fzf search
//

import Foundation

final class FzfCommandProvider: CommandProvider {
    private let context: PluginContext
    
    init(context: PluginContext) {
        self.context = context
    }
    
    var commands: [CommandSpec] {
        [CommandSpec(name: "fzf", help: "Fuzzy search files: fzf <pattern>")]
    }
    
    func invoke(_ command: CommandInvocation) async throws -> CommandResult {
        // Args contain the search pattern
        let pattern = command.args.joined(separator: " ")
        
        if pattern.isEmpty {
            // Open search sheet if no pattern provided
            await context.dispatch(.ui(.showSheet(.fzfPicker)))
            return .openUI(.fzfPicker)
        }
        
        // Execute search with pattern
        let panes = context.panes()
        let currentPath = panes.active == .left ? panes.leftPath : panes.rightPath
        let directory = URL(fileURLWithPath: currentPath)
        
        do {
            let results = try await FzfService.shared.search(
                pattern: pattern,
                directory: directory,
                recursive: true
            )
            
            if results.isEmpty {
                return .message("No matches found for: \(pattern)")
            }
            
            // Return message with count, results will be shown via sheet
            await context.dispatch(.ui(.showSheet(.fzfPicker)))
            return .message("Found \(results.count) matches")
        } catch {
            return .message("Search error: \(error.localizedDescription)")
        }
    }
}

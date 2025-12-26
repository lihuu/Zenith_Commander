//
//  GitKeybindingProvider.swift
//  Zenith Commander
//
//  Provides keybindings for Git plugin
//

import SwiftUI

struct GitKeybindingProvider: KeybindingProvider {
    let context: PluginContext

    var keybindings: [KeybindingDefinition] {
        [
            // Normal mode: Toggle Git history panel with 'g' + 'h'
            KeybindingDefinition(
                mode: .normal,
                keyChord: KeyChord("h", [.control]),
                action: .ui(.toggleGitPanel),
                description: "Toggle Git history panel"
            ),

            // Normal mode: Git status
            KeybindingDefinition(
                mode: .normal,
                keyChord: KeyChord("g", [.control, .shift]),
                action: .command(.runCommand("git status")),
                description: "Show Git status"
            ),
        ]
    }
}

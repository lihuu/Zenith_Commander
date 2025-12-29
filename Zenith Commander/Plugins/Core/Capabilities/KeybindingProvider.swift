//
//  KeybindingProvider.swift
//  Zenith Commander
//
//  Plugin capability for providing custom keybindings
//

import SwiftUI

/// Keybinding definition for a specific mode
struct KeybindingDefinition {
    let mode: AppMode
    let keyChord: KeyChord
    let action: AppAction
    let description: String?

    init(mode: AppMode, keyChord: KeyChord, action: AppAction, description: String? = nil) {
        self.mode = mode
        self.keyChord = keyChord
        self.action = action
        self.description = description
    }
}

/// Plugin capability that provides custom keybindings
protocol KeybindingProvider: PluginCapability {
    /// Returns all keybindings provided by this plugin
    var keybindings: [KeybindingDefinition] { get }
}

extension KeybindingProvider {
    var type: CapabilityType {
        .keybindingProvider
    }
}

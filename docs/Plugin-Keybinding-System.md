# Plugin Keybinding System

## Overview

The Plugin Keybinding System allows plugins to register custom keyboard shortcuts that integrate seamlessly with Zenith Commander's modal interface. Keybindings can be defined for different modes (Normal, Visual, Command, etc.) and are automatically merged with the application's core keybindings.

## Architecture

### Components

1. **KeybindingProvider**: Protocol that plugins implement to provide keybindings
2. **KeybindingDefinition**: Struct that defines a keybinding with mode, key chord, action, and optional description
3. **PluginManager**: Manages keybinding registration and retrieval
4. **AppMode+Keymaps**: Integrates plugin keybindings with core keymaps

### Key Files

- `Plugins/Core/Capabilities/KeybindingProvider.swift` - Protocol definition
- `Plugins/Core/PluginManager.swift` - Registration and management
- `Models/AppMode+Keymaps.swift` - Integration with mode keymaps

## Usage

### Creating a Keybinding Provider

```swift
import SwiftUI

struct MyPluginKeybindingProvider: KeybindingProvider {
    let context: PluginContext

    var keybindings: [KeybindingDefinition] {
        [
            // Normal mode keybinding
            KeybindingDefinition(
                mode: .normal,
                keyChord: KeyChord("m", [.command]),
                action: .custom(.myPluginAction),
                description: "Execute my plugin action"
            ),

            // Visual mode keybinding
            KeybindingDefinition(
                mode: .visual,
                keyChord: KeyChord("p", [.shift]),
                action: .ui(.showSheet(.mySheet)),
                description: "Show my plugin sheet"
            ),

            // Multi-modifier keybinding
            KeybindingDefinition(
                mode: .normal,
                keyChord: KeyChord("k", [.command, .shift]),
                action: .command(.runCommand("my-command")),
                description: "Run my custom command"
            )
        ]
    }
}
```

### Registering Keybindings in Plugin

```swift
struct MyPlugin: ZenithPlugin {
    let id = PluginID(rawValue: "my-plugin")
    let displayName = "My Plugin"
    let version = "1.0.0"

    func makeCapabilities(context: PluginContext) -> [any PluginCapability] {
        let keybindings = MyPluginKeybindingProvider(context: context)
        // ... other capabilities
        return [keybindings, /* other capabilities */]
    }
}
```

## Keybinding Definition

### KeybindingDefinition Properties

- **mode**: The AppMode in which this keybinding is active
  - `.normal`, `.visual`, `.command`, `.filter`, `.driveSelect`, etc.
- **keyChord**: The keyboard combination (key + modifiers)
  - Use `KeyChord(key, modifiers)` constructor
  - Available modifiers: `.command`, `.shift`, `.control`, `.option`
- **action**: The AppAction to execute
  - Can be any valid AppAction
  - Common actions: `.command()`, `.ui()`, `.file()`, `.pane()`, etc.
- **description**: Optional human-readable description
  - Used for help documentation and debugging

## Supported Modes

All AppMode values are supported:

- `.normal` - Default mode
- `.visual` - Visual selection mode
- `.command` - Command input mode
- `.filter` - Filter/search mode
- `.driveSelect` - Drive selection mode
- `.rename` - Single file rename mode
- `.batchRename` - Batch rename mode
- `.settings` - Settings view
- `.help` - Help view
- `.modal` - Modal dialogs

## Priority

Plugin keybindings have **higher priority** than core keybindings. If a plugin defines a keybinding that conflicts with a core keybinding, the plugin's binding will take precedence.

## Examples

### Example 1: Rsync Plugin

```swift
struct RsyncKeybindingProvider: KeybindingProvider {
    let context: PluginContext

    var keybindings: [KeybindingDefinition] {
        [
            KeybindingDefinition(
                mode: .normal,
                keyChord: KeyChord("S", [.shift]),
                action: .ui(.showSheet(.rsyncSheet)),
                description: "Open Rsync synchronization sheet"
            ),

            KeybindingDefinition(
                mode: .visual,
                keyChord: KeyChord("S", [.shift]),
                action: .ui(.showSheet(.rsyncSheet)),
                description: "Sync selected files with Rsync"
            )
        ]
    }
}
```

### Example 2: Git Plugin

```swift
struct GitKeybindingProvider: KeybindingProvider {
    let context: PluginContext

    var keybindings: [KeybindingDefinition] {
        [
            KeybindingDefinition(
                mode: .normal,
                keyChord: KeyChord("h", [.control]),
                action: .ui(.toggleGitPanel),
                description: "Toggle Git history panel"
            ),

            KeybindingDefinition(
                mode: .normal,
                keyChord: KeyChord("g", [.control, .shift]),
                action: .command(.runCommand("git status")),
                description: "Show Git status"
            )
        ]
    }
}
```

## Best Practices

1. **Use descriptive action names**: Make descriptions clear and concise
2. **Avoid conflicts**: Check existing keybindings before defining new ones
3. **Follow conventions**: Use familiar keybinding patterns when possible
4. **Mode-specific bindings**: Only bind keys in modes where they make sense
5. **Document keybindings**: Always provide descriptions for user reference

## API Reference

### KeybindingProvider Protocol

```swift
protocol KeybindingProvider: PluginCapability {
    var keybindings: [KeybindingDefinition] { get }
}
```

### KeybindingDefinition Struct

```swift
struct KeybindingDefinition {
    let mode: AppMode
    let keyChord: KeyChord
    let action: AppAction
    let description: String?
}
```

### PluginManager Methods

```swift
// Get keybindings for a specific mode
func keybindings(for mode: AppMode) -> [KeyChord: AppAction]

// Get all keybindings from all providers
func allKeybindings() -> [KeybindingDefinition]
```

## Testing

To test plugin keybindings:

1. Register your plugin with the PluginManager
2. Switch to the appropriate mode
3. Press the configured key combination
4. Verify the action is triggered

## Future Enhancements

- Visual keybinding configuration UI
- Keybinding conflict detection and warnings
- User-customizable keybindings
- Export/import keybinding profiles
- Keybinding documentation generator

//
//  ContextMenuProvider.swift
//  Zenith Commander
//
//  Plugin capability for providing context menu items
//

import SwiftUI

/// Context information for menu item evaluation
struct MenuContext: Sendable {
    /// Selected files in the current pane
    let selectedFiles: [FileItem]

    /// Current directory path
    let currentPath: URL

    /// Active pane side
    let activePaneSide: PaneSide

    /// Inactive pane path (for sync operations)
    let inactivePanePath: URL?
}

/// A single context menu item
struct ContextMenuItem: Identifiable {
    let id: String
    let title: String
    let icon: String?
    let isEnabled: Bool
    let action: @MainActor () async -> Void

    init(
        id: String,
        title: String,
        icon: String? = nil,
        isEnabled: Bool = true,
        action: @escaping @MainActor () async -> Void
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.isEnabled = isEnabled
        self.action = action
    }
}

/// Separator between menu sections
struct MenuSeparator: Identifiable {
    let id: String

    init(id: String = UUID().uuidString) {
        self.id = id
    }
}

/// Menu item or separator
enum MenuElement: Identifiable {
    case item(ContextMenuItem)
    case separator(MenuSeparator)

    var id: String {
        switch self {
        case .item(let item):
            return item.id
        case .separator(let sep):
            return sep.id
        }
    }
}

/// Plugin capability for providing context menu items
protocol ContextMenuProvider: PluginCapability {
    /// Returns menu items for the given context
    /// - Parameter context: Current selection and navigation context
    /// - Returns: Array of menu elements to display
    func menuItems(for context: MenuContext) -> [MenuElement]
}

extension ContextMenuProvider {
    var type: CapabilityType {
        .contextMenuProvider
    }
}

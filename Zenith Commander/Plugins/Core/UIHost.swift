//
//  UIHost.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/19/25.
//

import SwiftUI

struct PluginSheetHost: ViewModifier {
    @ObservedObject var appState: AppState
    let pluginManager: PluginManager

    func body(content: Content) -> some View {
        content
            .sheet(
                item: Binding(
                    get: { appState.activeSheet },
                    set: { newValue in
                        if newValue == nil { appState.activeSheet = nil }
                    }
                )
            ) { request in
                pluginManager.view(for: request)
                    ?? AnyView(Text("No UI for \(String(describing: request))"))
            }
    }
}

extension View {
    func pluginSheetHost(appState: AppState, pluginManager: PluginManager)
        -> some View
    {
        modifier(
            PluginSheetHost(appState: appState, pluginManager: pluginManager)
        )
    }
}

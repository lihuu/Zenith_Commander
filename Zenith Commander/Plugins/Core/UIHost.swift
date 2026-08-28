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
    let pluginContext: PluginContext

    func body(content: Content) -> some View {
        content
            .sheet(
                item: Binding(
                    get: { appState.activeSheet },
                    set: { newValue in
                        // SwiftUI 的 .sheet(item:) 期望 setter 同步反映新值，
                        // 故此处分支不能走 async dispatch。这里同步写 activeSheet
                        // 并调用 exitMode()，与 reducer 的 dismissSheet 行为对齐，
                        // 避免「sheet 关了但 mode 仍卡在 .modal」的不一致窗口。
                        // 打开分支由 dispatch(.ui(.showSheet)) 驱动，不在此处处理。
                        if newValue == nil {
                            appState.activeSheet = nil
                            appState.exitMode()
                        }
                    }
                )
            ) { request in
                (pluginManager.view(for: request)
                    ?? AnyView(Text("No UI for \(String(describing: request))")))
                    // 插件 sheet 同样是独立窗口，需要呈现面级 colorScheme 对齐
                    // （AGENTS.md §6：插件视图依赖根级对齐，不得自行 hack 原生控件颜色）。
                    .themeAlignedColorScheme()
            }
    }
}

extension View {

    func pluginSheetHost(
        appState: AppState, pluginContext: PluginContext, pluginManager: PluginManager
    )
        -> some View
    {
        modifier(
            PluginSheetHost(
                appState: appState,
                pluginManager: pluginManager,
                pluginContext: pluginContext
            )
        )
    }

}

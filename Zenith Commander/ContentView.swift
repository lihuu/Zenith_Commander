//
//  ContentView.swift
//  Zenith Commander
//
//  Created by Hu Li on 11/27/25.
//

import Foundation
import SwiftUI

// This file is kept for compatibility
// The main view is now in MainView.swift

struct ContentView: View {
    // 注入 ThemeManager，使根视图能根据 mode 切换 SwiftUI 原生控件的 colorScheme。
    // 这是修复「自定义背景 vs 原生控件（TextField/Form/Picker）颜色撕裂」的根治点：
    // 在根视图一次性对齐 colorScheme，所有子视图的原生控件都会跟随 ThemeManager.mode，
    // 无需在每个含原生控件的视图里单独 hack（单一运行时源原则，见 AGENTS.md §6）。
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        MainView()
            .preferredColorScheme(themeManager.preferredColorScheme)
    }
}

#Preview {
    ContentView()
        .frame(width: 1200, height: 800)
        .environmentObject(
            AppState(
                environment: .test(
                    tempRoot: FileManager.default.temporaryDirectory,
                    initPath: FileManager.default.temporaryDirectory
                )
            )
        )
}

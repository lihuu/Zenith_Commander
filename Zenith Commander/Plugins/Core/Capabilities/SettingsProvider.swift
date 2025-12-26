//
//  SettingsProvider.swift
//  Zenith Commander
//
//  插件设置能力 - 允许插件提供自定义设置界面
//

import SwiftUI

/// 设置提供者协议 - 插件实现此协议以提供设置界面
protocol SettingsProvider: PluginCapability {
    /// 插件的唯一标识符
    var pluginId: String { get }

    /// 设置区域的标题
    var settingsTitle: String { get }

    /// 设置区域的图标
    var settingsIcon: String { get }

    /// 创建设置视图
    /// - Returns: 设置界面的 SwiftUI 视图
    func settingsView() -> AnyView

    /// 插件设置的显示顺序（数值越小越靠前）
    var settingsOrder: Int { get }
}

extension SettingsProvider {
    var type: CapabilityType { .settingsProvider }

    /// 默认显示顺序为 100
    var settingsOrder: Int { 100 }
}

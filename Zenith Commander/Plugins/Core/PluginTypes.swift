//
//  PluginTypes.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/19/25.
//

import OSLog
import SwiftUI

struct PluginID: Hashable, Sendable {
    let rawValue: String
}

protocol ZenithPlugin {
    var id: PluginID { get }
    var displayName: String { get }
    var version: String { get }
    func makeCapabilities(context: PluginContext) -> [any PluginCapability]
}

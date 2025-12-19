//
//  PluginContext.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/19/25.
//

import OSLog
import SwiftUI

enum PaneID {
    case left, right
}

struct PanesSnapshot {
    let leftPath: String
    let rightPath: String
    let active: PaneID
}

public struct PluginContext {
    public let environment: EnvironmentValues

    let panes: @Sendable () -> PanesSnapshot
    let dispatch: @Sendable (AppAction) async -> Void
    public let logger: Logger

    let toolRunner: ToolRunner
}

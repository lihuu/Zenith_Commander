//
//  AISettings.swift
//  Zenith Commander
//
//  Settings model for AI tools plugin
//

import Foundation

struct AISettings: Codable, Equatable {
    var enabled: Bool
    var tools: [AIToolConfig]

    static var `default`: AISettings {
        AISettings(enabled: true, tools: AIToolConfig.defaultTools)
    }
}

//
//  PluginCapability.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/19/25.
//

protocol PluginCapability {
    var type: CapabilityType { get }
}

enum CapabilityType: String, CaseIterable {
    case commandProvider
    case toolRunner
    case uiContribution
}

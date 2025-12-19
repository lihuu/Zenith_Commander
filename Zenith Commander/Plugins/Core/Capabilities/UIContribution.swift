//
//  UIContribution.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/19/25.
//

import SwiftUI

enum UIRequest: Hashable {
    case rsyncSheet
    case gitPanel
    case fzfPicker
}

protocol UIContribution: PluginCapability {
    func makeView(for request: UIRequest) -> AnyView?
}

extension UIContribution {
    var type: CapabilityType {
        .uiContribution
    }
}

extension UIRequest: Identifiable {
    var id: String {
        switch self {
        case .rsyncSheet: "rsyncSheet"
        case .gitPanel: "gitPanel"
        case .fzfPicker: "fzfPicker"
        }
    }
}

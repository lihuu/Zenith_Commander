//
//  FzfUIContribution.swift
//  Zenith Commander
//
//  UI contribution for fzf search sheet
//

import SwiftUI

struct FzfUIContribution: UIContribution {
    let context: PluginContext
    
    func makeView(for request: UIRequest) -> AnyView? {
        switch request {
        case .fzfPicker:
            return AnyView(FzfSearchSheetView(context: context))
        default:
            return nil
        }
    }
}

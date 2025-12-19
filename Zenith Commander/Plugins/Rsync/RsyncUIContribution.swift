//
//  RsyncUIContribution.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/19/25.
//


import SwiftUI

final class RsyncUIContribution: UIContribution{
    
    private let viewFactory: (UIRequest) -> AnyView?
    
    init(viewFactory: @escaping (UIRequest) -> AnyView?) {
        self.viewFactory = viewFactory
    }
    
    func makeView(for request: UIRequest) -> AnyView? {
        viewFactory(request)
    }
}








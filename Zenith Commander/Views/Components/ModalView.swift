//
//  ModalView.swift
//  Zenith Commander
//
//  Created by Zenith Commander on 2025/12/05.
//

import SwiftUI

struct ModalView<Content: View>: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var appState: AppState
    let content: Content
    
    init(isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            if isPresented {
                // Background overlay
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        isPresented = false
                    }
                    .transition(.opacity)
                
                // Modal Content
                content
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                    .shadow(radius: 20)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                    .onAppear {
                        appState.enterMode(.modal)
                    }
                    .onDisappear {
                        appState.exitMode()
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isPresented)
        // Handle Esc key to close
        .background(
            Button("") {
                isPresented = false
            }
            .keyboardShortcut(.cancelAction)
            .opacity(0)
        )
    }
}

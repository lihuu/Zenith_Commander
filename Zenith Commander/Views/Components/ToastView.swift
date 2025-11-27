//
//  ToastView.swift
//  Zenith Commander
//
//  Toast 通知组件
//

import SwiftUI

struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.85))
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

/// Toast 修饰器
struct ToastModifier: ViewModifier {
    let message: String?
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if let message = message {
                VStack {
                    ToastView(message: message)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 50)
                    Spacer()
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: message)
            }
        }
    }
}

extension View {
    func toast(message: String?) -> some View {
        modifier(ToastModifier(message: message))
    }
}

#Preview {
    ZStack {
        Theme.background
        ToastView(message: "3 files copied")
    }
    .frame(width: 400, height: 200)
}

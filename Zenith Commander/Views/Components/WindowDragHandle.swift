//
//  WindowDragHandle.swift
//  Zenith Commander
//
//  用于窗口拖动的视图组件
//  替代 isMovableByWindowBackground = true，仅在特定区域允许拖动窗口
//

import SwiftUI
import AppKit

/// 一个不可见的视图，用于响应窗口拖动事件
struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = DraggableView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    class DraggableView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        
        override func hitTest(_ point: NSPoint) -> NSView? {
            // 只有当鼠标点击在这个视图范围内时，才允许拖动
            // 如果上层有其他交互元素（如按钮），它们会优先捕获事件（如果它们在层级上更高）
            // 但在这里，我们通常作为背景使用，所以只需确保我们能接收到事件
            let view = super.hitTest(point)
            return view == self ? self : nil
        }
    }
}

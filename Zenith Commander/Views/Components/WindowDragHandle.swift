//
//  WindowDragHandle.swift
//  Zenith Commander
//
//  用于窗口拖动的视图组件
//  替代 isMovableByWindowBackground = true，仅在特定区域允许拖动窗口
//  支持双击最大化/还原窗口（macOS 标准行为）
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
            let view = super.hitTest(point)
            return view == self ? self : nil
        }
        
        override func mouseDown(with event: NSEvent) {
            // 检测双击
            if event.clickCount == 2 {
                // 双击标题栏区域时，执行 zoom（最大化/还原）
                self.window?.zoom(nil)
            } else {
                super.mouseDown(with: event)
            }
        }
    }
}

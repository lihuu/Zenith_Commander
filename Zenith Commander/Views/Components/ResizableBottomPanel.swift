//
//  ResizableBottomPanel.swift
//  Zenith Commander
//
//  可调整大小的底部面板容器
//

import SwiftUI

/// 可调整大小的底部面板容器 - 优化拖动性能
struct ResizableBottomPanel<Content: View>: View {
    @Binding var height: CGFloat
    @Binding var isVisible: Bool
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let content: () -> Content

    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0
    @GestureState private var dragState: CGFloat = 0

    // 计算实际显示高度：基础高度 + 拖动偏移
    private var displayHeight: CGFloat {
        let newHeight = height - dragState
        return min(max(newHeight, minHeight), maxHeight)
    }

    var body: some View {
        if isVisible {
            VStack(spacing: 0) {
                // 拖动手柄
                dragHandle

                // 内容 - 使用 displayHeight 实现流畅拖动
                content()
                    .frame(height: displayHeight)
            }

            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var dragHandle: some View {
        Rectangle()
            .fill(isDragging ? Theme.accent : Theme.border)
            .frame(height: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.textTertiary)
                    .frame(width: 40, height: 3)
            )
            .frame(maxWidth: .infinity)
            .frame(height: 12)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .updating($dragState) { value, state, _ in
                        state = value.translation.height
                    }
                    .onChanged { _ in
                        if !isDragging {
                            isDragging = true
                        }
                    }
                    .onEnded { value in
                        // 拖动结束时更新实际高度
                        let newHeight = height - value.translation.height
                        height = min(max(newHeight, minHeight), maxHeight)
                        isDragging = false
                    }
            )
            .onHover { isHovered in
                if isHovered {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

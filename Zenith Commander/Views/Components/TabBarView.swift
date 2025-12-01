//
//  TabBarView.swift
//  Zenith Commander
//
//  标签栏组件
//

import SwiftUI

struct TabBarView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject var pane: PaneState
    let isActivePane: Bool
    let onTabSwitch: (Int) -> Void
    let onTabClose: (Int) -> Void
    let onTabAdd: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // 标签页列表
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(pane.tabs.enumerated()), id: \.element.id) { index, tab in
                        TabItemView(
                            tab: tab,
                            isActive: index == pane.activeTabIndex,
                            isPaneActive: isActivePane,
                            onSelect: { onTabSwitch(index) },
                            onClose: { onTabClose(index) }
                        )
                    }
                }
            }
            
            // 添加标签按钮
            Button(action: onTabAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.textTertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            
            Spacer()
        }
        .frame(height: 28)
        .background(WindowDragHandle())
        .background(Theme.backgroundSecondary)
        .opacity(isActivePane ? 1.0 : 0.7)
    }
}

struct TabItemView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    let tab: TabState
    let isActive: Bool
    let isPaneActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 6) {
            Text(tab.directoryName)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundColor(textColor)
                .lineLimit(1)
            
            // 关闭按钮
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(closeButtonColor)
            }
            .buttonStyle(.plain)
            .opacity(isHovering || isActive ? 1 : 0)
            .frame(width: 14, height: 14)
            .background(isHovering ? Theme.backgroundElevated : .clear)
            .cornerRadius(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(minWidth: 80, maxWidth: 150)
        .background(backgroundColor)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Theme.border),
            alignment: .trailing
        )
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    private var backgroundColor: Color {
        if isActive {
            return Theme.background
        }
        return isHovering ? Theme.backgroundTertiary : Theme.backgroundSecondary
    }
    
    private var textColor: Color {
        if isActive && isPaneActive {
            return Theme.accent
        }
        return isActive ? Theme.textPrimary : Theme.textSecondary
    }
    
    private var closeButtonColor: Color {
        isHovering ? Theme.textPrimary : Theme.textTertiary
    }
}

#Preview {
    let pane = PaneState(
        side: .left,
        initialPath: URL(fileURLWithPath: "/Users"),
        drive: DriveInfo(id: "1", name: "Macintosh HD", path: URL(fileURLWithPath: "/"), type: .system, totalCapacity: 0, availableCapacity: 0)
    )
    
    return TabBarView(
        pane: pane,
        isActivePane: true,
        onTabSwitch: { _ in },
        onTabClose: { _ in },
        onTabAdd: { }
    )
    .frame(width: 400)
    .background(Theme.background)
}

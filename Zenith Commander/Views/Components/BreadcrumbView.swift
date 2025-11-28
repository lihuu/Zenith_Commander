//
//  BreadcrumbView.swift
//  Zenith Commander
//
//  面包屑导航组件
//

import SwiftUI

struct BreadcrumbView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    let tab: TabState
    let isActivePane: Bool
    let onNavigate: (URL) -> Void
    let onDriveClick: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            // 驱动器/卷图标
            Button(action: onDriveClick) {
                HStack(spacing: 4) {
                    Image(systemName: tab.drive.iconName)
                        .font(.system(size: 11))
                    Text(tab.drive.name)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(isActivePane ? Theme.textSecondary : Theme.textTertiary)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            
            // 路径分隔符
            if !tab.pathComponents.isEmpty {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Theme.textMuted)
            }
            
            // 路径组件
            ForEach(Array(tab.pathComponents.enumerated()), id: \.offset) { index, component in
                Button(action: {
                    navigateToPathComponent(index)
                }) {
                    Text(component)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(pathColor(for: index))
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                
                // 分隔符
                if index < tab.pathComponents.count - 1 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Theme.textMuted)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
    
    private func pathColor(for index: Int) -> Color {
        let isLast = index == tab.pathComponents.count - 1
        if isLast && isActivePane {
            return Theme.textPrimary
        }
        return isActivePane ? Theme.textSecondary : Theme.textTertiary
    }
    
    private func navigateToPathComponent(_ index: Int) {
        // 构建到指定组件的路径
        var path = tab.drive.path
        for i in 0...index {
            path = path.appendingPathComponent(tab.pathComponents[i])
        }
        onNavigate(path)
    }
}

#Preview {
    let drive = DriveInfo(id: "1", name: "Macintosh HD", path: URL(fileURLWithPath: "/"), type: .system, totalCapacity: 0, availableCapacity: 0)
    let tab = TabState(drive: drive, path: URL(fileURLWithPath: "/Users/test/Documents"))
    
    return BreadcrumbView(
        tab: tab,
        isActivePane: true,
        onNavigate: { _ in },
        onDriveClick: { }
    )
    .background(Theme.background)
}

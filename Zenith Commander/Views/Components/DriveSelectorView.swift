//
//  DriveSelectorView.swift
//  Zenith Commander
//
//  驱动器选择悬浮层
//

import SwiftUI

struct DriveSelectorView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    let drives: [DriveInfo]
    let cursorIndex: Int
    let onSelect: (DriveInfo) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 12))
                Text("Select Drive")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("ESC to close")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
            }
            .foregroundColor(Theme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.backgroundTertiary)
            
            Divider()
                .background(Theme.border)
            
            // 驱动器列表
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Array(drives.enumerated()), id: \.element.id) { index, drive in
                        DriveRowView(
                            drive: drive,
                            isSelected: index == cursorIndex,
                            onSelect: { onSelect(drive) }
                        )
                    }
                }
                .padding(8)
            }
        }
        .frame(width: 320, height: min(CGFloat(drives.count * 60 + 60), 400))
        .background(Theme.backgroundSecondary)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.borderLight, lineWidth: 1)
        )
    }
}

struct DriveRowView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    let drive: DriveInfo
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: drive.iconName)
                .font(.system(size: 24))
                .foregroundColor(iconColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                // 名称
                Text(drive.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : Theme.textPrimary)
                
                // 容量信息
                HStack(spacing: 4) {
                    // 进度条
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.backgroundElevated)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(progressColor)
                                .frame(width: geo.size.width * drive.usedPercentage / 100)
                        }
                    }
                    .frame(width: 60, height: 4)
                    
                    Text(drive.formattedCapacity)
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? Theme.textSecondary : Theme.textTertiary)
                }
            }
            
            Spacer()
            
            // 类型标签
            Text(driveTypeLabel)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(isSelected ? .white.opacity(0.7) : Theme.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(isSelected ? Color.white.opacity(0.2) : Theme.backgroundTertiary)
                .cornerRadius(3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundColor)
        .cornerRadius(6)
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Theme.selection
        }
        return isHovering ? Theme.backgroundTertiary : .clear
    }
    
    private var iconColor: Color {
        switch drive.type {
        case .system:
            return Theme.accent
        case .external:
            return Theme.folder
        case .network:
            return Theme.info
        case .removable:
            return Theme.warning
        }
    }
    
    private var progressColor: Color {
        if drive.usedPercentage > 90 {
            return Theme.error
        } else if drive.usedPercentage > 75 {
            return Theme.warning
        }
        return Theme.success
    }
    
    private var driveTypeLabel: String {
        switch drive.type {
        case .system: return "System"
        case .external: return "External"
        case .network: return "Network"
        case .removable: return "Removable"
        }
    }
}

#Preview {
    ZStack {
        Theme.background
        
        DriveSelectorView(
            drives: [
                DriveInfo(id: "1", name: "Macintosh HD", path: URL(fileURLWithPath: "/"), type: .system, totalCapacity: 1000000000000, availableCapacity: 500000000000),
                DriveInfo(id: "2", name: "Samsung T7", path: URL(fileURLWithPath: "/Volumes/T7"), type: .external, totalCapacity: 2000000000000, availableCapacity: 800000000000),
                DriveInfo(id: "3", name: "NAS", path: URL(fileURLWithPath: "/Volumes/NAS"), type: .network, totalCapacity: 12000000000000, availableCapacity: 3000000000000)
            ],
            cursorIndex: 0,
            onSelect: { _ in },
            onDismiss: { }
        )
    }
    .frame(width: 600, height: 500)
}

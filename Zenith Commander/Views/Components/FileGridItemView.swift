//
//  FileGridItemView.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/7/25.
//


import SwiftUI

struct FileGridItemView: View {
    let file: FileItem
    let isActive: Bool
    let isSelected: Bool
    let isPaneActive: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            // 图标
            AsyncIconView(
                url: file.path,
                type: file.type,
                iconName: file.iconName,
                size: 48
            )
            .foregroundColor(iconColor)
            .frame(width: 48, height: 48)
            
            // 文件名
            Text(file.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(textColor)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 28)
        }
        .frame(width: 90, height: 100)
        .background(backgroundColor)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(borderColor, lineWidth: isActive ? 2 : 0)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("file_grid_item_\(file.name)")
        .accessibilityLabel(file.name)
        .accessibilityValue(
            (isActive ? "focused" : "") +
            (isSelected ? ", selected" : "")
        )
        .draggable(file.path) {
            // 拖动预览
            HStack(spacing: 6) {
                Image(systemName: file.type == .folder ? "folder.fill" : "doc.fill")
                    .foregroundColor(file.type == .folder ? Theme.folder : Theme.file)
                Text(file.name)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.backgroundSecondary)
            .cornerRadius(6)
        }
    }
    
    private var backgroundColor: Color {
        if isActive && isPaneActive {
            return Theme.selection
        } else if isSelected {
            return Theme.selection.opacity(0.5)
        }
        return Theme.backgroundSecondary.opacity(0.5)
    }
    
    private var borderColor: Color {
        if isActive {
            return isPaneActive ? Theme.accent : Theme.accent.opacity(0.5)
        }
        return .clear
    }
    
    private var iconColor: Color {
        file.type == .folder ? Theme.folder : Theme.file
    }
    
    private var textColor: Color {
        if isActive && isPaneActive {
            return .white
        } else if isSelected {
            return Theme.accent
        }
        return Theme.textPrimary
    }
}
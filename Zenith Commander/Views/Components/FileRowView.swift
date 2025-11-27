//
//  FileRowView.swift
//  Zenith Commander
//
//  文件行视图组件
//

import SwiftUI

struct FileRowView: View {
    let file: FileItem
    let isActive: Bool       // 光标所在
    let isSelected: Bool     // 被选中
    let isPaneActive: Bool   // 面板是否激活
    
    var body: some View {
        HStack(spacing: 8) {
            // 文件图标
            Image(systemName: file.iconName)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(iconColor)
                .frame(width: 18)
            
            // 文件名
            Text(file.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(textColor)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            // 文件大小
            Text(file.formattedSize)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(sizeColor)
                .frame(width: 70, alignment: .trailing)
            
            // 修改日期
            Text(file.formattedDate)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(dateColor)
                .frame(width: 120, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .overlay(
            // 光标边框（非活动面板时显示空心框）
            RoundedRectangle(cornerRadius: 4)
                .stroke(cursorBorderColor, lineWidth: isActive && !isPaneActive ? 1 : 0)
                .padding(1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("file_row_\(file.name)")
        .accessibilityLabel(file.name)
        .accessibilityValue(
            "\(file.formattedSize), \(file.formattedDate)" +
            (isActive ? ", focused" : "") +
            (isSelected ? ", selected" : "")
        )
    }
    
    // MARK: - 颜色计算
    
    private var backgroundColor: Color {
        if isActive && isPaneActive {
            return Theme.selection
        } else if isActive && !isPaneActive {
            return Theme.selectionInactive.opacity(0.3)
        } else if isSelected {
            return Theme.selection.opacity(0.5)
        }
        return .clear
    }
    
    private var cursorBorderColor: Color {
        if isActive && !isPaneActive {
            return Theme.accent.opacity(0.5)
        }
        return .clear
    }
    
    private var iconColor: Color {
        switch file.type {
        case .folder:
            return Theme.folder
        case .file:
            return colorForExtension(file.fileExtension)
        default:
            return Theme.file
        }
    }
    
    private var textColor: Color {
        if isActive && isPaneActive {
            return .white
        } else if isSelected {
            return Theme.accent
        }
        return Theme.textPrimary
    }
    
    private var sizeColor: Color {
        isActive && isPaneActive ? Theme.textPrimary : Theme.textTertiary
    }
    
    private var dateColor: Color {
        isActive && isPaneActive ? Theme.textSecondary : Theme.textTertiary
    }
    
    private func colorForExtension(_ ext: String) -> Color {
        switch ext.lowercased() {
        case "swift", "m", "h", "c", "cpp", "py", "js", "ts", "java", "rb", "go", "rs":
            return Theme.code
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp", "svg":
            return Theme.image
        case "mp4", "mov", "avi", "mkv", "wmv":
            return Theme.video
        case "mp3", "wav", "aac", "flac", "m4a":
            return Theme.audio
        case "zip", "tar", "gz", "rar", "7z":
            return Theme.archive
        default:
            return Theme.file
        }
    }
}

// MARK: - 网格视图
struct FileGridItemView: View {
    let file: FileItem
    let isActive: Bool
    let isSelected: Bool
    let isPaneActive: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            // 图标
            Image(systemName: file.iconName)
                .font(.system(size: 32, weight: .light))
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

#Preview {
    VStack(spacing: 0) {
        FileRowView(
            file: FileItem(
                id: "1",
                name: "Documents",
                path: URL(fileURLWithPath: "/Users/test/Documents"),
                type: .folder,
                size: 0,
                modifiedDate: Date(),
                createdDate: Date(),
                isHidden: false,
                permissions: "755",
                fileExtension: ""
            ),
            isActive: true,
            isSelected: false,
            isPaneActive: true
        )
        
        FileRowView(
            file: FileItem(
                id: "2",
                name: "test.swift",
                path: URL(fileURLWithPath: "/Users/test/test.swift"),
                type: .file,
                size: 1024,
                modifiedDate: Date(),
                createdDate: Date(),
                isHidden: false,
                permissions: "644",
                fileExtension: "swift"
            ),
            isActive: false,
            isSelected: true,
            isPaneActive: true
        )
    }
    .background(Theme.background)
}

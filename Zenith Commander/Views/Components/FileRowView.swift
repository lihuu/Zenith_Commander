//
//  FileRowView.swift
//  Zenith Commander
//
//  文件行视图组件
//

import SwiftUI

/// 优化的文件行视图 - 使用 Equatable 减少不必要的重绘
struct FileRowView: View, Equatable {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    let file: FileItem
    let isActive: Bool       // 光标所在
    let isSelected: Bool     // 被选中
    let isPaneActive: Bool   // 面板是否激活
    let rowIndex: Int        // 行索引，用于斑马条纹（可选）
    
    init(file: FileItem, isActive: Bool, isSelected: Bool, isPaneActive: Bool, rowIndex: Int = 0) {
        self.file = file
        self.isActive = isActive
        self.isSelected = isSelected
        self.isPaneActive = isPaneActive
        self.rowIndex = rowIndex
    }
    
    // 实现 Equatable 以优化重绘
    static func == (lhs: FileRowView, rhs: FileRowView) -> Bool {
        lhs.file.id == rhs.file.id &&
        lhs.file.name == rhs.file.name &&
        lhs.file.gitStatus == rhs.file.gitStatus &&
        lhs.isActive == rhs.isActive &&
        lhs.isSelected == rhs.isSelected &&
        lhs.isPaneActive == rhs.isPaneActive &&
        lhs.rowIndex == rhs.rowIndex
    }
    
    // 基于设置的字体大小计算
    private var baseFontSize: CGFloat {
        CGFloat(settingsManager.settings.appearance.fontSize)
    }
    
    // 基于设置的行高计算
    private var lineHeight: CGFloat {
        CGFloat(settingsManager.settings.appearance.lineHeight)
    }
    
    private var iconSize: CGFloat { baseFontSize + 1 }
    private var nameSize: CGFloat { baseFontSize }
    private var detailSize: CGFloat { max(baseFontSize - 2, 9) }
    
    // 行内垂直间距基于行高设置计算
    // lineHeight 1.0 = 紧凑, 1.4 = 默认, 2.0 = 宽松
    private var rowPadding: CGFloat {
        let baseRowHeight = baseFontSize * lineHeight
        let textHeight = baseFontSize
        return max((baseRowHeight - textHeight) / 2, 2)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // 文件图标 (异步加载)
            AsyncIconView(
                url: file.path,
                type: file.type,
                iconName: file.iconName,
                size: baseFontSize + 4
            )
            .foregroundColor(iconColor) // Apply color to fallback SF Symbol
            .frame(width: baseFontSize + 4, height: baseFontSize + 4)
            
            // 文件名
            Text(file.name)
                .font(.system(size: nameSize, weight: .medium))
                .foregroundColor(textColor)
                .lineLimit(1)
                .truncationMode(.middle)
            
            // Git 状态标记
            if settingsManager.settings.git.enabled && file.gitStatus.shouldDisplay {
                Text(file.gitStatus.displayText)
                    .font(.system(size: detailSize, weight: .bold, design: .monospaced))
                    .foregroundColor(file.gitStatus.color)
                    .frame(width: 16)
            }
            
            Spacer()
            
            // 文件大小
            Text(file.formattedSize)
                .font(.system(size: detailSize, weight: .regular, design: .monospaced))
                .foregroundColor(sizeColor)
                .frame(width: 70, alignment: .trailing)
            
            // 修改日期
            Text(file.formattedDate)
                .font(.system(size: detailSize, weight: .regular))
                .foregroundColor(dateColor)
                .frame(width: 120, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, rowPadding)
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

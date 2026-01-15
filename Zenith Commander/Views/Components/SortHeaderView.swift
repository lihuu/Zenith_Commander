//
//  SortHeaderView.swift
//  Zenith Commander
//
//  排序列标题视图
//

import SwiftUI

/// 排序列标题视图 - 显示在列表视图顶部
struct SortHeaderView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var settingsManager = SettingsManager.shared
    @Binding var sortOption: SortOption
    
    // 基于设置的字体大小计算
    private var baseFontSize: CGFloat {
        CGFloat(settingsManager.settings.appearance.fontSize)
    }
    
    private var detailSize: CGFloat { max(baseFontSize - 2, 9) }
    
    var body: some View {
        HStack(spacing: 8) {
            // 文件图标占位（与 FileRowView 对齐）
            Color.clear
                .frame(width: baseFontSize + 4, height: baseFontSize + 4)
            
            // 名称列标题
            Button(action: {
                sortOption = sortOption.toggled(to: .name)
            }) {
                HStack(spacing: 4) {
                    Text("Name")
                        .font(.system(size: detailSize, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    
                    if sortOption.field == .name {
                        Text(sortOption.order.indicator)
                            .font(.system(size: detailSize - 2))
                            .foregroundColor(Theme.accent)
                    }
                }
            }
            .buttonStyle(.plain)
            .help("Sort by name")
            
            Spacer()
            
            // Git 状态列占位（如果启用）
            if settingsManager.settings.git.enabled {
                Color.clear
                    .frame(width: 16)
            }
            
            // 文件大小列标题
            Button(action: {
                sortOption = sortOption.toggled(to: .size)
            }) {
                HStack(spacing: 4) {
                    Text("Size")
                        .font(.system(size: detailSize, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    
                    if sortOption.field == .size {
                        Text(sortOption.order.indicator)
                            .font(.system(size: detailSize - 2))
                            .foregroundColor(Theme.accent)
                    }
                }
            }
            .buttonStyle(.plain)
            .help("Sort by size")
            .frame(width: 70, alignment: .trailing)
            
            // 修改日期列标题
            Button(action: {
                sortOption = sortOption.toggled(to: .modifiedDate)
            }) {
                HStack(spacing: 4) {
                    Text("Date")
                        .font(.system(size: detailSize, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    
                    if sortOption.field == .modifiedDate {
                        Text(sortOption.order.indicator)
                            .font(.system(size: detailSize - 2))
                            .foregroundColor(Theme.accent)
                    }
                }
            }
            .buttonStyle(.plain)
            .help("Sort by modification date")
            .frame(width: 120, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Theme.backgroundSecondary)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Theme.borderLight),
            alignment: .bottom
        )
    }
}

#Preview {
    VStack(spacing: 0) {
        SortHeaderView(sortOption: .constant(.default))
        
        SortHeaderView(sortOption: .constant(SortOption(field: .size, order: .descending)))
    }
    .background(Theme.background)
    .frame(width: 600)
}

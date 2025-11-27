//
//  PermissionRequestView.swift
//  Zenith Commander
//
//  权限请求视图组件
//

import SwiftUI

/// 权限请求视图 - 当无法访问目录时显示
struct PermissionRequestView: View {
    let path: URL
    let onRequestAccess: () -> Void
    let onOpenSettings: () -> Void
    let onGoBack: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // 图标
            Image(systemName: "lock.shield")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.warning, Theme.error],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 标题
            Text("Permission Required")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            
            // 路径显示
            VStack(spacing: 4) {
                Text("Cannot access folder:")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
                
                Text(path.path)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // 说明文本
            Text("Zenith Commander needs permission to access this folder.\nYou can grant access or open System Settings.")
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // 按钮组
            VStack(spacing: 10) {
                // 主要按钮 - 授权访问
                Button(action: onRequestAccess) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 13))
                        Text("Grant Folder Access")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: 200, height: 32)
                    .background(Theme.accent)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                // 次要按钮 - 打开系统设置
                Button(action: onOpenSettings) {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12))
                        Text("Open System Settings")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 200, height: 28)
                    .background(Theme.backgroundTertiary)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Theme.borderLight, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                // 返回按钮
                Button(action: onGoBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Go Back")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            
            Spacer()
            
            // 底部提示
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                Text("Press 'h' to go back to parent directory")
                    .font(.system(size: 10))
            }
            .foregroundColor(Theme.textMuted)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}

/// 权限错误横幅 - 在文件列表顶部显示
struct PermissionErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    let onRequestAccess: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(Theme.warning)
            
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
            
            Spacer()
            
            Button(action: onRequestAccess) {
                Text("Grant Access")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.accent)
            }
            .buttonStyle(.plain)
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.warning.opacity(0.15))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Theme.warning.opacity(0.3)),
            alignment: .bottom
        )
    }
}

#Preview {
    PermissionRequestView(
        path: URL(fileURLWithPath: "/Users/test/Documents"),
        onRequestAccess: { },
        onOpenSettings: { },
        onGoBack: { }
    )
    .frame(width: 400, height: 500)
}

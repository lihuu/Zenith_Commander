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
    
    /// 判断当前路径是否为远程路径（SFTP等）
    private var isRemotePath: Bool {
        !tab.currentPath.isFileURL
    }
    
    /// 获取远程连接的显示名称
    private var remoteHostName: String {
        if let host = tab.currentPath.host {
            if let user = tab.currentPath.user {
                return "\(user)@\(host)"
            }
            return host
        }
        return "Remote"
    }
    
    /// 获取远程路径的组件（不包含根目录的 /）
    private var remotePathComponents: [String] {
        var components = tab.currentPath.pathComponents
        // 移除第一个 "/"
        if components.first == "/" {
            components.removeFirst()
        }
        return components
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if isRemotePath {
                // 远程连接显示
                remoteConnectionHeader
            } else {
                // 本地驱动器显示
                localDriveHeader
            }
            
            // 路径分隔符
            let pathComps = isRemotePath ? remotePathComponents : tab.pathComponents
            if !pathComps.isEmpty {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Theme.textMuted)
            }
            
            // 路径组件
            ForEach(Array(pathComps.enumerated()), id: \.offset) { index, component in
                Button(action: {
                    navigateToPathComponent(index, components: pathComps)
                }) {
                    Text(component)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(pathColor(for: index, total: pathComps.count))
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
                if index < pathComps.count - 1 {
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
    
    // MARK: - 远程连接头部
    
    private var remoteConnectionHeader: some View {
        Button(action: {
            // 点击远程主机名时，导航到远程根目录
            navigateToRemoteRoot()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "network")
                    .font(.system(size: 11))
                Text(remoteHostName)
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
    }
    
    // MARK: - 本地驱动器头部
    
    private var localDriveHeader: some View {
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
    }
    
    private func pathColor(for index: Int, total: Int) -> Color {
        let isLast = index == total - 1
        if isLast && isActivePane {
            return Theme.textPrimary
        }
        return isActivePane ? Theme.textSecondary : Theme.textTertiary
    }
    
    private func navigateToPathComponent(_ index: Int, components: [String]) {
        if isRemotePath {
            // 对于远程路径，使用当前URL的scheme、host、port等信息构建新URL
            var urlComponents = URLComponents()
            urlComponents.scheme = tab.currentPath.scheme
            urlComponents.host = tab.currentPath.host
            urlComponents.port = tab.currentPath.port
            urlComponents.user = tab.currentPath.user
            urlComponents.password = tab.currentPath.password
            
            // 构建路径
            let pathParts = Array(components.prefix(index + 1))
            urlComponents.path = "/" + pathParts.joined(separator: "/")
            
            if let newURL = urlComponents.url {
                onNavigate(newURL)
            }
        } else {
            // 本地路径：使用原来的逻辑
            var path = tab.drive.path
            for i in 0...index {
                path = path.appendingPathComponent(components[i])
            }
            onNavigate(path)
        }
    }
    
    private func navigateToRemoteRoot() {
        // 导航到远程根目录
        var urlComponents = URLComponents()
        urlComponents.scheme = tab.currentPath.scheme
        urlComponents.host = tab.currentPath.host
        urlComponents.port = tab.currentPath.port
        urlComponents.user = tab.currentPath.user
        urlComponents.password = tab.currentPath.password
        urlComponents.path = "/"
        
        if let rootURL = urlComponents.url {
            onNavigate(rootURL)
        }
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

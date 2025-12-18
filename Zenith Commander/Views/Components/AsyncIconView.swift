//
//  AsyncIconView.swift
//  Zenith Commander
//
//  异步加载文件图标的视图
//

import SwiftUI
import AppKit

/// 异步图标视图
/// 在后台线程加载系统图标，避免阻塞主线程
struct AsyncIconView: View, Equatable {
    let url: URL
    let type: FileType
    let iconName: String // fallback SF Symbol name
    let size: CGFloat
    
    @State private var iconImage: NSImage?

    // Simple in-memory cache to avoid refetching icons and prevent double-refresh flashes
    private static let iconCache = NSCache<NSString, NSImage>()
    
    static func == (lhs: AsyncIconView, rhs: AsyncIconView) -> Bool {
        lhs.url == rhs.url && lhs.size == rhs.size
    }
    
    var body: some View {
        Group {
            if let image = iconImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // 不显示占位符，保持透明直到系统图标加载完成
                Color.clear
            }
        }
        .frame(width: size, height: size)
        .task(id: url) { // Use .task to load asynchronously when view appears
            await loadIcon()
        }
    }
    
    private func loadIcon() async {
        // Avoid reloading if already loaded
        if iconImage != nil { return }

        if let cached = AsyncIconView.iconCache.object(forKey: url.path as NSString) {
            iconImage = cached
            return
        }
        
        // Run on detached task to avoid main actor blocking
        let image = await Task.detached(priority: .userInitiated) {
            let workspace = NSWorkspace.shared
            let icon = workspace.icon(forFile: url.path)
            return icon
        }.value
        
        // Update on MainActor
        AsyncIconView.iconCache.setObject(image, forKey: url.path as NSString)
        self.iconImage = image
    }
}

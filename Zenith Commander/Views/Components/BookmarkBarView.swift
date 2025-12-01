//
//  BookmarkBarView.swift
//  Zenith Commander
//
//  书签栏视图组件
//

import SwiftUI
import UniformTypeIdentifiers

/// 书签栏视图
struct BookmarkBarView: View {
    @ObservedObject var bookmarkManager: BookmarkManager
    
    /// 点击书签回调
    var onBookmarkClicked: ((BookmarkItem) -> Void)?
    
    /// 编辑模式
    @State private var isEditing = false
    
    /// 当前拖拽的书签
    @State private var draggingBookmark: BookmarkItem?
    
    var body: some View {
        HStack(spacing: 0) {
            // 书签图标
            Image(systemName: "bookmark.fill")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .padding(.leading, 8)
                .padding(.trailing, 4)
            
            // 书签列表
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(bookmarkManager.bookmarks) { bookmark in
                        BookmarkItemView(
                            bookmark: bookmark,
                            isEditing: isEditing,
                            onClicked: {
                                onBookmarkClicked?(bookmark)
                            },
                            onRemove: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    bookmarkManager.remove(bookmark)
                                }
                            }
                        )
                        .onDrag {
                            draggingBookmark = bookmark
                            return NSItemProvider(object: bookmark.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: BookmarkDropDelegate(
                            item: bookmark,
                            bookmarks: $bookmarkManager.bookmarks,
                            draggingItem: $draggingBookmark
                        ))
                    }
                    
                    // 空状态提示
                    if bookmarkManager.bookmarks.isEmpty {
                        Text("无书签 - 右键文件添加")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal, 4)
            }
            
            Spacer()
            
            // 编辑按钮
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isEditing.toggle()
                }
            }) {
                Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle")
                    .font(.system(size: 14))
                    .foregroundColor(isEditing ? Theme.accent : Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .help(isEditing ? "完成编辑" : "编辑书签")
        }
        .frame(height: 28)
        .background(WindowDragHandle())
        .background(Theme.backgroundSecondary.opacity(0.5))
    }
}

/// 单个书签项视图
struct BookmarkItemView: View {
    let bookmark: BookmarkItem
    let isEditing: Bool
    let onClicked: () -> Void
    let onRemove: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 4) {
            // 删除按钮（编辑模式）
            if isEditing {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            
            // 图标
            Image(systemName: bookmark.iconName)
                .font(.system(size: 11))
                .foregroundColor(bookmark.type == .folder ? Theme.accent : Theme.textPrimary)
            
            // 名称
            Text(bookmark.name)
                .font(.system(size: 11))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovering ? Theme.selection : Color.clear)
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            if !isEditing {
                onClicked()
            }
        }
        .contextMenu {
            Button("在 Finder 中显示") {
                NSWorkspace.shared.selectFile(bookmark.path.path, inFileViewerRootedAtPath: bookmark.path.deletingLastPathComponent().path)
            }
            
            Button("复制路径") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(bookmark.path.path, forType: .string)
            }
            
            Divider()
            
            Button("删除书签", role: .destructive) {
                onRemove()
            }
        }
        .help(bookmark.path.path)
    }
}

/// 书签拖放代理
struct BookmarkDropDelegate: DropDelegate {
    let item: BookmarkItem
    @Binding var bookmarks: [BookmarkItem]
    @Binding var draggingItem: BookmarkItem?
    
    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem,
              draggingItem.id != item.id,
              let fromIndex = bookmarks.firstIndex(where: { $0.id == draggingItem.id }),
              let toIndex = bookmarks.firstIndex(where: { $0.id == item.id })
        else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            bookmarks.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

/// 书签栏预览
#Preview {
    @Previewable @StateObject var manager = BookmarkManager()
    
    BookmarkBarView(bookmarkManager: manager)
        .frame(width: 600)
        .onAppear {
            manager.bookmarks = [
                BookmarkItem(name: "Documents", path: URL(fileURLWithPath: "/Users/test/Documents"), type: .folder, iconName: "folder.fill"),
                BookmarkItem(name: "Downloads", path: URL(fileURLWithPath: "/Users/test/Downloads"), type: .folder, iconName: "folder.fill"),
                BookmarkItem(name: "config.json", path: URL(fileURLWithPath: "/Users/test/config.json"), type: .file, iconName: "doc.fill")
            ]
        }
}

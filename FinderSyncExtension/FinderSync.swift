//
//  FinderSync.swift
//  FinderSyncExtension
//
//  Created by Hu Li on 1/5/26.
//

import Cocoa
import FinderSync
import UserNotifications

class FinderSync: FIFinderSync {

    override init() {
        super.init()

        let fm = FileManager.default

        // Monitor the home directory for broader coverage
        let homeDir = fm.homeDirectoryForCurrentUser

        FIFinderSyncController.default().directoryURLs = [homeDir]

        NSLog(
            "FinderSyncExtension loaded from %@, directoryURLs=%@",
            Bundle.main.bundlePath as NSString, homeDir.path as NSString)
        
        // 请求通知权限
        requestNotificationAuthorization()
    }
    
    private func requestNotificationAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                NSLog("FinderSyncExtension: notification authorization error: %@", error.localizedDescription as NSString)
            }
            NSLog("FinderSyncExtension: notification authorization granted: %@", granted ? "YES" : "NO")
        }
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems || menuKind == .contextualMenuForContainer else {
            return nil
        }

        NSLog("FinderSyncExtension: building contextual menu (kind=%ld)", menuKind.rawValue)

        let menu = NSMenu(title: "")

        // 复制完整路径
        let copyItem = NSMenuItem(
            title: "复制完整路径",
            action: #selector(copyFullPath(_:)),
            keyEquivalent: ""
        )
        copyItem.target = self
        menu.addItem(copyItem)

        // 批量重命名 - 仅当选中多个文件时显示
        let controller = FIFinderSyncController.default()
        let selectedCount = controller.selectedItemURLs()?.count ?? 0

        if selectedCount >= 2 {
            menu.addItem(NSMenuItem.separator())

            let renameMenu = NSMenu(title: "")

            // 添加序号 (01, 02, 03...)
            let addNumbersItem = NSMenuItem(
                title: "添加序号 (01, 02, 03...)",
                action: #selector(batchRenameWithNumbers(_:)),
                keyEquivalent: ""
            )
            addNumbersItem.target = self
            renameMenu.addItem(addNumbersItem)

            // 添加前缀
            let addPrefixItem = NSMenuItem(
                title: "添加前缀 (backup_...)",
                action: #selector(batchRenameWithPrefix(_:)),
                keyEquivalent: ""
            )
            addPrefixItem.target = self
            renameMenu.addItem(addPrefixItem)

            // 添加日期后缀
            let addDateItem = NSMenuItem(
                title: "添加日期 (..._2026-01-06)",
                action: #selector(batchRenameWithDate(_:)),
                keyEquivalent: ""
            )
            addDateItem.target = self
            renameMenu.addItem(addDateItem)

            // 小写扩展名
            let lowercaseExtItem = NSMenuItem(
                title: "扩展名转小写",
                action: #selector(batchRenameLowercaseExt(_:)),
                keyEquivalent: ""
            )
            lowercaseExtItem.target = self
            renameMenu.addItem(lowercaseExtItem)

            // 分隔符
            renameMenu.addItem(NSMenuItem.separator())

            // 自定义规则（打开主应用）
            let customRenameItem = NSMenuItem(
                title: "自定义规则...",
                action: #selector(openMainAppForBatchRename(_:)),
                keyEquivalent: ""
            )
            customRenameItem.target = self
            renameMenu.addItem(customRenameItem)

            let renameItem = NSMenuItem(
                title: "批量重命名",
                action: nil,
                keyEquivalent: ""
            )
            renameItem.submenu = renameMenu
            menu.addItem(renameItem)
        }

        return menu
    }

    override func beginObservingDirectory(at url: URL) {
        NSLog("FinderSyncExtension: beginObservingDirectory %@", url.path as NSString)
    }

    override func endObservingDirectory(at url: URL) {
        NSLog("FinderSyncExtension: endObservingDirectory %@", url.path as NSString)
    }

    @objc private func copyFullPath(_ sender: Any?) {
        let controller = FIFinderSyncController.default()

        // 优先使用多选，其次使用当前目标目录
        let urls =
            controller.selectedItemURLs()
            ?? (controller.targetedURL().map { [$0] } ?? [])

        NSLog("FinderSyncExtension: copyFullPath invoked, urls.count=%ld", urls.count)

        guard !urls.isEmpty else { return }

        let paths = urls.map { $0.path }
        let textToCopy = paths.joined(separator: "\n")

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(textToCopy, forType: .string)
    }

    // MARK: - Batch Rename Methods

    @objc private func batchRenameWithNumbers(_ sender: Any?) {
        performBatchRename { urls in
            urls.enumerated().map { index, url in
                let ext = url.pathExtension
                let number = String(format: "%02d", index + 1)
                let originalName = url.deletingPathExtension().lastPathComponent
                let newName = "\(number)_\(originalName)" + (ext.isEmpty ? "" : ".\(ext)")
                return url.deletingLastPathComponent().appendingPathComponent(newName)
            }
        }
    }

    @objc private func batchRenameWithPrefix(_ sender: Any?) {
        performBatchRename { urls in
            urls.map { url in
                let ext = url.pathExtension
                let originalName = url.deletingPathExtension().lastPathComponent
                let newName = "backup_\(originalName)" + (ext.isEmpty ? "" : ".\(ext)")
                return url.deletingLastPathComponent().appendingPathComponent(newName)
            }
        }
    }

    @objc private func batchRenameWithDate(_ sender: Any?) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())

        performBatchRename { urls in
            urls.map { url in
                let ext = url.pathExtension
                let originalName = url.deletingPathExtension().lastPathComponent
                let newName = "\(originalName)_\(dateString)" + (ext.isEmpty ? "" : ".\(ext)")
                return url.deletingLastPathComponent().appendingPathComponent(newName)
            }
        }
    }

    @objc private func batchRenameLowercaseExt(_ sender: Any?) {
        performBatchRename { urls in
            urls.map { url in
                let ext = url.pathExtension.lowercased()
                let baseName = url.deletingPathExtension().lastPathComponent
                let newName = baseName + (ext.isEmpty ? "" : ".\(ext)")
                return url.deletingLastPathComponent().appendingPathComponent(newName)
            }
        }
    }

    private func performBatchRename(transform: ([URL]) -> [URL]) {
        let controller = FIFinderSyncController.default()

        guard let urls = controller.selectedItemURLs(), urls.count >= 2 else {
            NSLog("FinderSyncExtension: batchRename requires at least 2 selected items")
            showNotification(title: "批量重命名", body: "请选择至少 2 个文件")
            return
        }

        NSLog("FinderSyncExtension: batchRename invoked, urls.count=%ld", urls.count)

        // 按文件名排序
        let sortedURLs = urls.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }

        let newURLs = transform(sortedURLs)

        // 执行重命名
        let fm = FileManager.default
        var successCount = 0
        var failCount = 0

        for (oldURL, newURL) in zip(sortedURLs, newURLs) {
            // 跳过未改变的文件
            if oldURL == newURL {
                continue
            }

            // 检查是否会覆盖
            if fm.fileExists(atPath: newURL.path) {
                NSLog(
                    "FinderSyncExtension: skip rename, target exists: %@", newURL.path as NSString)
                failCount += 1
                continue
            }

            do {
                try fm.moveItem(at: oldURL, to: newURL)
                successCount += 1
                NSLog(
                    "FinderSyncExtension: renamed %@ -> %@",
                    oldURL.lastPathComponent as NSString,
                    newURL.lastPathComponent as NSString)
            } catch {
                NSLog(
                    "FinderSyncExtension: rename failed: %@", error.localizedDescription as NSString
                )
                failCount += 1
            }
        }

        // 显示通知结果
        let message =
            failCount > 0
            ? "成功: \(successCount), 失败: \(failCount)"
            : "成功重命名 \(successCount) 个文件"

        showNotification(title: "批量重命名完成", body: message)
    }

    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("FinderSyncExtension: failed to deliver notification: %@", error.localizedDescription as NSString)
            }
        }
    }

    @objc func openMainAppForBatchRename(_ sender: Any?) {
        let controller = FIFinderSyncController.default()

        guard let urls = controller.selectedItemURLs(), urls.count >= 2 else {
            NSLog("FinderSyncExtension: batchRename requires at least 2 selected items")
            showNotification(title: "批量重命名", body: "请选择至少 2 个文件")
            return
        }

        // 按文件名排序
        let sortedURLs = urls.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }

        // 构建 URL Scheme
        let filePaths = sortedURLs.map { $0.path }.joined(separator: ",")
        let encodedPaths =
            filePaths.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "zenith-commander://batch-rename?files=\(encodedPaths)"

        guard let url = URL(string: urlString) else {
            NSLog("FinderSyncExtension: failed to create URL: %@", urlString as NSString)
            return
        }

        NSLog("FinderSyncExtension: opening main app with URL: %@", url.absoluteString as NSString)

        // 打开主应用
        NSWorkspace.shared.open(url)
    }

}

//
//  FinderSync.swift
//  FinderSyncExtension
//
//  Created by Hu Li on 1/5/26.
//

import Cocoa
import FinderSync

class FinderSync: FIFinderSync {

    override init() {
        super.init()

        let fm = FileManager.default
        
        // Monitor the home directory for broader coverage
        let homeDir = fm.homeDirectoryForCurrentUser
        
        FIFinderSyncController.default().directoryURLs = [homeDir]

        NSLog("FinderSyncExtension loaded from %@, directoryURLs=%@", Bundle.main.bundlePath as NSString, homeDir.path as NSString)
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
            
            let renameItem = NSMenuItem(
                title: "批量重命名...",
                action: #selector(batchRename(_:)),
                keyEquivalent: ""
            )
            renameItem.target = self
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
        let urls = controller.selectedItemURLs()
            ?? (controller.targetedURL().map { [$0] } ?? [])

        NSLog("FinderSyncExtension: copyFullPath invoked, urls.count=%ld", urls.count)

        guard !urls.isEmpty else { return }

        let paths = urls.map { $0.path }
        let textToCopy = paths.joined(separator: "\n")

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(textToCopy, forType: .string)
    }
    
    @objc private func batchRename(_ sender: Any?) {
        let controller = FIFinderSyncController.default()
        
        guard let urls = controller.selectedItemURLs(), urls.count >= 2 else {
            NSLog("FinderSyncExtension: batchRename requires at least 2 selected items")
            return
        }
        
        NSLog("FinderSyncExtension: batchRename invoked, urls.count=%ld", urls.count)
        
        // 按文件名排序
        let sortedURLs = urls.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        
        // 创建重命名对话框
        let alert = NSAlert()
        alert.messageText = "批量重命名"
        alert.informativeText = "已选中 \(sortedURLs.count) 个文件"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "重命名")
        alert.addButton(withTitle: "取消")
        
        // 创建自定义视图
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 120))
        
        // 前缀
        let prefixLabel = NSTextField(labelWithString: "前缀:")
        prefixLabel.frame = NSRect(x: 0, y: 90, width: 50, height: 20)
        containerView.addSubview(prefixLabel)
        
        let prefixField = NSTextField(frame: NSRect(x: 55, y: 88, width: 245, height: 24))
        prefixField.placeholderString = "添加到文件名开头"
        containerView.addSubview(prefixField)
        
        // 后缀
        let suffixLabel = NSTextField(labelWithString: "后缀:")
        suffixLabel.frame = NSRect(x: 0, y: 55, width: 50, height: 20)
        containerView.addSubview(suffixLabel)
        
        let suffixField = NSTextField(frame: NSRect(x: 55, y: 53, width: 245, height: 24))
        suffixField.placeholderString = "添加到扩展名前"
        containerView.addSubview(suffixField)
        
        // 序号
        let numberCheck = NSButton(checkboxWithTitle: "添加序号 (01, 02, 03...)", target: nil, action: nil)
        numberCheck.frame = NSRect(x: 0, y: 20, width: 200, height: 20)
        containerView.addSubview(numberCheck)
        
        // 起始编号
        let startLabel = NSTextField(labelWithString: "起始:")
        startLabel.frame = NSRect(x: 200, y: 20, width: 40, height: 20)
        containerView.addSubview(startLabel)
        
        let startField = NSTextField(frame: NSRect(x: 245, y: 18, width: 55, height: 24))
        startField.stringValue = "1"
        containerView.addSubview(startField)
        
        alert.accessoryView = containerView
        
        // 显示对话框
        let response = alert.runModal()
        
        guard response == .alertFirstButtonReturn else {
            NSLog("FinderSyncExtension: batchRename cancelled")
            return
        }
        
        // 获取输入值
        let prefix = prefixField.stringValue
        let suffix = suffixField.stringValue
        let useNumbering = numberCheck.state == .on
        let startNumber = Int(startField.stringValue) ?? 1
        
        // 执行重命名
        let fm = FileManager.default
        var successCount = 0
        var failCount = 0
        
        for (index, url) in sortedURLs.enumerated() {
            let originalName = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            
            // 构建新文件名
            var newName = prefix + originalName + suffix
            
            if useNumbering {
                let number = startNumber + index
                let paddedNumber = String(format: "%02d", number)
                newName = prefix + paddedNumber + "_" + originalName + suffix
            }
            
            // 添加扩展名
            if !ext.isEmpty {
                newName += "." + ext
            }
            
            let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
            
            // 检查是否会覆盖
            if fm.fileExists(atPath: newURL.path) && url != newURL {
                NSLog("FinderSyncExtension: skip rename, target exists: %@", newURL.path as NSString)
                failCount += 1
                continue
            }
            
            do {
                try fm.moveItem(at: url, to: newURL)
                successCount += 1
                NSLog("FinderSyncExtension: renamed %@ -> %@", url.lastPathComponent as NSString, newName as NSString)
            } catch {
                NSLog("FinderSyncExtension: rename failed: %@", error.localizedDescription as NSString)
                failCount += 1
            }
        }
        
        // 显示结果
        let resultAlert = NSAlert()
        resultAlert.messageText = "重命名完成"
        resultAlert.informativeText = "成功: \(successCount), 失败: \(failCount)"
        resultAlert.alertStyle = failCount > 0 ? .warning : .informational
        resultAlert.addButton(withTitle: "确定")
        resultAlert.runModal()
    }

}

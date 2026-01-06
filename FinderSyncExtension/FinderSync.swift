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

        // A small, real directory is required; if the directory doesn't exist,
        // Finder Sync often won't trigger on it.
        let testDir = fm.homeDirectoryForCurrentUser.appendingPathComponent("FinderSyncTest", isDirectory: true)
        do {
            try fm.createDirectory(at: testDir, withIntermediateDirectories: true)
        } catch {
            NSLog("FinderSyncExtension: failed to create testDir=%@, error=%@", testDir.path as NSString, String(describing: error) as NSString)
        }

        // Desktop is a reliable place to test triggering in Finder.
        let desktop = (try? fm.url(for: .desktopDirectory, in: .userDomainMask, appropriateFor: nil, create: false))

        var dirs: Set<URL> = [testDir]
        if let desktop { dirs.insert(desktop) }

        FIFinderSyncController.default().directoryURLs = dirs

        NSLog("FinderSyncExtension loaded from %@, directoryURLs=%@", Bundle.main.bundlePath as NSString, dirs.map { $0.path }.joined(separator: ", ") as NSString)
    }
    
    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems || menuKind == .contextualMenuForContainer else {
            return nil
        }

        NSLog("FinderSyncExtension: building contextual menu (kind=%ld)", menuKind.rawValue)

        let menu = NSMenu(title: "")
        let copyItem = NSMenuItem(
            title: "复制完整路径",
            action: #selector(copyFullPath(_:)),
            keyEquivalent: ""
        )
        copyItem.target = self
        menu.addItem(copyItem)
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

}

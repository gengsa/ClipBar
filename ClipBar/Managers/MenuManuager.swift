// Copyright 2025 gengsa
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//
//  MenuManuager.swift
//  ClipBar
//
//  Created by 王钊 on 2025/12/9.
//

import Cocoa
import Combine

/// MenuManager: 把剪贴历史构建成 NSMenu，并绑定到 status item
final class MenuManager: NSObject {
    static let shared = MenuManager()

    private(set) var clipMenu: NSMenu = NSMenu(title: "ClipBar")
    private weak var statusItem: NSStatusItem?
    private var cancellable: AnyCancellable?
    private let pageSize = 9 // 前 1..9 做快捷键

    private override init() {
        super.init()
    }

    /// 绑定 statusItem（会把 menu 赋给 statusItem）
    func setup(statusItem: NSStatusItem) {
        self.statusItem = statusItem
        statusItem.menu = clipMenu
        // 订阅 ClipboardManager 的 items 变化
        cancellable = ClipboardManager.shared.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
        // 初次建立
        rebuildMenu()
    }

    /// 根据 ClipboardManager.shared.items 重建菜单
    func rebuildMenu() {
        clipMenu.removeAllItems()

        let items = ClipboardManager.shared.items
        guard !items.isEmpty else {
            let empty = NSMenuItem(title: "No clipboard history", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            clipMenu.addItem(empty)
            clipMenu.addItem(NSMenuItem.separator())
            clipMenu.addItem(NSMenuItem(title: "Preferences…", action: #selector(AppDelegate.showPreferenceWindow), keyEquivalent: ""))
            clipMenu.addItem(NSMenuItem(title: "Quit", action: #selector(AppDelegate.terminate), keyEquivalent: "q"))
            return
        }

        // 主页面（前 pageSize 项）— 设置数字快捷键 1..9
        let count = items.count
        let mainCount = min(pageSize, count)
        for i in 0..<mainCount {
            let item = items[i]
            let label = menuTitle(for: item, index: i + 1)
            let keyEq = String((i + 1) % 10) // 1..9
            let mi = NSMenuItem(title: label, action: #selector(AppDelegate.selectClipMenuItem(_:)), keyEquivalent: keyEq)
            mi.representedObject = item.id.uuidString
            mi.target = NSApp.delegate
            
            // 为图片类型添加缩略图
            if item.type == .image, let imageData = item.imageData {
                if let image = NSImage(data: imageData) {
                    let thumbnail = image.resize(to: NSSize(width: 32, height: 32))
                    mi.image = thumbnail
                }
            }
            // 为颜色类型添加色块预览
            if item.type == .color, let colorValue = item.colorValue {
                if let color = NSColor(hexString: colorValue) {
                    let colorImage = NSImage.create(with: color, size: NSSize(width: 20, height: 20))
                    mi.image = colorImage
                }
            }
            
            clipMenu.addItem(mi)
        }

        // 其余项放到 "More..." 子菜单（分页）
        if count > mainCount {
            var start = mainCount
            var page = 2
            while start < count {
                let end = min(start + pageSize, count)
                let submenu = NSMenu(title: "Page \(page)")
                for j in start..<end {
                    let item = items[j]
                    let label = menuTitle(for: item, index: j + 1)
                    let mi = NSMenuItem(title: label, action: #selector(AppDelegate.selectClipMenuItem(_:)), keyEquivalent: "")
                    mi.representedObject = item.id.uuidString
                    mi.target = NSApp.delegate
                    
                    if item.type == . image, let imageData = item.imageData {
                        if let image = NSImage(data: imageData) {
                            let thumbnail = image.resize(to: NSSize(width: 32, height: 32))
                            mi.image = thumbnail
                        }
                    }
                    // 为颜色类型添加色块预览
                    if item.type == .color, let colorValue = item.colorValue {
                        if let color = NSColor(hexString: colorValue) {
                            let colorImage = NSImage.create(with: color, size: NSSize(width: 20, height: 20))
                            mi.image = colorImage
                        }
                    }

                    submenu.addItem(mi)
                }
                let parent = NSMenuItem(title: "More (page \(page))", action: nil, keyEquivalent: "")
                parent.submenu = submenu
                clipMenu.addItem(parent)
                start = end
                page += 1
            }
        }

        clipMenu.addItem(NSMenuItem.separator())
        clipMenu.addItem(NSMenuItem(title: "Clear All History", action: #selector(AppDelegate.clearAllHistory), keyEquivalent: ""))
        clipMenu.addItem(NSMenuItem(title: "Preferences…", action: #selector(AppDelegate.showPreferenceWindow), keyEquivalent: ""))
        clipMenu.addItem(NSMenuItem(title: "Quit", action: #selector(AppDelegate.terminate), keyEquivalent: "q"))
    }

    private func menuTitle(for item: ClipboardItem, index: Int) -> String {
        let typeIcon: String
        switch item.type {
        case .text:
            typeIcon = "📝"
        case .rtf:
            typeIcon = "📄"
        case .rtfd:
            typeIcon = "📋"  // 带图片的文档
        case .html:
            typeIcon = "🌐"
        case .pdf:
            typeIcon = "📕"
        case .image:
            typeIcon = "🖼️"
        case .file:
            typeIcon = "📁"
        case .url:
            typeIcon = "🔗"
        case .color:
            typeIcon = "🎨"
        case .spreadsheet:
            typeIcon = "📊"
        }
        
        let preview = item.displayText
            .replacingOccurrences(of: "\n", with: " ")
            .prefix(50)
        
        return "\(index). \(typeIcon) \(preview)"
    }

    private func shortTitle(for s: String, index: Int) -> String {
        let oneLinePreview = s.replacingOccurrences(of:  "\n", with: " ").prefix(50)
        return "\(index). \(oneLinePreview)"
    }
}

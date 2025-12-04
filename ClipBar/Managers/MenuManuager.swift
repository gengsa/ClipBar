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

        let items = ClipboardManager.shared.items // [String] 或你自定义的模型的展示字段
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
            let s = items[i]
            let label = shortTitle(for: s, index: i + 1)
            let keyEq = String((i + 1) % 10) // 1..9
            let mi = NSMenuItem(title: label, action: #selector(AppDelegate.selectClipMenuItem(_:)), keyEquivalent: keyEq)
            mi.representedObject = s
            mi.target = NSApp.delegate
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
                    let s = items[j]
                    let label = shortTitle(for: s, index: j + 1)
                    let mi = NSMenuItem(title: label, action: #selector(AppDelegate.selectClipMenuItem(_:)), keyEquivalent: "")
                    mi.representedObject = s
                    mi.target = NSApp.delegate
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

    private func shortTitle(for s: String, index: Int) -> String {
        let maxLen = 60
        let display = s.count > maxLen ? String(s.prefix(maxLen)) + "…" : s
        return "\(index). \(display)"
    }
}

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
//  HotKeyManager.swift
//  ClipBar
//
//  Created by 王钊 on 2025/12/10.
//


//
// HotKeyManager.swift
// 全局热键管理：基于 soffes/HotKey（Swift Package）
// 使用：HotKeyManager.shared.setup(statusItem: statusItem, key: .v, modifiers: [.command, .shift])
//

import Cocoa
import HotKey

final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKey: HotKey?
    private weak var statusItem: NSStatusItem?

    private init() {}

    /// 注册热键并把 statusItem 传入（触发时会弹出菜单）
    /// key: HotKey.Key（库定义），modifiers: NSEvent.ModifierFlags
    func setup(statusItem: NSStatusItem, key: Key = .v, modifiers: NSEvent.ModifierFlags = [.command, .shift]) {
        self.statusItem = statusItem

        // 如果已有注册，先释放
        hotKey = nil

        // 直接使用 NSEvent.ModifierFlags（HotKey 支持）
        hotKey = HotKey(key: key, modifiers: modifiers)
        hotKey?.keyDownHandler = { [weak self] in
            DispatchQueue.main.async {
                // 可选：如果你有排除前台应用的逻辑，可在此检查并决定是否忽略
                // 示例：如果需要把应用切到前台：
                // NSApp.activate(ignoringOtherApps: true)

                // 最简单、可靠的菜单弹出方式：模拟 statusItem 点击
                if let button = self?.statusItem?.button {
                    button.performClick(nil)
                }
            }
        }
    }

    func unregister() {
        hotKey = nil
    }
}

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
//  AppDelegate.swift
//  ClipBar
//
//  Created by 王钊 on 2025/11/18.
//

import Cocoa
import SwiftUI
import HotKey

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[AppDelegate] applicationDidFinishLaunching")
        // 常规初始化（ClipboardManager 等）
        ClipboardManager.shared.startPolling()

        // 创建 status item（用图标）
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let img = NSImage(systemSymbolName: "scissors", accessibilityDescription: "ClipBar") {
                img.isTemplate = true
                button.image = img
            } else {
                button.title = "ClipBar"
            }
        }

        // 绑定 MenuManager（注意：MenuManager.setup 会把 menu 赋给 statusItem）
        MenuManager.shared.setup(statusItem: statusItem)
        
        // 注册全局热键 Cmd+Shift+V
        HotKeyManager.shared.setup(statusItem: statusItem, key: .v, modifiers: [.command, .shift])
    }

    // MARK: - Menu actions

    @objc func selectClipMenuItem(_ sender: NSMenuItem) {
        guard let s = sender.representedObject as? String else { return }
        AutoPasteHelper.shared.writeAndAutoPaste(s, autoPaste: true, useCGEvent: true)
    }

    @objc func showPreferenceWindow() {
        NSApp.activate(ignoringOtherApps: true)
        // 打开你的偏好窗口或 Settings scene
        // 如果使用 SwiftUI Settings scene，可打开对应 window/controller
    }

    @objc func clearAllHistory() {
        ClipboardManager.shared.clearAll()
    }

    @objc func terminate() {
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("[AppDelegate] applicationWillTerminate")
        // 注销热键（清理）
        HotKeyManager.shared.unregister()
    }
}

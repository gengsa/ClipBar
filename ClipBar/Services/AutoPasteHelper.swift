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
//  AutoPasteHelper.swift
//  ClipBar
//
//  Created by 王钊 on 2025/12/10.
//


//
// AutoPasteHelper.swift
// 把字符串写入剪贴板并可选地模拟一次 Cmd+V 自动粘贴（需要辅助功能权限）
// 使用方法：AutoPasteHelper.shared.writeAndAutoPaste(s, autoPaste: true)
// 注意：调用自动粘贴前请提醒用户在 系统偏好 → 隐私与安全 → 辅助功能 中允许本 App
//

import Cocoa
import ApplicationServices

final class AutoPasteHelper {
    static let shared = AutoPasteHelper()

    private init() {}

    /// 直接写入剪贴板
    func writeToPasteboard(_ s: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(s, forType: .string)
        // 简单反馈（可换成更友好的 UI）
        NSSound.beep()
    }

    /// 写入剪贴板并根据 autoPaste 决定是否发送一次 Cmd+V
    /// useCGEvent: true 使用 CGEvent（推荐），false 使用 AppleScript
    func writeAndAutoPaste(_ s: String, autoPaste: Bool, useCGEvent: Bool = true) {
        // 把选中内容放入系统剪贴板
        writeToPasteboard(s)
        guard autoPaste else { return }

        // 如果没有辅助功能权限，先弹出系统授权提示（会打开设置或触发系统提示）
        if !isAccessibilityTrusted() {
            // 尝试主动触发系统授权提示
            _ = requestAccessibilityPermissionPrompt()
            // 同时打开系统设置到辅助功能页，方便用户授权（有时系统不会自动打开）
            openAccessibilityPreferences()
            return
        }

        // 发送 Cmd+V
        if useCGEvent {
            sendCmdV_CGEvent()
        } else {
            sendCmdV_AppleScript()
        }
    }

    // MARK: - 权限检查与提示

    /// 检查是否已被授予辅助功能权限
    func isAccessibilityTrusted() -> Bool {
        return AXIsProcessTrusted()
    }

    /// 请求辅助功能权限并弹出系统提示（会在 macOS 上触发“要授权吗？”的对话）
    /// 返回当前检查结果（true 表示已授权）
    @discardableResult
    func requestAccessibilityPermissionPrompt() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// 打开系统偏好到辅助功能/隐私页，帮助用户手动授权
    func openAccessibilityPreferences() {
        // 尝试打开隐私页（辅助功能）
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        } else {
            // 兜底：打开安全性与隐私面板
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane"))
        }
    }

    // MARK: - 发送按键（两种实现）

    /// AppleScript 实现（简单但可能比 CGEvent 更慢）
    private func sendCmdV_AppleScript() {
        let script = "tell application \"System Events\" to keystroke \"v\" using command down"
        if let appleScript = NSAppleScript(source: script) {
            var err: NSDictionary?
            appleScript.executeAndReturnError(&err)
            if let e = err {
                NSLog("[AutoPaste] AppleScript error: \(e)")
            }
        }
    }

    /// CGEvent 实现（更底层、推荐）
    /// 注意：虚拟键码基于常见 US 键盘布局， 'v' 的 keycode 常为 9（Intel/Mac）。
    /// 对于非常规布局此值可能不同；若要更保险可做更复杂的映射。
    private func sendCmdV_CGEvent() {
        guard let src = CGEventSource(stateID: .combinedSessionState) else { return }
        let vKeyCode: CGKeyCode = 9 // 常用 v 键码

        // key down (Cmd + v)
        if let keyDown = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: true) {
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
        }
        // key up
        if let keyUp = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: false) {
            keyUp.flags = .maskCommand
            keyUp.post(tap: .cghidEventTap)
        }
    }
}

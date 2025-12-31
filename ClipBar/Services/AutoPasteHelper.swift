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


// 把字符串写入剪贴板并可选地模拟一次 Cmd+V 自动粘贴（需要辅助功能权限）
// 使用方法：AutoPasteHelper.shared.writeAndAutoPaste(s, autoPaste: true)
// 注意：调用自动粘贴前请提醒用户在 系统偏好 → 隐私与安全 → 辅助功能 中允许本 App

import Cocoa
import ApplicationServices

final class AutoPasteHelper {
    static let shared = AutoPasteHelper()

    private init() {}

    /// 写入剪贴板并根据 autoPaste 决定是否发送一次 Cmd+V
    /// useCGEvent: true 使用 CGEvent（推荐），false 使用 AppleScript
    func writeAndAutoPaste(_ item: ClipboardItem, autoPaste: Bool, useCGEvent: Bool = true) {
        // 1. 写入剪贴板
        item.writeTo(pasteboard: NSPasteboard.general)
        
        // 2. 如果需要自动粘贴
        if autoPaste {
            // 延迟一点确保剪贴板已更新
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.simulatePaste(useCGEvent: useCGEvent)
            }
        }
    }

    // MARK: - 权限检查与提示

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

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = "请在\"系统偏好设置 → 隐私与安全 → 辅助功能\"中允许 ClipBar 控制您的电脑。"
        alert.alertStyle = . warning
        alert.addButton(withTitle: "打开系统偏好设置")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openAccessibilityPreferences()
        }
    }

    // MARK: - 粘贴（两种实现）

    /// 模拟 Cmd+V 粘贴操作
    private func simulatePaste(useCGEvent: Bool = true) {
        if useCGEvent {
            simulatePasteWithCGEvent()
        } else {
            simulatePasteWithAppleScript()
        }
    }

    /// AppleScript 实现（简单但可能比 CGEvent 更慢）
    private func simulatePasteWithAppleScript() {
        let script = """
        tell application "System Events"
            keystroke "v" using command down
        end tell
        """
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            if let err = error {
                print("[AutoPasteHelper] AppleScript error: \(err)")
            }
        }
    }

    /// CGEvent 实现（更底层、推荐）
    /// 注意：虚拟键码基于常见 US 键盘布局， 'v' 的 keycode 常为 9（Intel/Mac）。
    /// 对于非常规布局此值可能不同；若要更保险可做更复杂的映射。
    private func simulatePasteWithCGEvent() {
        // 确保有辅助功能权限
        guard AXIsProcessTrusted() else {
            print("[AutoPasteHelper] ⚠️ 需要辅助功能权限")
            // 可以考虑弹窗提示用户
            showAccessibilityAlert()
            return
        }
        let vKey = CGKeyCode(0x09) // V key
        let cmdFlag = CGEventFlags.maskCommand
        // Cmd+V down
        if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: vKey, keyDown:  true) {
            keyDown.flags = cmdFlag
            keyDown.post(tap: .cghidEventTap)
        }
        // Cmd+V up
        if let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: vKey, keyDown: false) {
            keyUp.flags = cmdFlag
            keyUp.post(tap: .cghidEventTap)
        }
    }
}

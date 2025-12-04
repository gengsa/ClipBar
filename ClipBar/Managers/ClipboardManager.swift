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
//  ClipboardManager.swift
//  ClipBar
//
//  Created by 王钊 on 2025/11/18.
//

import Foundation
import AppKit
import Combine

final class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    @Published private(set) var items: [String] = [] // 当前剪贴板历史（最新在前）

    private let pasteboard = NSPasteboard.general
    private var changeCount: Int
    private var timer: Timer?
    private let maxItems: Int
    private let queue = DispatchQueue(label: "com.clipbar.clipboardmanager")

    private init(maxItems: Int = 50) {
        self.maxItems = maxItems
        self.changeCount = pasteboard.changeCount
    }

    // MARK: - Polling

    /// 开始轮询剪贴板
    func startPolling(interval: TimeInterval = 1.0) {
        stopPolling()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }

    /// 停止轮询
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func checkPasteboard() {
        // 在后台线程检查 changeCount，以减少主线程开销
        queue.async { [weak self] in
            guard let self = self else { return }
            let current = self.pasteboard.changeCount
            guard current != self.changeCount else { return }
            self.changeCount = current

            if let s = self.pasteboard.string(forType: .string) {
                self.handleNewClipboardString(s)
            }
        }
    }

    // MARK: - Mutations / API

    /// 处理新检测到的剪贴文本（公有，外部也可直接调用）
    func handleNewClipboardString(_ str: String) {
        // 去重：与最新项相同则跳过
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            if self.items.first == trimmed { return }

            // 插入到最前面
            self.items.insert(trimmed, at: 0)

            // 限制长度
            if self.items.count > self.maxItems {
                self.items.removeLast(self.items.count - self.maxItems)
            }
        }
    }

    /// 清空所有历史（AppDelegate 中的 Clear All 将调用它）
    func clearAll() {
        DispatchQueue.main.async { [weak self] in
            self?.items.removeAll()
        }
    }

    /// 删除匹配的条目（按值删除所有匹配项）
    func delete(_ value: String) {
        DispatchQueue.main.async { [weak self] in
            self?.items.removeAll { $0 == value }
        }
    }

    /// 删除指定索引（安全检查）
    func delete(at index: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.items.indices.contains(index) else { return }
            self.items.remove(at: index)
        }
    }

    /// 导入一组条目（会合并并去重，最新条目放前面）
    func importItems(_ newItems: [String]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for s in newItems.reversed() { // 让 newItems[0] 成为最早项
                let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                if self.items.first != trimmed {
                    self.items.insert(trimmed, at: 0)
                }
            }
            if self.items.count > self.maxItems {
                self.items.removeLast(self.items.count - self.maxItems)
            }
        }
    }

    /// 手动把字符串写入系统剪贴板（供菜单/选择项调用）
    func writeToPasteboard(_ s: String) {
        DispatchQueue.main.async {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(s, forType: .string)
            // 更新 changeCount，以避免立即被轮询重复读取
            self.changeCount = self.pasteboard.changeCount
        }
    }
}

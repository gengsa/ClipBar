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

    // 最新复制的的在前面
    @Published private(set) var items: [ClipboardItem] = []

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

            // 从剪贴板创建 ClipboardItem
            if let item = ClipboardItem.from(pasteboard: self.pasteboard) {
                self.handleNewClipboardItem(item)
            }
        }
    }

    // MARK: - Mutations / API

    /// 处理新检测到的剪贴板条目
    func handleNewClipboardItem(_ item: ClipboardItem) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 去重：与最新项相同则跳过 (简单比较 displayText)
            // TODO: 可能得去重写对象的 equals 方法，或者给 ClipboardItem 增加 hashable 支持然后比较 hash 值
            if let first = self.items.first,
               first.displayText == item.displayText,
               first.type == item.type {
                return
            }

            // 插入到最前面
            self.items.insert(item, at: 0)

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

    /// 删除指定索引（安全检查）
    func delete(at index: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.items.indices.contains(index) else { return }
            self.items.remove(at: index)
        }
    }
}

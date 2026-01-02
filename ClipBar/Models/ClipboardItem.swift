// Copyright 2026 gengsa
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
//  ClipboardItem.swift
//  ClipBar
//
//  Created by 王钊 on 2025/12/31.
//

import Foundation
import AppKit

/// 剪贴板条目类型
enum ClipboardItemType: String, Codable {
    case text           // 纯文本
    case rtf            // 富文本
    case html           // HTML
    case image          // 图片
    case file           // 文件引用
    case pdf            // PDF
    case url            // URL
    case color          // 颜色代码
    case spreadsheet    // 表格
    case unknown        // 未知类型
}

/// 单个 pasteboard type 的数据
struct PasteboardItemData: Codable {
    let typeIdentifier: String  // NSPasteboard.PasteboardType.rawValue
    let data: Data
    
    static let maxDataSize = 10 * 1024 * 1024
    
    init?(type: NSPasteboard.PasteboardType, from pasteboard: NSPasteboard) {
        let typeId = type.rawValue
        self.typeIdentifier = typeId
        
        // ✅ 跳过动态类型
        if typeId.hasPrefix("dyn. ") {
            #if DEBUG
            print("⏭️ Skipping dynamic type:  \(typeId)")
            #endif
            return nil
        }
        
        // ✅ 跳过承诺类型
        if typeId.contains("promised") {
            #if DEBUG
            print("⏭️ Skipping promised type: \(typeId)")
            #endif
            return nil
        }
        
        // 方法1: data(forType:)
        if let data = pasteboard.data(forType: type) {
            // ✅ 跳过空数据
            guard !data.isEmpty else {
                #if DEBUG
                print("⏭️ Skipping empty data:  \(typeId)")
                #endif
                return nil
            }
            
            guard data.count <= Self.maxDataSize else {
                #if DEBUG
                print("⚠️ Skipping large data \(typeId): \(data.count) bytes")
                #endif
                return nil
            }
            self.data = data
            return
        }
        
        // 方法2: string(forType:)
        if let string = pasteboard.string(forType: type) {
            guard !string.isEmpty else {
                return nil
            }
            guard let stringData = string.data(using: .utf8) else {
                return nil
            }
            self.data = stringData
            return
        }
        
        // 方法3: propertyList(forType:)
        if let propertyList = pasteboard.propertyList(forType: type) {
            guard let plistData = try? PropertyListSerialization.data(
                fromPropertyList: propertyList,
                format: .binary,
                options: 0
            ) else {
                return nil
            }
            self.data = plistData
            return
        }
        
        // 无法获取数据
        return nil
    }
}

/// 统一的剪贴板条目模型
struct ClipboardItem: Identifiable, Codable {
    let id:  UUID
    let timestamp: Date
    
    // 核心：保存所有原始数据
    var pasteboardItems: [PasteboardItemData]
    
    // 用于显示的元数据
    var displayType:  ClipboardItemType
    var displayText: String
    
    // 用于颜色预览
    var colorValue: String?
    
    // 用于图片预览
    var thumbnailData: Data?
    
    
    /// 从 NSPasteboard 创建 ClipboardItem
    //完全透明，只做复制，不识别具体类型
    // 只为显示预览目的分析类型
    static func from(pasteboard: NSPasteboard) -> ClipboardItem? {
        guard let types = pasteboard.types, !types.isEmpty else {
            return nil
        }
        #if DEBUG
        print("[ClipboardItem] 📋 Pasteboard types: \(types.map { $0.rawValue })")
        #endif
        
        // 获取所有类型的数据（不关心具体是什么）
        var items: [PasteboardItemData] = []
        for type in types {
            if let itemData = PasteboardItemData(type: type, from: pasteboard) {
                items.append(itemData)
            }
        }
        guard !items.isEmpty else {
            return nil
        }
        // 只为显示预览目的分析类型
        let displayInfo = analyzeForDisplay(types: types, pasteboard: pasteboard)
        
        return ClipboardItem(
            id: UUID(),
            timestamp: Date(),
            pasteboardItems: items,
            displayType: displayInfo.type,
            displayText: displayInfo.text,
            colorValue: displayInfo.colorValue,
            thumbnailData: displayInfo.thumbnailData
        )
    }
    
    /// 分析类型和预览文本（仅用于显示，不影响数据保存）
    // 不像 Clipy 那样，只取第一个type的数据
    // 这里还是有优先级处理的，能识别就终止，不能识别继续往后检测
    private static func analyzeForDisplay(
        types: [NSPasteboard.PasteboardType],
        pasteboard: NSPasteboard
    ) -> (type: ClipboardItemType, text: String, colorValue: String?, thumbnailData: Data?) {
        
        // 检测文件
        if types.contains(.fileURL),
           let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
            let fileNames = urls.map { $0.lastPathComponent }
            if fileNames.count == 1 {
                return (.file, fileNames[0], nil, nil)
            } else {
                let text = "\(fileNames.count) files: \(fileNames.prefix(3).joined(separator: ", "))"
                return (.file, text, nil, nil)
            }
        }
        
        // 检测图片
        if types.contains(.tiff) || types.contains(.png) {
            if let imageData = pasteboard.data(forType: .tiff) ??  pasteboard.data(forType: .png) {
                // ✅ 验证图片数据是否有效
                if NSImage(data: imageData) != nil {
                    return (.image, "[Image]", nil, imageData)
                }
            }
            // 如果图片无效，继续检查其他类型
        }
        
        // 检测 PDF
        if types.contains(.pdf) {
            return (.pdf, "[PDF Document]", nil, nil)
        }
        
        // 检测表格
        if types.contains(.tabularText) {
            if let tsvData = pasteboard.data(forType: .tabularText),
               let tsvString = String(data: tsvData, encoding: .utf8) {
                // ✅ 显示表格前几个单元格
                let lines = tsvString.components(separatedBy: .newlines).prefix(2)
                let preview = lines.map { line in
                    line.components(separatedBy: "\t").prefix(3).joined(separator: " | ")
                }.joined(separator: " ")
                return (.spreadsheet, String(preview.prefix(100)), nil, nil)
            }
            return (.spreadsheet, "[Spreadsheet Data]", nil, nil)
        }
        
        // 检测 RTF/RTFD
        if types.contains(.rtfd) || types.contains(.rtf) {
            // 尝试提取纯文本预览
            if let rtfData = pasteboard.data(forType: .rtfd) ?? pasteboard.data(forType: .rtf),
               let attributed = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
                let preview = attributed.string.trimmingCharacters(in: . whitespacesAndNewlines)
                return (.rtf, String(preview.prefix(100)), nil, nil)
            }
            return (.rtf, "[Rich Text]", nil, nil)
        }
        
        // 检测 HTML
        if types.contains(.html) {
            if let html = pasteboard.string(forType: .html),
               let data = html.data(using: . utf8),
               let attributed = NSAttributedString(html: data, documentAttributes: nil) {
                let preview = attributed.string.trimmingCharacters(in:  .whitespacesAndNewlines)
                return (.html, String(preview.prefix(100)), nil, nil)
            }
            return (.html, "[HTML]", nil, nil)
        }
        
        // 检测纯文本
        if types.contains(.string),
           let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 检测颜色代码
            if isColorCode(trimmed) {
                return (.color, trimmed, trimmed, nil)
            }
            
            // 检测 URL
            if types.contains(.URL) {
                return (.url, trimmed, nil, nil)
            }
            
            // 普通文本
            return (.text, String(trimmed.prefix(100)), nil, nil)
        }
        
        // 未知类型
        return (.unknown, "[Unknown Data]", nil, nil)
    }
    
    /// 检测是否是颜色代码
    private static func isColorCode(_ string: String) -> Bool {
        // 匹配 #RGB, #RRGGBB, #RRGGBBAA
        let pattern = "^#([A-Fa-f0-9]{3}|[A-Fa-f0-9]{6}|[A-Fa-f0-9]{8})$"
        return string.range(of: pattern, options: .regularExpression) != nil
    }
    
    /// 将数据写回到 NSPasteboard
    func writeTo(pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        
        // 原封不动地写回所有数据
        for item in pasteboardItems {
            let type = NSPasteboard.PasteboardType(rawValue: item.typeIdentifier)
            pasteboard.setData(item.data, forType: type)
        }
        #if DEBUG
        print("[ClipboardItem] 📤 Written \(pasteboardItems.count) types:  \(pasteboardItems.map { $0.typeIdentifier })")
        #endif
    }
}

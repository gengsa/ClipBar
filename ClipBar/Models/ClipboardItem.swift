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
//  ClipboardItemType.swift
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
    case spreadsheet    // 表格数据
}

/// 统一的剪贴板条目模型
struct ClipboardItem: Identifiable, Codable {
    let id:  UUID
    let type: ClipboardItemType
    let timestamp: Date
    
    // 不同类型的数据存储
    var stringValue: String?          // 文本/HTML
    var rtfData: Data?              // RTF 数据
    var imageData: Data?            // 图片数据
    var fileURLs: [String]?         // 文件路径
    var spreadsheetData: Data?      // 表格数据 (可能是 TSV/CSV)
    
    // 用于显示的预览文本
    var displayText: String {
        switch type {
        case .text, .html:
            return stringValue?.prefix(100).description ?? ""
        case .rtf:
            // 从 RTF 数据提取纯文本用于预览
            if let data = rtfData,
               let attributed = NSAttributedString(rtf: data, documentAttributes: nil) {
                return attributed.string.prefix(100).description
            }
            return "[Rich Text]"
        case .image:
            return "[Image]"
        case .file:
            if let urls = fileURLs {
                return urls.joined(separator: ", ")
            }
            return "[File]"
        case .spreadsheet:
            return "[Spreadsheet Data]"
        }
    }
    
    /// 从 NSPasteboard 创建 ClipboardItem
    static func from(pasteboard: NSPasteboard) -> ClipboardItem? {
        let types = pasteboard.types ??  []
        
        // 优先级：文件 > 图片 > RTF > HTML > 纯文本
        
        // 1. 文件
        if types.contains(.fileURL),
           let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
            return ClipboardItem(
                id: UUID(),
                type: .file,
                timestamp: Date(),
                fileURLs: urls.map { $0.path }
            )
        }
        
        // 2. 图片
        if types.contains(.tiff) || types.contains(.png),
           let imageData = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) {
            return ClipboardItem(
                id: UUID(),
                type: .image,
                timestamp: Date(),
                imageData:  imageData
            )
        }
        
        // 3. 表格数据 (TSV - Tab Separated Values, 通常用于 Excel/Numbers 复制)
        if types.contains(.tabularText),
           let tsvData = pasteboard.data(forType: .tabularText) {
            return ClipboardItem(
                id: UUID(),
                type: .spreadsheet,
                timestamp: Date(),
                stringValue: String(data: tsvData, encoding: .utf8),
                spreadsheetData: tsvData
            )
        }
        
        // 4. RTF (富文本)
        if types.contains(.rtf),
           let rtfData = pasteboard.data(forType: .rtf) {
            return ClipboardItem(
                id: UUID(),
                type: .rtf,
                timestamp: Date(),
                rtfData: rtfData
            )
        }
        
        // 5. HTML
        if types.contains(.html),
           let htmlString = pasteboard.string(forType: .html) {
            return ClipboardItem(
                id: UUID(),
                type: .html,
                timestamp: Date(),
                stringValue: htmlString
            )
        }
        
        // 6. 纯文本
        if types.contains(.string),
           let stringValue = pasteboard.string(forType: .string) {
            return ClipboardItem(
                id: UUID(),
                type: .text,
                timestamp: Date(),
                stringValue: stringValue
            )
        }
        
        return nil
    }
    
    /// 将数据写回到 NSPasteboard
    func writeTo(pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        
        switch type {
        case .text:
            if let str = stringValue {
                pasteboard.setString(str, forType: .string)
            }
        case .rtf:
            if let data = rtfData {
                pasteboard.setData(data, forType: .rtf)
            }
        case .html:
            if let str = stringValue {
                pasteboard.setString(str, forType: .html)
            }
        case .image:
            if let data = imageData {
                pasteboard.setData(data, forType: .tiff)
            }
        case .file:
            if let paths = fileURLs {
                let urls = paths.compactMap { URL(fileURLWithPath: $0) }
                pasteboard.writeObjects(urls as [NSURL])
            }
        case .spreadsheet:
            // 写入表格数据，同时提供纯文本备选
            if let data = spreadsheetData {
                pasteboard.setData(data, forType: .tabularText)
            }
            if let str = stringValue {
                pasteboard.setString(str, forType: .string)
            }
        }
    }
}

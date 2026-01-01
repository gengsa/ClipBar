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
    case rtf            // 富文本（简单）
    case rtfd           // 富文本（带图片）
    case html           // HTML
    case pdf            // PDF 文档
    case image          // 图片
    case file           // 文件引用
    case url            // URL 链接
    case color          // 颜色代码
    case spreadsheet    // 表格数据
}

/// 统一的剪贴板条目模型
struct ClipboardItem: Identifiable, Codable {
    let id:  UUID
    let type: ClipboardItemType
    let timestamp: Date
    
    // 不同类型的数据存储
    var stringValue: String?           // 文本/HTML/URL
    var rtfData: Data?                 // RTF 数据
    var rtfdData: Data?                // RTFD 数据（带图片的富文本）
    var pdfData: Data?                 // PDF 数据
    var imageData: Data?               // 图片数据
    var fileURLs: [String]?            // 文件路径（支持多文件）
    var spreadsheetData: Data?         // 表格数据 (TSV/CSV)
    var colorValue: String?            // 颜色值（如 #FF5733）
    
    // 用于显示的预览文本
    var displayText: String {
        switch type {
        case .text:
            return stringValue?.prefix(100).description ?? ""
        case .html:
           // 从 HTML 提取纯文本用于预览
            if let html = stringValue,
               let data = html.data(using: .utf8),
               let attributed = NSAttributedString(html: data, documentAttributes: nil) {
                return attributed.string.prefix(100).description
            }
            return "[HTML]"
        case .rtf:
            // 从 RTF 数据提取纯文本用于预览
            if let data = rtfData,
               let attributed = NSAttributedString(rtf: data, documentAttributes: nil) {
                return attributed.string.prefix(100).description
            }
            return "[Rich Text]"
        case .rtfd:
            if let data = rtfdData,
               let attributed = try? NSAttributedString(rtfd: data, documentAttributes: nil) {
                return attributed.string.prefix(100).description
            }
            return "[Rich Text with Images]"
        case .pdf:
            return "[PDF Document]"
        case .image:
            return "[Image]"
        case .file:
            if let urls = fileURLs {
                let fileNames = urls.map { URL(fileURLWithPath: $0).lastPathComponent }
                if fileNames.count == 1 {
                    return fileNames[0]
                } else {
                    return "\(fileNames.count) files: \(fileNames.prefix(3).joined(separator: ", "))"
                }
            }
            return "[File]"
        case .url:
            return stringValue ?? "[URL]"
        case .color:
            return colorValue ?? "[Color]"
        case .spreadsheet:
            return "[Spreadsheet Data]"
        }
    }
    
    /// 从 NSPasteboard 创建 ClipboardItem
    static func from(pasteboard: NSPasteboard) -> ClipboardItem? {
        let types = pasteboard.types ??  []
        
        // 优先级顺序（从高到低）：
        // 1. 文件（最具体）
        // 2. 图片
        // 3. PDF
        // 4. RTFD（带图片的富文本）
        // 5. RTF
        // 6. 表格数据
        // 7. URL（单独的链接）
        // 8. HTML
        // 9. 颜色代码（检测 #RRGGBB 格式）
        // 10. 纯文本（最通用）
        
        // 1. 文件
        if types.contains(.fileURL),
           let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
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
                imageData: imageData
            )
        }
        
        // 3. PDF
        if types.contains(.pdf),
           let pdfData = pasteboard.data(forType: .pdf) {
            return ClipboardItem(
                id: UUID(),
                type: .pdf,
                timestamp: Date(),
                pdfData: pdfData
            )
        }
        
        // 4. RTFD（带图片的富文本）
        if types.contains(.rtfd),
           let rtfdData = pasteboard.data(forType: .rtfd) {
            return ClipboardItem(
                id: UUID(),
                type: .rtfd,
                timestamp: Date(),
                rtfdData: rtfdData
            )
        }
        
        // 5. RTF（富文本）
        if types.contains(.rtf),
           let rtfData = pasteboard.data(forType: .rtf) {
            return ClipboardItem(
                id: UUID(),
                type: .rtf,
                timestamp: Date(),
                rtfData: rtfData
            )
        }
        
        // 6. 表格数据 (TSV - Tab Separated Values, 通常用于 Excel/Numbers 复制)
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
        
        // 7. URL（单独的 URL 类型，不是纯文本）
        if types.contains(.URL),
           let urlString = pasteboard.string(forType: .URL), !urlString.isEmpty {
            return ClipboardItem(
                id: UUID(),
                type: .url,
                timestamp: Date(),
                stringValue: urlString
            )
        }
                
        // 8. HTML
        if types.contains(.html),
           let htmlString = pasteboard.string(forType: .html) {
            return ClipboardItem(
                id: UUID(),
                type: .html,
                timestamp: Date(),
                stringValue: htmlString
            )
        }
                
        // 9. 颜色代码
        // 10. 纯文本
        if types.contains(.string), let stringValue = pasteboard.string(forType: .string) {
            let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 检测颜色代码（#RGB, #RRGGBB, #RRGGBBAA）
            if isColorCode(trimmed) {
                return ClipboardItem(
                    id: UUID(),
                    type: .color,
                    timestamp: Date(),
                    stringValue: trimmed,
                    colorValue: trimmed
                )
            }
            
            // 普通文本
            return ClipboardItem(
                id: UUID(),
                type: .text,
                timestamp: Date(),
                stringValue: stringValue
            )
        }
        
        return nil
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
        
        switch type {
        case .text:
            if let str = stringValue {
                pasteboard.setString(str, forType: .string)
            }
        case .rtf:
            if let data = rtfData {
                pasteboard.setData(data, forType: .rtf)
            }
        case .rtfd:
            if let data = rtfdData {
                pasteboard.setData(data, forType: .rtfd)
            }
        case .html:
            if let str = stringValue {
                pasteboard.setString(str, forType: .html)
            }
        case .pdf:
            if let data = pdfData {
                pasteboard.setData(data, forType: .pdf)
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
        case .url:
            if let str = stringValue {
                pasteboard.setString(str, forType: .URL)
                // 同时也设置为普通文本，增加兼容性
                pasteboard.setString(str, forType: .string)
            }
        case .color:
            if let str = stringValue {
                pasteboard.setString(str, forType: .string)
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

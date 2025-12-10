# ClipBar

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

ClipBar — 一个轻量的 macOS 剪贴板历史工具（菜单栏常驻）。

## 简短说明

- ClipBar 用于记录并方便访问系统剪贴板历史（文本、图片、富文本、文件引用等）
- 目标用户：频繁复制粘贴文本/代码/图片/文件的开发者与内容创作者
- 当前阶段：MVP

## 核心功能（MVP）

- 监听并存储系统剪贴板历史（文本、图片、链接、富文本、文件等），并在菜单中显示
- 菜单栏图标常驻，快捷键或点击唤出历史列表，在列表中预览、搜索、选择并粘贴到当前焦点应用
- 从菜单中选择条目会将内容写入系统剪贴板（默认行为），并可扩展为自动粘贴（需用户授权）
- 菜单分页（历史超过 9 条时自动生成子菜单）
- 本地持久化（可配置最大条目数、导入/导出），基本偏好设置（基本设置、快捷键、条目数等）
- 清空历史、打开偏好、退出应用

## 实现要点

- 语言：Swift 5+
- UI：AppKit（使用 NSStatusBar 创建菜单栏状态项，NSMenu / NSStatusItem 绘制用于粘贴板历史菜单）+ SwiftUI（用于偏好设置、编辑窗口）
- 剪贴板监听：NSPasteboard（通过 changeCount 定时轮询）
- 存储：当前为内存保留（可扩展为 File Codable / Core Data / Realm）
- 异步/响应式：Combine（订阅 ClipboardManager.items 自动刷新菜单）
- 全局快捷键：HotKey (soffes/HotKey) 
- 测试：XCTest（单元测试 + UI Tests）（暂未启用，后续添加）
- CI：GitHub Actions（macos-latest）（暂未启用，后续添加）

## 开发与本地运行（开发者）

1. 安装 Xcode（建议 Xcode 14+），目标最低 macOS: 12
2. 克隆仓库
   git clone https://github.com/gengsa/ClipBar.git
3. 启用 githooks（可选）
    chmod +x .githooks/pre-commit
    git config core.hooksPath .githooks
4. 打开 Xcode 项目
   open ClipBar/ClipBar.xcodeproj
5. 在 Xcode 中选择运行目标（My Mac），按 ⌘R 或 使用 Run 按钮
    从 Xcode 运行，需要将 build 后的软件添加到”系统偏好设置 → 安全性与隐私 → 隐私 → 辅助功能”中，以允许自动粘贴生效
6. 运行测试：Product → Test（或 xcodebuild test）

## License

This project is licensed under the Apache License 2.0 — see the [LICENSE](LICENSE) file for details.

# ClipBar

简短说明
- ClipBar 是一个用于 macOS 的多重粘贴板管理工具（菜单栏常驻，使用 Swift + SwiftUI 开发）。
- 目标用户：频繁复制粘贴文本/代码/图片/文件的开发者与内容创作者。
- 当前阶段：MVP

核心功能（MVP）
- 监听并存储系统剪贴板历史（文本、图片、链接、富文本、文件等）
- 菜单栏图标常驻，快捷键或点击唤出历史列表
- 在列表中预览、搜索、选择并粘贴到当前焦点应用
- 本地持久化（可配置最大条目数、导入/导出）
- 基本偏好设置（基本设置、快捷键、条目数等）

技术栈（建议）
- 语言：Swift 5+
- UI：SwiftUI（macOS App lifecycle）
- 异步/响应式：Combine
- 剪贴板访问：NSPasteboard（通过 changeCount 轮询或轻量监听策略）
- 存储：Core Data（优先）
- 全局快捷键：HotKey / MASShortcut / Carbon 封装库
- 测试：XCTest（单元测试 + UI Tests）
- CI：GitHub Actions（macos-latest）（暂不启用，后续再添加）

开发与本地运行（开发者）
1. 安装 Xcode（建议 Xcode 14+），目标最低 macOS: 12（你选择的 macOS 12）
2. 克隆仓库
   git clone https://github.com/gengsa/ClipBar.git
3. 打开 Xcode 项目
   open ClipBar/ClipBar.xcodeproj
4. 在 Xcode 中选择运行目标（My Mac），按 ⌘R 或 使用 Run 按钮
5. 运行测试：Product → Test（或 xcodebuild test）

实现要点（参考）
- 剪贴板监听：通常通过 NSPasteboard.general.changeCount 的定期检查（Combine + Timer），或结合 AppKit 的事件/策略优化。
- 菜单栏：使用 NSStatusBar 创建菜单栏状态项，SwiftUI 内容通过 NSHostingController 嵌入到菜单或弹窗中。
- 全局快捷键：推荐 HotKey (soffes/HotKey) 或 MASShortcut；注意 App Sandbox 的影响。
- 数据模型：ClipItem（类型 text/image/file 等、内容引用、时间戳、标签/备注）。
- 权限/沙盒：若计划上架 Mac App Store，注意沙盒对文件访问与剪贴板的限制。


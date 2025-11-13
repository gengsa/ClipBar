# 贡献指南

欢迎为 ClipBar 贡献代码！下面是推荐的流程与规范。

流程
1. 在开始前先打开 Issue 讨论你的设计/改动（若是小修复可直接提交 PR）。
2. 从 main 拉出 feature 分支，命名建议：
   - feat/<简短描述>
   - fix/<简短描述>
3. 编写代码并尽量添加测试（XCTest）。
4. 提交 PR：描述变更、原因、测试方法与复现步骤；如有界面截图或演示请附上。
5. PR 将由至少一名维护者审查，按需修改后合并。

代码规范（建议）
- 使用 SwiftLint（可选）
- 使用 Xcode 的格式化工具，保持代码风格一致
- 小而频繁的提交，清晰的 commit message（推荐 Conventional Commits）

本地开发
- 请使用与仓库相同的 Xcode 版本和 macOS target（最低 macOS 12）
- 在提交前运行测试：Product → Test

感谢你的贡献！


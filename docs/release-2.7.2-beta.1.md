# Clipio 2.7.2-beta.1 / 剪贴板交互与位置修复

App version 2.7.2, build 63. macOS 14+, Apple Silicon and Intel.

## 简体中文

- 修复在剪贴板和文件收集区之间按 Tab 切换时，顶部工具栏上下偏移的问题。
- 剪贴板卡片的悬停高亮与预览使用同一个目标，清理离开屏幕的卡片位置缓存。
- 右键点击剪贴板卡片，可从历史中移除这一项。
- 包含从「信息」拖入图片时保存独立副本的修复，以及设置中的透明度实时预览。
- 本次不提供手动拖动排序；保留原有排序设置。剪贴板数据库结构未因这次交互修复改变。

安装：下载 **Clipio-2.7.2-beta.1.dmg**，打开后把 Clipio 拖入「应用程序」。更新时先退出旧版，再替换。也提供 ZIP。历史与收集数据沿用原有本地位置。

这是公开测试版。另一台 Mac、跨磁盘移动和系统重启后的完整流程仍未独立验证；部分新增文字在中文以外的语言中显示为英文。更新采用手动安装。

## English

- Keep the top toolbar in place when Tab switches between Clipboard and Collection.
- Use one hover target for clipboard highlights and previews, and discard offscreen card geometry.
- Remove an individual clipboard entry from its context menu.
- Include the Messages image-drop fix and the live transparency preview in Settings.
- Manual drag ordering is omitted. Existing sorting settings remain; this interaction update does not change the clipboard database schema.

Install **Clipio-2.7.2-beta.1.dmg**, open it and drag Clipio into Applications. Quit the previous version before replacing it. A ZIP is also available. Existing history and collection data keep their current local locations.

This is a public beta. Independent installation on another Mac, cross-disk moves and the complete workflow after a system restart remain unverified. Some new strings appear in English outside Chinese. Updates are manual.

## Verification / 验证

- Required Debug build, 131 unit tests and 10 selected UI regressions passed. The UI run covers repeated Tab switching with stable header/search/window geometry, targeted context-menu removal, hover then keyboard selection, copy, search, Pin and collection shortcuts/separation.
- The Tab regression failed against the previous layout with a measured 4pt header shift and passed after top alignment.
- Earlier UI runs had startup/focus failures; the test harness now activates the nonactivating menu app without reopening/toggling it. The geometry assertion targets the shelf window instead of the separate hover preview. Those failed attempts remain in the local logs; the final ten-test run passed as a single group.
- Universal Release app (arm64 + x86_64): Developer ID signed, Apple notarization Accepted, stapled, Gatekeeper accepted. Final ZIP/DMG validation and local replacement are recorded in the release evidence after completion.
- Clipboard model, History and Sorter match the prior master implementation; the cancelled manual-order field is absent. No new clipboard database migration is introduced.

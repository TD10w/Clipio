# Clipio 2.8.3-beta.1

Collection import fixes for this beta:

- App-private files such as chat videos, PDFs, audio and archives are kept as bounded owned copies, preserving their content and originals.
- File URL representations share the same source-protection rules; unavailable videos are not silently replaced by thumbnails, and empty videos are rejected.
- Readable image URLs can be imported without a separate image representation while retaining image validation.
- User cloud-drive paths remain ordinary file references instead of being misclassified as app-private media.
- Clearing a global shortcut keeps shelf keyboard navigation available; stopped monitors can be started again. Outdated shortcut help was removed in all supported languages.
- Retains the official Sparkle 2.9.3 update-installer repair from 2.8.2.

## 中文说明

- 修正聊天应用中的视频、PDF、音频、压缩包等文件导入，保留原内容和原件。
- 统一文件地址的原件保护；不可用视频不再误收成缩略图，空视频不加入收集区。
- 支持只有可读取文件地址的图片，保留图片大小和像素校验。
- 修正用户云盘文件被误判为应用私有文件的问题，继续保存普通文件引用。
- 修正清除/重设快捷键后的面板键盘监听；清理 31 种语言中失效的快捷键提示。
- 保留 2.8.2 中 Sparkle 2.9.3 的更新安装修复。

App-private saved copies have a 64 MiB per-item limit and 128 MiB default total budget. Save larger or generated-only files to a Finder folder first, then collect their location. Accepted drops consume unpinned entries; chat send/upload completion is not observed.

Prepared for macOS 14 and later, Apple silicon and Intel. Real WeChat-source, shortcut-recording and another-Mac acceptance remain open for this beta. See [the readiness review](beta-readiness-review-2026-11-12.md).

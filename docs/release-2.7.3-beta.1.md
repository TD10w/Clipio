# Clipio 2.7.3-beta.1 — Getting Started

App version 2.7.3, build 65. macOS 14+, Apple Silicon and Intel.

## 简体中文

- 第一次打开时显示三页上手指南：找到菜单栏入口、认识剪贴板、认识收集区。
- 指南使用简短英文，显示当前实际设置的快捷键；可以跳过，关闭后不会每次启动都出现。
- 点击齿轮菜单里的 **Getting Started** 可以重新查看；设置 → General 里也有同名入口。
- 沿用 2.7.2 的剪贴板与文件收集功能，本次不改变历史或文件的存储格式。
- 修复收集区常驻入口遮挡其他菜单栏图标的问题：入口现在由 macOS 分配位置，拖文件时的接收胶囊仍显示在菜单栏下方。

安装：下载 **Clipio-2.7.3-beta.1.dmg**，打开后把 Clipio 拖入「应用程序」。更新时先退出旧版，再替换。也提供 ZIP。已有用户更新后会看到一次指南，之后可以随时从上述入口重看。

这是公开测试版。另一台 Mac、跨磁盘移动及系统重启后的完整流程仍未独立验证；本次上手指南在所有系统语言下均使用英文。更新采用手动安装。

## English

- A three-page guide appears on first launch: find the menu-bar icon, open Clipboard, and use Collection.
- The guide shows your configured shortcuts, including when a shortcut is not set. Skip or close it to keep it from appearing on every launch.
- Open **Getting Started** from the gear menu or Settings → General to view the guide again.
- Existing clipboard and file-collection behavior is retained. This release does not change clipboard or collection storage formats.
- Fix the idle Collection entry covering other menu-bar icons. macOS now allocates its menu-bar position; the file-drop receiver remains below the menu bar while dragging.

Install **Clipio-2.7.3-beta.1.dmg**, open it and drag Clipio into Applications. Quit the previous version before replacing it. A ZIP is also available. Existing users see the guide once after updating and can reopen it at any time.

This is a public beta. Independent installation on another Mac, cross-disk moves and the complete workflow after a system restart remain unverified. The guide uses English in every system language. Updates are manual.

## Checksums

SHA-256 sidecars are provided for both downloads. In Terminal, run `shasum -a 256 -c Clipio-2.7.3-beta.1.dmg.sha256` from the download folder, or use the corresponding ZIP sidecar.

## Verification / 验证

- The required Debug build and all 134 unit tests passed. The idle-menu overlap regression failed on the previous implementation and passed after the fix.
- Six affected UI regressions passed in batches, covering collection preservation, both shortcuts, Tab switching with the native entry enabled, and onboarding. A shortcut test mistook the transparent prewarm panel for an opened shelf; the harness now uses the existing launch-open flag. Earlier failed attempts are retained in the project evidence; a single all-green full UI suite is not claimed.
- The final build is 65; earlier unpublished build 64 packages are superseded. The packaged app contains arm64 and x86_64 code and all 31 language tables with the approved English guide.
- Automated checks do not replace another-Mac installation or the user's real-world menu-bar/drag experience.

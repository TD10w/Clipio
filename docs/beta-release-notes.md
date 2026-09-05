# Clipio 2.6.1-beta.1 — early public beta / 早期公开测试版

## English

A horizontal clipboard shelf for macOS, built on Maccy. Browse text, images, files and colors, search history, and pin frequently used items.

**Requires macOS 14 or later.** One universal ZIP supports Apple Silicon and Intel. The app is Developer ID signed, accepted by Apple notarization, and stapled; the final ZIP was extracted and passed signature, stapling, and Gatekeeper checks locally.

### Install

1. Download **Clipio-2.6.1-beta.1.zip** from Assets below (not “Source code”).
2. Extract it and drag **Clipio.app** into **Applications**, then open it.
3. Find Clipio in the menu bar or press **Shift + Command + C**.
4. **Return** copies a card; paste manually with **Command + V**. For automatic paste with **Option + Return**, enable Clipio under System Settings → Privacy & Security → Accessibility.

No Xcode is needed. Updates are manual. Read the [README](https://github.com/TD10w/Clipio#readme) for usage and privacy details.

### Testing status and limitations

- Debug and universal Release builds passed; 85 core tests passed with no failures.
- **Installation on a second Mac and the complete UI checklist have not been verified.** Four UI smoke tests could not start because macOS automation mode timed out; they are not counted as passed.
- Image/file dragging can vary by destination app. Some inherited translations may still say Maccy. Database failure recovery needs further work; do not keep your only copy of important content in clipboard history.
- Clipboard history stays local but has no app-level encryption. Use sample content in public bug reports.

Please report your macOS version, CPU type, steps, and expected/actual result in [Clipio Issues](https://github.com/TD10w/Clipio/issues/new/choose).

## 简体中文

基于 Maccy 的 macOS 横向剪贴板卡片栏，支持浏览文字、图片、文件与颜色，搜索历史并置顶常用内容。

**需要 macOS 14 或更高版本。** 同一个 ZIP 支持 Apple Silicon 和 Intel。已完成 Developer ID 签名、Apple 公证及凭据附加，最终安装包重新解压后也通过了本机签名、公证凭据和 Gatekeeper 检查。

### 安装

1. 从下方 Assets 下载 **Clipio-2.6.1-beta.1.zip**，不要下载“Source code”。
2. 解压，将 **Clipio.app** 拖入“**应用程序**”，然后打开。
3. 从菜单栏打开 Clipio，或按 **Shift + Command + C**。
4. **Return** 复制卡片，再按 **Command + V** 手动粘贴。需要 **Option + Return** 自动粘贴时，在“系统设置 → 隐私与安全性 → 辅助功能”中允许 Clipio。

不需要 Xcode，目前采用手动更新。使用方法与隐私说明见[中文 README](https://github.com/TD10w/Clipio/blob/master/README.zh-CN.md)。

### 测试状态与限制

- Debug、通用 Release 构建通过，85 项核心测试全部通过。
- **另一台 Mac 的安装体验和完整界面流程尚未验证。** 四项界面测试因为自动化模式启动超时未能执行，没有计入通过。
- 图片或文件拖拽效果可能受目标应用影响；部分旧翻译可能仍显示 Maccy。数据库故障恢复仍需完善，不要把重要内容的唯一副本保存在剪贴板历史中。
- 历史保存在本机，但没有应用层加密。公开反馈时请使用示例内容。

欢迎通过 [Clipio Issues](https://github.com/TD10w/Clipio/issues/new/choose) 反馈，请提供 macOS 版本、芯片类型、操作步骤与预期/实际结果。

## Optional checksum / 可选校验

Download both the ZIP and its `.sha256` file into the same folder. In Terminal, open that folder and run:

将 ZIP 和对应的 `.sha256` 文件下载到同一个文件夹，在终端进入该文件夹后运行：

```bash
shasum -a 256 -c Clipio-2.6.1-beta.1.zip.sha256
```

Expected result / 预期结果: `Clipio-2.6.1-beta.1.zip: OK`.

SHA-256: `81e99c3d8bc7b35df881b7c87e3536ca501a05aed385c51a7749dd387fb79e87`.

App version: `2.6.1` (build `60`). Source: release tag `v2.6.1-beta.1`. Documentation-only changes since the artifact build do not alter the app source.

# Clipio

[English](README.md) · [简体中文](README.zh-CN.md)

**找回复制过的内容，把要移走的文件先收在一起。**

Clipio 是一款原生 macOS 剪贴板管理工具，提供横向卡片栏和文件收集区。复制过的文字、图片、链接和颜色可以搜索、预览；散落在不同位置的文件可以先收在一起，再拖到目标位置。

[![下载 Clipio macOS 版](docs/screenshots/download-macos.svg)](https://github.com/TD10w/Clipio/releases/download/v2.9.1/Clipio-2.9.1.dmg)

**[下载 2.9.1 版（.dmg）](https://github.com/TD10w/Clipio/releases/download/v2.9.1/Clipio-2.9.1.dmg)** · [版本说明](https://github.com/TD10w/Clipio/releases/latest)

打开下载的 DMG，将 **Clipio.app** 拖入“**应用程序**”。

macOS 14+ · Apple Silicon 和 Intel · 已签名并通过 Apple 公证 · 免费开源

![Clipio 演示：剪贴板历史、文件收集、Stack 展开与收藏](docs/screenshots/clipio-demo.gif)

*30 秒演示 · 无声预览*

## 剪贴板

找回刚才复制的链接、预览图片、重复使用一段文字，不必再回原来的应用翻找。直接输入文字搜索，鼠标悬停查看预览，常用内容可以加星，之后在“收藏”里取用。

按 **Shift + Command + V** 打开卡片栏，选中卡片按 **Return**，再用 **Command + V** 粘贴。

![Clipio 横向卡片栏中的剪贴板历史](docs/screenshots/clipio-shelf.png)

## 文件收集区

从不同文件夹挑文件时，可以先收在这里，再一起拖到 Finder 文件夹或其他应用。把文件、文件夹或图片拖到屏幕上方的 **Drop Zone**。一次放入的多个文件会叠成一个 **Stack**，点一下即可展开。按 **Tab** 在剪贴板和收集区之间切换。

![Clipio 文件收集区](docs/screenshots/clipio-collection.png)

普通收集项拖到 Finder 会移动原文件；先 **Pin** 再拖出，则会复制文件，并保留收集项。

## 开始使用

1. 下载并打开 DMG，将 **Clipio.app** 拖入“**应用程序**”。
2. 打开 Clipio，它会在**菜单栏**运行，并用一个简短引导带你选好快捷键、亲手试一次。
3. 复制一些内容，按 **Shift + Command + V** 打开剪贴板历史。
4. 选中卡片按 **Return**。如果在引导里允许了自动粘贴，内容会直接贴到你正在输入的位置；否则再按 **Command + V**。
5. 试试文件收集：把几个示例文件一起拖到 Drop Zone，点开 Stack，再把其中一个文件拖到 Finder 文件夹。普通文件会移动，想保留原件时请先 Pin。

使用下载版不需要 Xcode，也不用输入终端命令。

自动粘贴需要在**系统设置 → 隐私与安全性 → 辅助功能**里打开 Clipio。引导会直接带你到这一页；列表里没有 Clipio 时，点 **+** 手动添加。引导随时可从齿轮菜单 → **Getting Started** 重新查看。

## 快捷键

| 快捷键 | 功能 |
| --- | --- |
| Shift + Command + V | 打开剪贴板历史 |
| Shift + Command + C | 打开文件收集区 |
| Tab | 切换剪贴板与收集区 |
| Return | 复制选中的剪贴板内容 |
| Option + Return | 粘贴到当前应用 |
| Option + P | 收藏剪贴板内容 / Pin 收集项（再次按下取消） |
| Escape | 关闭卡片栏 |

以上为默认设置；快捷键和粘贴行为都可以在设置中修改。

## 隐私

剪贴板历史保存在你的 Mac 上，没有云同步或使用分析，也没有应用层历史加密。复制敏感内容前，可以设置忽略相关应用或暂停记录。

收集区保存普通本地文件的引用；浏览器图片和支持导入的应用私有目录文件会保存为 Clipio 本机数据中的副本，保留来源文件。移除收集项不会删除原文件。重要内容请另留副本。详见[导入限制与文件行为](docs/usage.zh-CN.md#文件收集区)。

## 更新与反馈

官方下载版支持在**设置 → 通用 → 检查更新**中更新。也可以退出 Clipio，下载新版本，再替换“应用程序”里的旧版本。

已知限制：文件拖拽可能受目标应用影响，跨磁盘移动和跨显示器拖拽尚未验证；部分界面文字目前仅有英文。

第一次用 Clipio？欢迎告诉我们：你拿它做了什么、哪里好用、哪里卡住了。[分享反馈或报告问题](https://github.com/TD10w/Clipio/issues/new/choose)时，请附上 Clipio 版本、macOS 版本；遇到问题时请写出复现步骤。截图请使用示例内容。

[更多用法与常见问题](docs/usage.zh-CN.md) · [从源码构建](docs/development.md)

## 致谢

由 [TD10w](https://github.com/TD10w) 设计和开发，基于 Alex Rodionov 及贡献者的 [Maccy](https://github.com/p0deje/Maccy)。代码采用 [MIT 许可证](LICENSE)。

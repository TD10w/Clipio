# Clipio Apple 27 设计方向

更新于 2026-11-09。本文记录用户已确认的设计方向、前期比较和待验收草图。

## 已确认方向

- 用户选择 Apple 原生感觉与 Liquid Glass。界面采用系统动态色和材质，强调色按系统设置处理。
- 字体采用全部系统标准字体，包括 Clipio 名称、正文、搜索和元信息。英文使用系统 SF Pro，中文跟随系统回退。
- 用户在查看简化草图后要求换回原版香蕉装小马。继续使用现有应用图标，停止推进简化概念。
- 当前设计分支已制作原生浅深色试排并整合文件收集功能，仍待视觉与设备验收后合入主线。

## 设计依据

- [Apple Design Resources](https://developer.apple.com/design/resources/) 提供 iOS／iPadOS 27 与 macOS 27 的 UI Kit、图标模板、字体和 Icon Composer。
- 用户提供的 [iOS／iPadOS 27 参考库](https://www.figma.com/design/ij1BCNmIRIoShBaluPqM6n/) 已读取过组件目录、材质与输入框示例。
- 用户提供的 [Clipio 设计工作文件](https://www.figma.com/design/JB45A7RLU6qS3yypgA7cSv/Untitled) 在 2026-11-09 核对时为一个空白页面，已启用 macOS 27 和 iOS／iPadOS 27 组件库；macOS Search Field 与 Button 可检索。
- Clipio 的目标界面为 macOS 顶部横向卡片架。桌面布局、鼠标、键盘、菜单栏和多显示器行为由 macOS 方案约束。

## 材质与颜色

主面板采用动态系统材质、主次文字色和系统强调色。品牌颜色集中于应用图标和少量强调位置。浅色、深色、增强对比度与降低透明度需要一起检查。

前期比较包含系统蓝、青绿和暖橙。用户随后明确了原生 Liquid Glass 方向。比较页中的色值保留为 macOS 27.2 本机系统色取样，实施时使用语义颜色与系统强调色 API。

设计分支已去除青色、粉色边缘与彩色悬停光晕，改用系统材质、语义文字色和系统强调色。浅深色样例用于检查文字、选中边框、固定标记和预览的层次。参考 [Apple 色彩指南](https://developer.apple.com/design/human-interface-guidelines/color)。

## 字体与前期比较

| 方向 | 英文与数字 | 中文 | 拟用位置 |
| --- | --- | --- | --- |
| 系统标准 | SF Pro | 系统中文回退，通常为苹方 | 正文、搜索、设置和元信息 |
| 系统圆体 | SF Pro Rounded | 系统中文回退 | Clipio 字标和少量强调文字 |
| 系统衬线 | New York | 本机实际回退为宋体 | 标题方向试排 |

用户已选择全部系统标准字体。Clipio 名称也使用标准体。正文从 13 pt、搜索 13 pt、元信息 11.5 pt、字标 17 pt 起做试排，再用真实卡片内容验证信息量；这些字号仍需原型检验。代码和颜色值使用系统等宽字体。

旧版卡片正文为 11.5 pt，元信息为 10 pt，搜索为 13 pt；本轮已将正文和元信息试排为 13／11.5 pt。比较素材使用 macOS 原生字体 API 渲染中英文样例。字号和密度仍待视觉确认。

[颜色与字体比较页](../Designs/explorations/2026-11-09-style-study/index.html) 可切换字体、浅深色和三种色调，并展示 SF Symbols 与现有图标的小尺寸样例。原生解析得到的字体名、中文回退和颜色值记录在[样例来源](../Designs/explorations/2026-11-09-style-study/native-samples.json)。系统标准与圆体均回退到苹方，圆体的主要变化体现在英文和数字；衬线方向的中文回退到宋体。

参考 [Apple 字体资源](https://developer.apple.com/fonts/) 和[字体排印指南](https://developer.apple.com/design/human-interface-guidelines/typography)。

## 图标

- 界面操作符号采用 SF Symbols，统一字重、尺寸和光学对齐。搜索、设置、清空、固定等控件同时提供清楚的操作名称。
- 菜单栏图标按实际小尺寸单独检查轮廓与识别度。
- 用户查看第一版简化概念后要求恢复原版。应用图标 PNG 图像集与主线一致，未采用简化版本。
- 简化 PNG 与生成记录保留为历史探索，不再作为待确认或待实施方案。

参考 [SF Symbols](https://developer.apple.com/sf-symbols/)、[应用图标指南](https://developer.apple.com/design/human-interface-guidelines/app-icons) 和 [Icon Composer](https://developer.apple.com/icon-composer/)。

## 选择与验收

基础方向已确认。下一步验收主面板浅深色的材质、字重与信息密度。图标继续使用原版。实施时补齐搜索、悬停、选中和固定状态，并检查长中文、长文件名和键盘焦点。

Dropzone 已演进为单收集区加 Pin。普通项被目标接受拖出后移除，取消保留，Pin 项保留；剩余内容重启保留。本地文件引用原件，网页图片本地保存。面板位于刘海下方，收起时使用刘海旁的计数入口。⌘⇧V 打开剪贴板，⌘⇧C 打开收集区；单图标与 Tab 切换，两种模式分别搜索。完整范围见[需求记录](plans/2026-11-09-dropzone-discussion.md)。

[原生评审素材](../Designs/explorations/2026-11-09-liquid-glass/README.md) 包含剪贴板／收集区浅深色窗口截图及交互比较页。截图中的简化小马图片只是剪贴板示例内容，属于已否决的历史探索。Figma 工作文件仅建立框架 `4:2`，组件导入受权限限制，随后达到 Starter MCP 调用上限，可编辑稿待补齐。

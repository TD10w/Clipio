# Clipio Apple 27 设计方向

更新于 2026-11-09。本文记录待用户选择的设计候选和参考依据。当前阶段为设计讨论。

## 设计依据

- [Apple Design Resources](https://developer.apple.com/design/resources/) 提供 iOS／iPadOS 27 与 macOS 27 的 UI Kit、图标模板、字体和 Icon Composer。
- 用户提供的 [iOS／iPadOS 27 参考库](https://www.figma.com/design/ij1BCNmIRIoShBaluPqM6n/) 已读取过组件目录、材质与输入框示例。
- 用户提供的 [Clipio 设计工作文件](https://www.figma.com/design/JB45A7RLU6qS3yypgA7cSv/Untitled) 在 2026-11-09 核对时为一个空白页面，已启用 macOS 27 和 iOS／iPadOS 27 组件库；macOS Search Field 与 Button 可检索。
- Clipio 的目标界面为 macOS 顶部横向卡片架。桌面布局、鼠标、键盘、菜单栏和多显示器行为由 macOS 方案约束。

## 颜色候选

主面板采用动态系统材质、主次文字色和系统强调色。品牌颜色集中于应用图标和少量强调位置。浅色、深色、增强对比度与降低透明度需要一起检查。

供选择的方向为系统蓝、青绿和暖橙。比较页中的色值来自当前 macOS 27.2 的系统颜色解析，是本机取样。最终应用使用语义颜色与系统强调色 API。

当前代码含青色、粉色边缘和固定白色标记。下一版需要用浅深色样例检查文字、选中边框、固定标记和预览的层次，再确定装饰强度。参考 [Apple 色彩指南](https://developer.apple.com/design/human-interface-guidelines/color)。

## 字体候选

| 方向 | 英文与数字 | 中文 | 拟用位置 |
| --- | --- | --- | --- |
| 系统标准 | SF Pro | 系统中文回退，通常为苹方 | 正文、搜索、设置和元信息 |
| 系统圆体 | SF Pro Rounded | 系统中文回退 | Clipio 字标和少量强调文字 |
| 系统衬线 | New York | 本机实际回退为宋体 | 标题方向试排 |

初步建议为 SF Pro 正文配圆润字标。正文从 13 pt、搜索 13 pt、元信息 11.5 pt、字标 17 pt 起做试排，用户选定后再用真实卡片内容验证信息量。代码和颜色值使用系统等宽字体。

当前卡片正文为 11.5 pt，元信息为 10 pt，搜索为 13 pt；较小的文字需要在实际 820 × 220 pt 面板中检查。比较素材使用 macOS 原生字体 API 渲染中英文样例，供视觉选择。此阶段的字号是候选。

[颜色与字体比较页](../Designs/explorations/2026-11-09-style-study/index.html) 可切换字体、浅深色和三种色调，并展示 SF Symbols 与现有图标的小尺寸样例。原生解析得到的字体名、中文回退和颜色值记录在[样例来源](../Designs/explorations/2026-11-09-style-study/native-samples.json)。系统标准与圆体均回退到苹方，圆体的主要变化体现在英文和数字；衬线方向的中文回退到宋体。

参考 [Apple 字体资源](https://developer.apple.com/fonts/) 和[字体排印指南](https://developer.apple.com/design/human-interface-guidelines/typography)。

## 图标

- 界面操作符号采用 SF Symbols，统一字重、尺寸和光学对齐。搜索、设置、清空、固定等控件同时提供清楚的操作名称。
- 菜单栏图标按实际小尺寸单独检查轮廓与识别度。
- 应用图标需要用户决定保留香蕉装小马并简化，或改用简洁图形。确认主体后制作 Icon Composer 分层方案，并检查默认、深色和单色外观。
- 当前应用图标为 PNG 图像集。分层图标素材的制作、预览和最终打包属于后续实施步骤。

参考 [SF Symbols](https://developer.apple.com/sf-symbols/)、[应用图标指南](https://developer.apple.com/design/human-interface-guidelines/app-icons) 和 [Icon Composer](https://developer.apple.com/icon-composer/)。

## 选择与验收

需要用户选择颜色方向、字标和正文字体组合，以及应用图标主体。选定后制作主面板的浅色、深色、搜索、悬停、选中和固定状态，并检查长中文、长文件名、键盘焦点和小尺寸识别度。

Dropzone 的使用流程与文件生命周期在独立会话确认。整体字体、颜色和图标方向由本设计记录接续。

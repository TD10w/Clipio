# 待办：收集区项目无法拖入 macOS 废纸篓

状态：已完成代码修复与隔离单元验证；真实 Dock 废纸篓拖放待验证，尚未安装或发布。

来源：用户于 2026-11-11 本次会话要求继续记录。

> 在记录， dropzone 拖到 trash can， 废纸篓，
>
> 他现在拖不到，要处理

## 问题与期望

用户反馈：从 Drop Zone／收集区向 macOS 废纸篓拖出项目，目前无法完成。后续需要调查并处理，使该拖放操作能够按预期使用。

## 后续核对

- 先在实际运行版本复现，记录拖出项类型、废纸篓接收反馈与磁盘结果，不预设原因。
- 普通文件、Pin 项、浏览器图片及 Stack 的处理语义需在实施时核对；本次不自行决定其原文件、收集卡片应如何变化。
- 区分“拖入系统废纸篓”和“从收集区移除卡片”，不能用其中一个操作代替另一个。
- 需求记录时仅记录；2026-11-11 用户授权开始处理，要求尽量不用 computer use。

## 2026-11-11 修复进展

- 代码缺口：拖出仅声明 move/copy，没有 Dock Trash 使用的 delete；结束回调也忽略 delete。依据 [Apple 拖动源说明](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/DragandDrop/Concepts/dragsource.html)。
- 无 Pin 的批次增加 delete 操作；含 Pin 的批次继续保持原有移动/复制保护，不开放 delete。Pin 删除语义仍待产品讨论。
- delete 回调沿用现有移动核对：只有导出文件确实离开原位置才移除对应非 Pin 卡片。部分完成只移除已完成项；延迟完成使用文件事件监听；取消或未移动保留卡片。
- 文件操作仍由系统目标处理；Clipio 不主动 trash/delete 本地原件，不更改只读书签或沙箱权限。**Dock 是否实际移动文件、真实拖放是否成功，尚无本次实机证据，不能以单元测试替代。**
- 新增 5 项回归，先在旧代码运行得到 6 个预期失败断言，修复后全部 139 项单元测试通过。测试只在独立 bundle `com.clipio.app.trashtests`、内存历史库和临时合成文件中运行；目的地用临时目录模拟，没有操作真实废纸篓。
- 日志：`/tmp/clipio-trash-baseline.log`（134 项基线）、`/tmp/clipio-trash-red.log`（失败回归）、`/tmp/clipio-trash-green.log`（139 项通过）、`/tmp/clipio-trash-final-tests.log`（补强网页图片延迟完成断言后，139 项全部通过）。
- 项目规定的 unsigned Debug 编译通过（`BUILD SUCCEEDED`），日志 `/tmp/clipio-trash-required-build.log`。
- 未运行会控制鼠标的 UI 测试；未替换日用版、未公开发布。

## 空闲时一次核对

使用独立体验数据与可丢弃文件，检查 Dock 是否接受普通文件、文件夹、无 Pin Stack 和网页图片；落放后核对废纸篓里的内容、原位置和卡片。另核对取消、失败及 Pin/混合批次的保护。若 Dock 只返回 delete 而没有搬走文件，卡片应保留；届时再根据真实行为确定是否需要单独的系统回收流程，不静默永久删除。

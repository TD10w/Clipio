# 待办：Drop Zone 收入成功的音效与 UI 反馈

状态：已按用户选定方案接入原生代码；隔离回归与编译通过，真实音画体验待验收；未安装、未发布。

来源：用户于 2026-11-11 口述，明确要求“先记下来”。

> 然后有一个 task，之后要做的就是加入音效和ui特效。当这个某个东西加入到了 Drop Zone的时候，这样他们就知道这个东西被收入了。

## 目标

文件、图片等项目成功加入 Drop Zone／收集区后，通过音效和 UI 特效，让用户明确知道“这个东西已经被收下”。

## 后续处理边界

- 实施前先核对现有收入流程和反馈能力，避免重复实现。
- 成功反馈应对应实际收入成功；悬停、拖动经过、取消或失败不能被误报为成功。
- 具体音效、动效样式，以及连续／批量收入的反馈方式留待后续讨论，不在本次预设。
- 本次只保存任务，不改应用代码，不制作音效或动效，不派发实现工作。

相关历史反馈：[11 月 10 日体验记录](../acceptance-feedback-2026-11-10.md)。

## 2026-11-11 设计讨论

- 用户已选择视觉预览 C 的轻弹 + B 的勾号；不显示“已收好 / 数量”文字。
- 原先选择复用按 Command+C 被 Clipio 收入时的 Write 音效；用户随后要求用 sound skill 再设计声音，因此最终音效重新开放试听，未定稿。
- 一批真正收入成功只反馈一次；取消或全部失败不播放成功反馈。部分失败的具体反馈仍需设计。
- [三个视觉方向](../../Designs/explorations/2026-11-11-receipt-feedback/index.html) 与 [音效试听](../../Designs/explorations/2026-11-11-receipt-feedback/sound-study/index.html) 均为独立 HTML 比较稿，不是已实现的原生行为。
- 音效候选的 CC0 来源、下载/评分记录与加工方式见[试听说明](../../Designs/explorations/2026-11-11-receipt-feedback/sound-study/README.md)。
- 第一轮试听后用户反馈“还差一点，想要收集的感觉”，未选定任何候选。[第二轮试听](../../Designs/explorations/2026-11-11-receipt-feedback/sound-study-v2/index.html) 改为靠近、接住和落定的短声音组合；视觉保持轻弹＋勾号，仍待试听确认。

## 2026-11-11 最终选择与实现

用户试听第二轮后明确选择 A（“A it is”）。已接入原生小胶囊：0.38 秒 A 音效 + C 的轻弹 + B 的勾号；不显示数量文字，约 1 秒后恢复/收起。声音与动画由同一成功事件触发。

- 一个完整成功且确实插入新项目的批次只触发一次；普通 provider、收集区 drop 和 file promises 使用同一批次统计。
- 重复、空批次、全失败、部分失败及保存失败不发完整成功提示；保留已成功保存的项及现有错误说明。
- 不靠总条数变化推断收入，不会因恢复历史、Pin、删除等操作响起；并发同文件重复收入也只确认一次实际插入。
- 反馈层不激活窗口并可穿透点击；新拖动恢复接收，Reduce Motion 下保留静态勾号。
- 实施方案：[设计](../superpowers/specs/2026-11-11-collection-receipt-design.md)、[计划](../superpowers/plans/2026-11-11-collection-receipt-feedback.md)。
- 独立代码复核发现的并发重复误报已用确定性回归重现并修复；没有用复核结论替代实际测试。
- 验证：134 项原始基线通过；新增回归先失败再通过；最终单元套件 140 项通过。规定 unsigned Debug 编译成功，实际包中音频逐字节匹配选定 A，31 份语言资源含成功辅助功能标签。
- 日志：`/tmp/clipio-receipt-red.log`、`/tmp/clipio-receipt-concurrent-red.log`、`/tmp/clipio-receipt-verified-tests.log`、`/tmp/clipio-receipt-final-build.log`。
- 边界：未使用 computer use、未运行控制鼠标的 UI 测试、未替换日用版。真实扬声器输出、动画与声音时序、Reduce Motion 和真实多文件 promise 交付仍待集中体验；不计为验收通过。

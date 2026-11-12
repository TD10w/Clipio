# Clipio 收入成功音效比较

日期：2026-11-11。状态：试听草案，未选定、未加入原生 App。

用户已选择原视觉预览 C 的轻弹 + B 的 check mark，不显示数量文字。原先选定复用 Command+C 收入声音；随后用户要求用 sound skill 再设计声音，因此最终音效重新开放试听。每批真正收入成功反馈一次、取消或全部失败不响的约定保留。

## 使用

打开 `index.html`，通过原生音频播放器单独听，或点击“配动画”比较相同视觉搭配下的听感。包含现有 Write.caf 音量对齐后的对照，以及三个 CC0 素材加工候选。文件完全自包含，无网络请求或个人数据访问；没有自动播放。

## 来源

下载使用 sound skill 的 `sfx.py freesound --license cc0 --urls` 与 `sfx.py get`。下载的是 Freesound HQ MP3 预览，尚未获取原始 WAV 母带。搜索结果、作者、许可、下载数及评分保存在 `sources.json`；来源副本保存在 `sources/`。

- A：Breviceps, Plop!, https://freesound.org/people/Breviceps/sounds/447910/ 。11,727 次下载，4.3 / 106 票，CC0；作者描述为 “A plop! sound”。原长约 0.243 秒。
- B：Joao_Janz, Digital Radio Rack Unit Button Snap 3_1, https://freesound.org/people/Joao_Janz/sounds/477706/ 。360 次下载，4.4 / 5 票，CC0；来源以标题所述数字广播机架按钮为依据，搜索结果未提取到详细描述。原长约 0.664 秒。
- C：GabFitzgerald, [UI Sound] Approval - High Pitched Bell Synth, https://freesound.org/people/GabFitzgerald/sounds/625174/ 。3,977 次下载，4.8 / 80 票，CC0；作者说明为 wavetable 合成的高音确认 UI 声。原长约 0.774 秒。

下载数和评分为本次查询快照，不表示听感结论。代理没有直接听取音色；候选依据描述、来源、长度和波形选取，最终靠用户试听决定。

## 处理与测量

`source-measurements.json` 记录解码后的总时长、峰值和累计能量位置；`processing.json` 记录候选滤波、增益及淡出。源 A 和 B 的 99% 能量均在前约 20ms 内，因此仅保留短尾，不拿源文件总长度当作有效声音时长。

- A：高通 100Hz / 低通 3500Hz，短版 0.13 秒，尾部淡出。
- B：高通 120Hz / 低通 4000Hz，短版 0.16 秒，尾部淡出。
- C：轻度降低音高，高通 120Hz / 低通 4800Hz，短版 0.60 秒，尾部淡出。
- 所有对照按最强 40ms RMS 对齐到 -27dBFS，且峰值不超过 -12dBFS；这是便于比较的测量控制，不等同于主观等响。默认播放器音量 65%，可调。
- 输出均为 44.1kHz / 16bit / mono WAV。`candidates/00-existing-reference.wav` 来自项目已有 `Clipio/Sounds/Write.caf`，只做声道和增益对齐，不截短。

JavaScript 语法检查通过，html_preview 无控制台消息；未声称验证本机扬声器输出或原生 App 行为。未调用 computer use，未修改或安装 App。

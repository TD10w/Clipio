# Clipio R2 候选交接

来源：用户体验 R1 后拒绝分段按键、要求一个 Star 标志，反馈 Shift+Tab 不好用，并明确普通文件/文件夹无法拖入 Dock 废纸篓。R1 相关三项未通过体验，不由以前的绿灯记录覆盖。

## R2 内容

- 搜索框左侧一个无胶囊边框的星标：空心=全部，金色实心=只看收藏。点击/Shift+Tab 共用切换动作并保留搜索词。
- Shift+Tab 只在剪贴板主界面、无中文组合输入及弹窗时匹配；普通 Tab、收集区和用户配置的打开快捷键仍保留原意。
- Dock delete 回调由源应用发起 NSWorkspace.recycle。只按系统逐项回收确认清理对应卡片；失败/部分失败保留未确认项，显示错误；无永久删除回退。
- 原文件快照身份、Pin/Pin 子项和异步导出锁保护已补回归。

## 两层根因与授权范围

R1 只有 delete 操作声明和路径观察，没有发起回收。进一步验证发现旧只读文件授权在冷启动后使系统回收返回 Cocoa 513。为实现用户明确要求的选入文件回收，R2 使用 App Sandbox 的 `user-selected.read-write`，只覆盖用户主动选入的文件/文件夹，并保存相应安全书签。

旧只读条目需从 Finder 重新拖入一次更新授权；addFile 保留原 ID、Pin、Stack，仅更新书签，不重复添加。若系统回报授权不足，界面明确提示此步骤。Pin 原件保护规则未改变。

主文档依据：[Apple Dragging Sources](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/DragandDrop/Concepts/dragsource.html)、[NSWorkspace recycle](https://developer.apple.com/documentation/appkit/nsworkspace/recycle(_:completionhandler:))。本机 SDK 的 NSWorkspace.h 同样明确逐项回收结果及部分错误语义。

## 实测证据

- 原候选运行文件与准备的 R1 可执行文件哈希一致。
- 初始新回归失败；复核的锁、不可读 Pin 子项和替换文件问题也先重现失败，随后修正。
- 最终全组 168 单元通过：`/tmp/clipio-r2-verified-tests.log`。
- 规定 unsigned Debug 与独立签名预览构建通过：`/tmp/clipio-r2-required-build.log`、`/tmp/clipio-r2-preview-build.log`。
- 真实 NSWorkspace 用独立临时文件完成系统 Trash/恢复；没有枚举或清空用户废纸篓。
- 后台无窗口沙箱探针：只读授权冷启动失败 513；选入读写授权的外部临时文件、文件夹回收成功并恢复。
- 用实际 CollectionStore/CollectionItem/RuntimeEnvironment 源码编译的探针验证旧只读条目重新选入、ID/Pin 保留、冷启动后回收文件/文件夹成功；重新签名后的冷启动也通过。只操作名称固定的合成临时内容，全部恢复。
- 探针源码和 JSON 对照保留在忽略目录 `build/trash-probe/`，不会打入体验包。31 份实际构建语言表含切换及授权更新提示；选定 A 音频保留。

## 体验包

- 源码 `f7abdc7`，候选 build `6702`，bundle `com.clipio.app.candidate20261111`。
- `build/Clipio候选体验-R2-20261111.zip`，8.7 MiB，内含 `Clipio-Candidate-R2.app`、`START-HERE.txt`。
- SHA-256 `a49514fb0a94b82f1ab2e30173bff6d5712cadc016b739fcdd22c59f70a14e7c`。
- 本机 ad-hoc Debug，签名/资源/ZIP CRC 已核对，不是公证发布包。
- R2 没有自动启动；没有替换正在运行的 R1 或日用版。先退出旧候选再开 R2，旧测试项从 Finder 重新拖入一次，更新授权后再试废纸篓。

真实 Dock 指针落放、原生 Shift+Tab/输入法/弹窗及星标观感仍待 R2 体验；没有将后台 API 检查写成这些场景已验收。旧数据范围与 UI 的 R1 反馈继续保留。

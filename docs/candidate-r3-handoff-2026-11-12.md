# Clipio R3 交接 — 2026-11-12

> **后续状态：R3 已整合为 2.8.0 beta.1（68），已发布并更新本机日用版。** 旧候选与构建包已归档；不要从下方历史状态重新发版。当前代码在 `.worktrees/star-candidate` 的 `release/2.8.0-r3-updates`；[最新本机记录](/Users/dubulu/AgentOS/Project/Clipio/.worktrees/star-candidate/docs/post-release-local-2026-11-12.md)，[归档索引](/Users/dubulu/AgentOS/Project/Clipio/build/Archive/2026-11-12-release-68/INDEX.md)。正式版与候选数据保持独立、未合并。

当前停在 **R3 候选已交付、等待真实体验**。不要直接发布，也不要把自动化通过写成用户已验收。下一步优先核对 R3 中的星标点击，以及从 Finder 废纸篓拖入 Drop Zone。

## 接手入口与代码位置

- 先读根目录 `AGENTS.md` → `CLAUDE.md`，遵守 brain-first 和编译后交接规则。
- 根 checkout：`/Users/dubulu/AgentOS/Project/Clipio`，本次交接核对为 `master`，HEAD `9b9ca17`（交接文档提交之前）。**这里不是 R3 实现工作区。**
- 实现工作区：`/Users/dubulu/AgentOS/Project/Clipio/.worktrees/star-candidate`。
- 实现分支：`feature/clipboard-star`；源码检查点 `db3d2cb`。交接时该工作区干净。
- 根目录未跟踪的 `Designs/Clipio-Showcase/` 是已有内容，不要清理、覆盖或顺手提交。
- 前序检查点：`39292de` Star，`7ab86c5` 初版 Trash，`e50e78a` 收集反馈，`f7abdc7` R2，`b71101a` R2 文档。不要从根 checkout 的旧代码重新实现这些能力。
- 详细 R3 计划：实现工作区 `docs/superpowers/plans/2026-11-12-drop-anything-hit-fix.md`。
- 前序交接：实现工作区 `docs/candidate-r2-handoff-2026-11-11.md`、`docs/star-candidate-handoff-2026-11-11.md`。

## 用户已定的方向

- 剪贴板 **Star** 用于长期保留常用文字、链接、图片；收集区 **Pin** 保护文件原件，两者不要混称。代码中的部分旧 `pin` 命名仍承载剪贴板 Star。
- 不要 All/Favorites 分段按键：用一个星标切换全部／收藏。R2 加入 Shift+Tab；其真实键盘体验仍需确认，用户曾报告旧版不好用。
- 收集反馈选择音效 A，配轻弹和 check mark；R3 保留原音频。
- 用户确认：旧文件夹从 Finder 重新拖入后，向系统废纸篓拖出已正常。不要继续把这个单项记成未通过。
- 新目标是“Drop anything”：文件、文件夹、图片、文字、网页链接，包括希望从废纸篓拖入。
- 用户不希望视频等使 Clipio 大量占用内存／闪存，已批准文件、文件夹和视频保存原位置引用，限制保存内容和预览缓存。引用依赖原件，清空废纸篓后可能不可用。
- 用户明确授权用临时文件短暂控制鼠标，诊断实际拖动。无需重复索取同一测试的许可；只操作测试内容。

## R3 做了什么

1. 星标点击：原生屏幕外测试复现相邻宽图片抢占点击；调整卡片交互裁切和星标 overlay 层级。修复后同一测试能收藏／取消收藏，且不触发卡片选择。收集区 Pin 按键也有原生点击验证。
2. 拖入：原生接收面保留原始 NSURL 与安全授权，跨异步导入持有。增加文字与网页链接的保存、预览、复制和拖出格式；支持 UTF-8／UTF-16／generic plain text。
3. 轻量：文件／文件夹／视频仍是引用；文字和链接通过旧 manifest 的 ownedFileName 保存独立小文件，使用内部 `.clipio-text`／`.clipio-link` 扩展名，普通外部文件保持文件语义。
4. 图片：ImageIO 降采样、缩略图缓存预算、离屏释放和关闭预览释放，避免旧 resized 绘制闭包持有原始大图。
5. 导出：临时传送预算与取消清理；失败时清理本次新建目录，保留已有成功传送。旧 promise 临时目录超过 24 小时清理。

实现者选定的候选默认值（用户批准的是轻量方向，并未逐项指定数字）：保存内容合计 128 MiB、文字 1 MiB、图片 64 MiB、链接 8 KiB、临时传送 128 MiB、缩略图 NSCache 预算 32 MiB。**不是整个进程的内存硬上限，也不是历史剪贴板数据库的总容量限制。**

## 仍有限制，不能写成完成

- **Finder 废纸篓 → Drop Zone 尚未实际拖动验证。** 两次 `cua.getState()` 都返回 `Sky Computer Use native pipe startup failed`／`The browser access host is unavailable`；没有鼠标操作。不要将系统回收 API 测试当成 Finder 拖入验证。
- 接收端选择 copy/link/generic；如果来源只提供 move，会拒绝，因为目前收集引用并没有实际搬动文件。Finder Trash 实际提供的操作码未知。
- 只有虚拟文件 promise、没有可直接读取的文件 URL／图片／文字／链接时，无法在生成副本前可靠限制大小，因此提示先保存到 Finder 再拖入。没有偷偷生成无上限副本。
- 所以“Drop anything”目前是五类内容的候选实现，**并非所有应用的所有拖动协议都已覆盖**。若真实 Trash 仍被拒绝，下一步先看来源操作码和类型，再讨论与引用方案兼容的实现；不要假报 move 成功。
- 旧只读书签需要从 Finder 重新拖入更新授权，保留原卡片、Pin、Stack。不要扩大成全磁盘权限；无永久删除回退。

## 验证证据

- 184 项隔离单元测试通过，零失败：`/tmp/clipio-r3-handoff-tests.log`。
- Star 原生点击回归：`/tmp/clipio-r3-hit-red.log` → `/tmp/clipio-r3-hit-green.log`。
- 完整测试命令（在实现工作区，独立测试 bundle，勿改成当前候选 ID）：

  ```sh
  xcodebuild -project Clipio.xcodeproj -scheme Clipio -configuration Debug \
    -derivedDataPath /tmp/clipio-r3-tests test -only-testing:ClipioTests \
    CLIPIO_APP_BUNDLE_IDENTIFIER=com.clipio.app.candidater3tests \
    CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES
  ```

- 项目规定的 unsigned Debug 编译通过：`/tmp/clipio-r3-required-build.log`；此次交接重新编译记录 `/tmp/clipio-r3-handoff-required-build.log`。
- 独立签名体验构建通过：`/tmp/clipio-r3-preview-build.log`。
- 实际构建产物检查过 31 个语言目录的新提示、候选 bundle/version、选入文件读写 entitlement、未变更的 `Collect.wav`；签名验证和 ZIP CRC 通过。
- 合成测试涵盖 2 GiB 稀疏视频只保留引用、独立临时文件的真实 Trash/恢复、容量拒绝和取消清理。没有枚举／清空用户废纸篓。
- 只读审查发现 UTF-16 加载与未知大小 promise 问题，已修正。一个旧鼠标释放测试因异步 postEvent 时序不稳定，改为同步发送旧事件后才开始新拖动。
- `/tmp` 日志可能被系统清理；若缺失，不能声称新一轮已经验证，按需重跑。

## 体验包

- 实现工作区内：`build/Clipio候选体验-R3-20261112.zip`，约 8.8 MiB。
- SHA-256：`cc9f20351e03aa0c99f8a0a2076e87434e200a8ae4ccfc96a0d598facef3ad6e`。
- 解压目录：`build/Review-Candidate-20261112-R3/`，内含 `Clipio-Candidate-R3.app` 和 `START-HERE.txt`。
- Bundle `com.clipio.app.candidate20261111`，build `6703`，沿用 R1/R2 候选数据。**先退出旧候选再开 R3，不能同时运行。**
- 本机 ad-hoc Debug 体验包，不是公证发布包。R3 未自动启动、未安装、未替换日用 `com.clipio.app`；没有为本轮创建或推送 PR。
- 前次实际观察运行的是 R2；此次交接没有重新检查运行进程。接手先核对实际运行路径／版本，不从包名猜测。

## 下一位接手的顺序

1. 核对实现分支和实际运行版本。继续在 `star-candidate` 工作区，不改根 checkout 的旧应用代码。
2. 如果用户有新的体验反馈，先按具体卡片／来源核对，保留原话，不让自动化结果覆盖体验失败。
3. 桌面连接恢复后，用一个独立临时文件做“Finder 普通目录 → Drop Zone → 废纸篓”和“Finder 废纸篓 → Drop Zone”，核对实际磁盘原件和卡片。只操作该临时文件；无需重新询问同一授权。
4. 若反向拖入失败，读取 `com.clipio.app` 子系统 `CollectionDrop` 分类的 sourceMask／accepted／types／count；日志不记录路径或内容。确认是来源拒绝、接收面未命中还是授权失败后再修。
5. 一批体验核对：同一卡片 star/unstar、切换全部／收藏和 Shift+Tab；文件、文件夹、图片、选中文字、网页链接各拖一次；Pin 原件保护；已有声音 A 与 check mark。
6. 用户体验通过后再准备正式打包／集成。当前请求仅为交接，不代表发布授权。

Brain 记录页：`notes/clipio-candidate-r3-2026-11-12`。本交接文件是根 checkout 的继续入口；详细实现证据位于上面的候选工作区。

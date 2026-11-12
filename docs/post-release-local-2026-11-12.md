# 2.8.0 发布后的本机日用与归档

2026-11-12 用户要求核对自己的日用版并清理/归档旧内容。用户明确选择“更新正式版，保留两份独立数据（先不合并）”。

- 已将公证的 Clipio 2.8.0（68）安装到 /Applications/Clipio.app；实际运行进程路径已核对，旧候选进程已退出。
- com.clipio.app 与 com.clipio.app.candidate20261111 的数据容器仍分别保留；没有复制、合并或删除用户数据，没有把候选数据覆盖到正式版。仅核对容器存在及元数据，不读取剪贴板内容。
- 上一版日用 App 已备份在 /Users/dubulu/AgentOS/Project/Clipio/build/Archive/2026-11-12-release-68/daily-app-before-update/Clipio.app 。
- 17 项旧候选/旧发布/旧构建目录与包共约 1433.6 MiB 已移动归档；这是位置整理，不是删除释放磁盘空间。
- 本地归档索引：/Users/dubulu/AgentOS/Project/Clipio/build/Archive/2026-11-12-release-68/INDEX.md ，对应 JSON 保留每个旧路径和新路径，全部验证存在。
- 全部本地命名分支和 tag 另存 source-branches.bundle 并通过 git bundle verify；源码工作区/分支、素材、设计文件、远端历史 releases 均保留。
- 当前发布资产继续保留在 .worktrees/star-candidate/build/Release-2.8.0-beta.1-68 。

历史候选 handoff 中 build/Review-Candidate 等旧包路径已迁移，按上述本地索引查找。候选源码检查点保留；归档不改写各次验收的证据边界。

这是手动替换正式 App 后的进程与签名核对，不是一次通过 Sparkle 的跨版本安装验收；没有检查窗口中实际显示的历史/收藏内容。

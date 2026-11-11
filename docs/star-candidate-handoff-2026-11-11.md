# Clipio 集中体验候选 · 2026-11-11

用户不在电脑旁，授权先做可回退候选。没有启动、安装、替换日用版或公开发布。

## 当前结果

- 工作区：`/Users/dubulu/AgentOS/Project/Clipio/.worktrees/star-candidate`，分支 `feature/clipboard-star`。
- Star 实现：`39292de`；带入废纸篓修复 `7ab86c5` 与收入反馈 `e50e78a`。包中应用代码来自 `e50e78a`。
- 体验包：`build/Clipio候选体验-20261111.zip`，约 9.2 MiB。内含 `Clipio-Candidate.app` 和 `START-HERE.txt`。
- SHA-256：`46fc249c85bc89c9a9736a8894128464837fba7d6b3d44c3f7a906c889537649`。
- 独立 bundle ID：`com.clipio.app.candidate20261111`；保留 App Sandbox，本机 ad-hoc Debug 签名完整性校验通过。没有复制日用数据库，初次运行会是独立空数据。

## 验证

- Star 单独 144 项单元通过；合并三项后的 155 项单元全部通过：`/tmp/clipio-combined-candidate-tests.log`。
- 合并后规定 unsigned Debug build 成功：`/tmp/clipio-combined-required-build.log`。
- 构建包 31/31 主语言资源含 Star、清空全部确认与收集成功标签；音频与选定 A 相同。没有重复资源键或未解决冲突。
- 合并时只对 31 份 Localizable.strings 的末尾追加冲突取并集，保留 Star 和 receipt 键，无新行为选择。
- ZIP CRC 和内含说明文件已检查；候选未启动。未使用 computer use 或鼠标 UI 自动化。

## 尚未验收

原生布局、改名/确认弹窗、输入法与焦点、不同设置组合、声音与动效时序，以及真实 Dock 废纸篓拖放。空数据库的单元测试和候选包不代表实际旧数据库升级通过；正式安装前需另行验证。

体验前先退出日用 Clipio，再直接打开包里的应用，不拖进 Applications。完成后退出候选并重新打开 `/Applications/Clipio.app`。先用可丢弃示例内容；测试数据与日用版分开。

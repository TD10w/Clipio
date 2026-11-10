# Clipio 跨会话交接 · 2026-11-10 晚（2.7.1 待发布）

接续目标：发布已打包好的 2.7.1（DMG + ZIP），再处理字体/样式统一与 README 改版。本文接在[上午交接](handoff-2026-11-10.md)之后；那份记录的四项 UI 待办（A 拖入小面板、B Liquid Glass、C Tab 晃动、D Stack）均已实现、合并并经用户体验认可。

## 接手先做

1. 读 [CLAUDE.md](../CLAUDE.md) → 本文。核对 `git log -1 master`、`gh release list`、`/Applications/Clipio.app` 版本，不要用本文代替现场检查。
2. **用户明确说「先不合并」：2.7.1 尚未公开发布，等用户点头再发。** 注意：Messages 修复（PR #9）在用户说这句话之前已合并进 master；「不合并」指的是暂不发布，不需要回滚。
3. 不要重做已通过的文件安全行为（见上午交接「不要破坏的文件边界」）。

## 当前状态（交接时实时核对）

- **master**：`2592324`（PR #9 合并）。本交接文档在分支 `docs/handoff-2026-11-10-release`，未合并。
- **GitHub Release**：只有 `v2.7.0-beta.1`（ZIP，代码 `833b1ae`）已公开，预发布。它**不含**模糊透明度滑条、设置预览和 Messages 修复。
- **README**：已按 2.7.0 更新（PR #6、#7），下载链接仍指向 2.7.0 ZIP；文字已描述新滑条（「向右更模糊」），与已发布的 2.7.0 包略有出入，发布 2.7.1 后即一致。
- **本机安装**：`/Applications/Clipio.app` = 2.7.1 (62)，从 DMG 装入，Developer ID 签名 + 公证，运行中。用户已确认 Messages 图片能拖入收集区。权限（辅助功能自动粘贴）与历史保留，用户尚未回复。
- **备份**：2.7.0 本机版在 `/tmp/clipio-backup-2.7.0.CYLvNA`；2.6.1 在 `/var/folders/_k/…/T/clipio-backup.0JAUf5/Clipio.app`。均在临时目录，可能被系统清理。

## 已打好、未发布的 2.7.1

代码 = master `2592324`，版本 2.7.1 (62)。

| 文件（`build/Beta/`，不入库） | SHA-256 |
|---|---|
| `Clipio-2.7.1-beta.1.dmg` | `1ad83a5c39d962b21973e744588e1754e2579cd05cd27745a1a84734fa369a87` |
| `Clipio-2.7.1-beta.1.zip` | `ce0198e4a0b8d84df309f8847c1fc6ae42aee8e214219ef79bce0e8f89cd8d96` |

两者均 Apple 公证 Accepted、已 staple、Gatekeeper `source=Notarized Developer ID`；DMG 已用「挂载 → 拖入应用程序」流程实装并启动。

发布步骤（用户同意后）：
1. 生成两个 `.sha256`（`shasum -a 256 文件 > 文件.sha256`）。
2. `git tag v2.7.1-beta.1 2592324 && git push origin v2.7.1-beta.1`，再 `gh release create v2.7.1-beta.1 --verify-tag --prerelease`，附 DMG、ZIP 及 sha256。说明沿用 2.7.0 的中英双语格式，安装步骤改为「打开 DMG，把 Clipio 拖到 Applications」，新增：透明度滑条通透→模糊 + 设置实时预览、Messages 等 App 的图片拖入。`--target` 必须用完整 SHA 或先推 tag，短 SHA 会 422。
3. README 中英两份下载按钮改为 DMG 链接。
4. 下载回来校验 sha256。

## 发布与签名要点

- 公证凭据：钥匙串 profile 名 **`Clipio`**（用户今天新建）。Developer ID：`Developer ID Application: Xin Du (TNC5DX363F)`。
- 公开包：`CLIPIO_DEVELOPER_ID=… CLIPIO_NOTARY_PROFILE=Clipio zsh scripts/release-beta.sh --output build/Beta/<名>.zip`，再 `zsh scripts/make-dmg.sh <zip> <名>.dmg`（PR #8 新增，DMG 自身也签名+公证+staple）。输出已存在会拒绝覆盖。
- 本机安装：`zsh scripts/release-local.sh`。它是 ad-hoc 签名，**必须关闭 Hardened Runtime**，否则 Sparkle 框架被拒、启动即崩（PR #5 修复，脚本现在会确认 App 仍在运行）。
- 用户日常用的是 /Applications 版本，替换前会退出它；同时运行测试版与日常版会抢 ⌘⇧V/⌘⇧C。

## 今天完成的事（均已合并）

| PR | 内容 |
|---|---|
| #4 | 2.7.0：文件收集区、Stack、拖入小胶囊、Tab 不晃、恢复 2.6.1 玻璃观感（PR #3 一并标记合并） |
| #5 | 本机发布脚本：关闭 Hardened Runtime、启动校验 |
| #6 | README 2.7.0 |
| #7 | 透明度滑条改为「通透 → 模糊」（行为后方模糊 + 色层，深浅模式同规则，默认中间）；设置 → 外观加实时预览（彩色圆斑 + 迷你面板，用户认可的简化版） |
| #8 | 2.7.1 版本号；`make-dmg.sh` |
| #9 | Messages 图片拖入：指向他人 App 私有存储（真实 `~/Library/…`）或不可读的 URL，改存图片副本；普通文件仍为引用 |

验证：Debug 构建成功；单元测试 129/129；4 个 `testCollection…` UI 测试在 PR #4 时 4/4（之后未重跑 UI 测试）。

### 用户确认的交互规则（供后续保持）

- **拖入小胶囊**：一开始拖文件就出现（Finder 内整理文件也会出现，用户已知）；停留 0.6 秒展开完整收集区；拖出面板外折回胶囊；松手后只有真正收进东西才保持面板打开；取消不残留。
- **透明度**：左通透（后面的字清楚）、右模糊（后面的字看不清），浅深模式一致，默认中间。用户不要五种样式的选择。
- **Stack**：点击展开/收起；收起整组操作，展开单个操作；搜索命中显示整组；剩 1 个变普通卡片；分组重启保留，展开状态不保留。

## 待用户决定 / 待办

1. **发布 2.7.1**：等用户同意。
2. **字体与样式统一**（已向用户列出，未决定）：
   - 原版 2.6.1 的「Clipio」字标、数字角标、⌥P 标签是 SF Rounded，现在是标准字体。上午交接记录用户曾确认「全用系统标准字体」，若要改回需用户再确认。
   - 字号比原版大（正文 11.5→13，时间 10→11.5）；颜色卡底条原版黑底白字，现为磨砂。
   - 收集区卡片的 Pin（蓝色 + 磨砂圆）与剪贴板卡片的金色 Pin 不一致；收集区选中框较细无光晕。
3. **README 改版**：已向用户提出结构（开头一句话 + 下载 + 主图 → 三个亮点 → 3 步安装 → 快捷键 → 精简隐私 → 限制/反馈 → 源码/致谢）。**等用户提供两张截图**：剪贴板面板、带 Stack 的收集区。agent 无屏幕录制权限，无法自行截图。
4. 仍未验证：跨磁盘移动、系统重启、另一台 Mac、多显示器拖动（展开后不跟随屏幕是已知项）。

## 不要做

- 不要在未经用户同意时发布 Release、更新公开下载或删除旧 Release。
- 不要重开「五种玻璃样式」或「整窗透明度」方案；用户已选定滑条。
- 不要把 `~/Library/Application Support/Maccy/Storage.sqlite` 改名。

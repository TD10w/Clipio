# Clipio 2.8.0 beta.1（68）发布准备与验收

用户 2026-11-12 确认 R3 Unstar 修复可用，要求把自动更新一起整合、统一打包；上传前确认具体版本、更新内容和验收结果。用户随后明确授权“直接打包上传吧，没问题了目前”；本轮按此授权发布 beta，但不把该授权当成尚未执行的自动升级测试证据。

## 代码保护与集成

- 原已验收源码 b02d80e 仍在 feature/clipboard-star；保护分支 backup/r3-accepted-20261112。
- 发布分支 release/2.8.0-r3-updates 位于 .worktrees/star-candidate。
- 自动更新原提交 0f5e458 已 cherry-pick 为 6dd6e69。工程文件两处登记冲突保留双方：Collect.wav 与 UpdateConfiguration.swift。
- 统一版本 2.8.0，build 68，拟公开 tag v2.8.0-beta.1。候选 build 6704 属于另一 Bundle ID，不占用正式版本序列；最近正式发布为 2.7.5（67）。
- 本轮发现并修复发布脚本直接用未展开 entitlement 模板重签名的问题；最终 Sparkle mach 服务名应为 com.clipio.app-spks / com.clipio.app-spki。

## 更新内容

Star 长期保留剪贴板文字、链接和图片，星标筛选及 Shift+Tab；修正点击目标和取消 Star 后滚动跳回。Drop Zone 支持文件/文件夹引用、图片、文字与网页链接；有保存容量与缩略图预算。保留收集区 Pin 保护、音效 A 与 checkmark。

应用内更新位于设置→通用，支持自动检查与主动检查；用户确认后安装，禁止静默安装，不发送系统概况。旧用户须手动安装这次引导版本，后续才可应用内更新。

## 生产渠道与密钥

- Feed: https://github.com/TD10w/Clipio/releases/download/clipio-updates/appcast.xml
- 专用 prerelease tag: clipio-updates；不设 Latest。
- 不可变版本资产 Clipio-68.zip，先版本包后 appcast.xml；禁止覆盖同构建号 ZIP。
- 生产 Ed25519 密钥已由 Sparkle generate_keys 生成，保存在本机钥匙串 account com.clipio.app.updates；没有导出私钥。
- 公钥 HamNrQtbtsXyKjE/688dCuJXuRWtdSeoKNdAovE4Qzc=，已核对最终签名包内嵌值。
- 钥匙串之外的灾备副本尚未制作；不要轮换此密钥而使旧包失去更新信任。
- 本机公证配置已恢复并验证：`Clipio-Notary-Production`。Apple 专用密码只经安全卡输入并存入钥匙串，未写入源码或发布资产。此配置名与 Apple 账号页的密码备注名不同。

## 已验证

- 整合后 186 项 ClipioTests，零失败：/tmp/clipio-release-integrated-tests.log。
- 项目规定 unsigned Debug 编译：/tmp/clipio-release-integrated-build.log。
- 更新配置门禁、7 项 Python 发布测试、真实 Ed25519 正确/错误公钥/篡改 ZIP 校验、beta 发布和 DMG 脚本检查。
- 真正调用 Sparkle generate_appcast 的合成流程通过，含生成失败清理：/tmp/clipio-280-synthetic-update.log。仅该临时副本绕过 Developer ID/公证检查，未实际升级应用。
- Release 通用构建、Developer ID 严格签名；最终实际 bundle 2.8.0（68）、31 个语言、arm64 + x86_64、feed、公钥、更新策略和展开后的两个 Sparkle 服务权限均核对。/tmp/clipio-280-release-build.log、/tmp/clipio-280-sign.log。
- 旧版 cb008d8 的持久化模型属性生成独立磁盘 fixture，由当前模型属性打开迁移；历史文字、Pin、复制次数保留，新增收藏名称保存后由第二个进程重新打开保留。工具与数据库仅在 /tmp/clipio-persistent-upgrade-68。这是模型数据兼容验证，不是实际 App 或 Sparkle 安装升级。
- 现有 CollectionTests 已覆盖文件引用/Pin/manifest 重启保留；正式 Bundle ID、Storage.swift 数据路径未变。旧设置键没有迁移或清空逻辑。

## 最终发布资产（已公证）

目录：`.worktrees/star-candidate/build/Release-2.8.0-beta.1-68/`。

- `Clipio-2.8.0-beta.1.zip`：Developer ID 签名、Apple 公证并装订、Gatekeeper accepted。
- `Clipio-2.8.0-beta.1.dmg`：包内 App 与 DMG 自身均公证并装订、Gatekeeper accepted；只读挂载后核对可执行文件、Info.plist、音效与源 App 字节一致。
- `update-assets/Clipio-68.zip` 与 `update-assets/appcast.xml`：生产 Ed25519 签名，包内公钥独立校验通过；ZIP 与手动安装 ZIP SHA256 相同。
- 每个 ZIP/DMG 旁有 `.sha256` 校验文件。旧 `PENDING-NOTARIZATION` ZIP 是首次 Apple 提交证据，不用于分发。
- App 公证 Accepted：`97a18208-20d6-42c7-8b01-04213aa175bf`；DMG 公证 Accepted：`9c760ea3-5609-4b62-a7c4-60d1a3a11585`。
- App 公证输入 SHA、submission/result JSON 保留在本地资产目录；校验日志 `/tmp/clipio-280-distribution-validation.log`、`/tmp/clipio-280-production-update-assets.log`、`/tmp/clipio-280-dmg.log`、`/tmp/clipio-280-mounted-validation.log`。
- ZIP SHA256：`bff611d5fd6ad0adedd4c8e9e6f6dae0dd7cc0c0e39e79213d8fa70f9d3d672e`。
- 本轮再次尝试桌面连接，仍返回 `Sky Computer Use native pipe startup failed`；没有实际操作更新窗口，没有安装/替换日用版。

## 尚未通过的验收与限制

- Apple App 和 DMG 公证已完成；仅下列真实升级与公开渠道验收仍未完成。
- 专用公开 feed/ZIP 已上传；公开下载、版本/长度/URL 与实际 ZIP 的生产 Ed25519 签名校验已通过。
- 未完成真实 App 内旧→新下载/安装/重启；因此历史、Star、设置、权限、快捷键在真实升级后的保留不能标为通过。
- 未完成真实界面的“无新版/发现新版/稍后/主动检查/关闭自动检查”和断网/中断下载验收；当前桌面工具连接失败。
- 通用二进制已核对，两种 CPU 的真实设备运行尚未分别验收。
- Finder 废纸篓反向拖入及 move-only 来源限制仍以 R3 handoff 为准，不把它宣传为任意来源都可拖入。
- 本轮没有安装或替换正式应用；已获用户明确授权上传发布资产。

## 发布次序

先补齐 Apple 公证和本地资产，交用户确认版本/说明/证据。获得上传授权后，创建或检查专用 prerelease，上传不可变 ZIP，验证下载和签名，最后上传 feed。进行正式渠道升级验收后再宣布后续自动更新可用；这一步需要用户授权发布测试渠道或独立隔离测试环境，不能在禁止上传的状态下假报公开渠道已通过。


## 2026-11-12 上传授权及公开渠道验证

用户明确要求直接打包上传。发布源码位于远程分支 release/2.8.0-r3-updates，发布资产对应源码检查点 781dcfe（运行时代码 17ccf07）。

- 专用渠道：https://github.com/TD10w/Clipio/releases/tag/clipio-updates ，prerelease，不设 Latest。
- 常规 beta 下载：https://github.com/TD10w/Clipio/releases/tag/v2.8.0-beta.1 。
- 先上传不可变 Clipio-68.zip，匿名公开下载校验 SHA256 后才上传 appcast.xml。
- 随后匿名下载正式 appcast.xml，核对版本 68、长度 10167607、固定下载地址，并对实际公开 ZIP 独立校验 Ed25519 签名通过。
- 这些检查覆盖公开交付链，不等同于真实 App 内安装重启验收；未测项目继续保留，不因用户批准发布而改写为已测通过。

- 常规 beta 已发布为非草稿 prerelease，四项资产（DMG、ZIP、各自 SHA256）均上传完成；ZIP 已匿名下载核验，DMG 的 GitHub 服务端 SHA256 与本地 `79262d7f24e8f77ff89234307e1d0edbdc4ae6f9073dd5684a6c8598c4dbf4fc` 相符。
- 两个公开 tag 均指向 `781dcfec473c5a0655fdaf9364c321dcb2602144`。专用更新渠道不是 Latest。

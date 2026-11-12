# Clipio 2.8.0 beta.1（68）发布准备与验收

用户 2026-11-12 确认 R3 Unstar 修复可用，要求把自动更新一起整合、统一打包；上传前确认具体版本、更新内容和验收结果。本记录不是发布授权。

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

## 已验证

- 整合后 186 项 ClipioTests，零失败：/tmp/clipio-release-integrated-tests.log。
- 项目规定 unsigned Debug 编译：/tmp/clipio-release-integrated-build.log。
- 更新配置门禁、7 项 Python 发布测试、真实 Ed25519 正确/错误公钥/篡改 ZIP 校验、beta 发布和 DMG 脚本检查。
- 真正调用 Sparkle generate_appcast 的合成流程通过，含生成失败清理：/tmp/clipio-280-synthetic-update.log。仅该临时副本绕过 Developer ID/公证检查，未实际升级应用。
- Release 通用构建、Developer ID 严格签名；最终实际 bundle 2.8.0（68）、31 个语言、arm64 + x86_64、feed、公钥、更新策略和展开后的两个 Sparkle 服务权限均核对。/tmp/clipio-280-release-build.log、/tmp/clipio-280-sign.log。
- 旧版 cb008d8 的持久化模型属性生成独立磁盘 fixture，由当前模型属性打开迁移；历史文字、Pin、复制次数保留，新增收藏名称保存后由第二个进程重新打开保留。工具与数据库仅在 /tmp/clipio-persistent-upgrade-68。这是模型数据兼容验证，不是实际 App 或 Sparkle 安装升级。
- 现有 CollectionTests 已覆盖文件引用/Pin/manifest 重启保留；正式 Bundle ID、Storage.swift 数据路径未变。旧设置键没有迁移或清空逻辑。

## 尚未通过的验收与限制

- Apple 公证凭据待恢复；当前只有 Developer ID 签名构建，不能标为可分发公证包。
- 本轮未上传 GitHub，专用公开 feed/ZIP 尚未验证可用。
- 未完成真实 App 内旧→新下载/安装/重启；因此历史、Star、设置、权限、快捷键在真实升级后的保留不能标为通过。
- 未完成真实界面的“无新版/发现新版/稍后/主动检查/关闭自动检查”和断网/中断下载验收；当前桌面工具连接失败。
- 通用二进制已核对，两种 CPU 的真实设备运行尚未分别验收。
- Finder 废纸篓反向拖入及 move-only 来源限制仍以 R3 handoff 为准，不把它宣传为任意来源都可拖入。
- 本轮没有安装或替换正式应用，没有上传发布资产。

## 发布次序

先补齐 Apple 公证和本地资产，交用户确认版本/说明/证据。获得上传授权后，创建或检查专用 prerelease，上传不可变 ZIP，验证下载和签名，最后上传 feed。进行正式渠道升级验收后再宣布后续自动更新可用；这一步需要用户授权发布测试渠道或独立隔离测试环境，不能在禁止上传的状态下假报公开渠道已通过。

# Clipio 应用内更新

## 用户体验和当前边界

正式分发包可自动检查新版；用户在 Sparkle 标准提示中查看更新说明，选择安装或稍后处理。
设置 → 通用提供“自动检查更新”和“立即检查”。禁止静默自动安装；不发送系统概况。
开发包、测试包和未配置更新地址/公钥的正式包不启动更新，也不显示这两个控件。

代码和发布准备流程已实现。2026-11-12 已整合 R3，固定地址与生产签名密钥已配置；公开渠道尚未上传，实际升级验收仍待完成。具体状态见 `docs/release-2.8.0-beta.1-acceptance.md`。
此前已分发的版本没有更新入口，需要用户手动安装一次新的引导版本。
本次没有修改 App 身份、数据目录、剪贴板数据库或收藏存储。

## 固定渠道（已选定，尚未公开上传）

沿用现有的公开仓库 `TD10w/Clipio`，建议使用一个专用的 GitHub prerelease：

- 固定 tag：`clipio-updates`，不作为 GitHub 的 Latest release。
- 固定 feed：`https://github.com/TD10w/Clipio/releases/download/clipio-updates/appcast.xml`。
- 版本包使用不可变名字 `Clipio-<CFBundleVersion>.zip`，放在同一个 release。
- 先上传版本包，确认公开下载完整后，最后替换 `appcast.xml`。
- 保留已发布版本包，不覆盖相同构建号的 ZIP；回退时重新打一个更高构建号。
- 不使用 `/latest/download/`，避免其他工作区发布普通 beta 时影响固定渠道。
- 此路径是待发布方案，不表示该地址现在已存在或已验收。

## 一次性生产准备

在准备发布的 Mac 上，使用当前 Xcode 依赖中的 Sparkle 工具目录（`<sparkle-bin>`）：

```sh
<sparkle-bin>/generate_keys --account com.clipio.app.updates
```

私钥保存在本机钥匙串，公钥用于打包。2026-11-12 已使用 account `com.clipio.app.updates` 生成生产密钥并核对包内公钥；私钥未导出。此前合成测试只使用临时密钥。
不要把私钥加入仓库、安装包、日志或 release。发布机器须一直保留同一密钥，并安排安全备份。

本机已验证可用的 notarytool 配置名是 `Clipio-Notary-Production`（2026-11-12）；它与 Apple 账号页中专用密码的备注名不同。后续直接使用这个配置，不再通过密码备注猜测。生产公钥为 `HamNrQtbtsXyKjE/688dCuJXuRWtdSeoKNdAovE4Qzc=`。

```sh
export CLIPIO_UPDATE_FEED_URL='https://github.com/TD10w/Clipio/releases/download/clipio-updates/appcast.xml'
export CLIPIO_UPDATE_PUBLIC_KEY="$(<sparkle-bin>/generate_keys --account com.clipio.app.updates -p)"
```

这两个值是公开配置。公钥和更新地址会在 `xcodebuild` 之后、最终 Developer ID 签名之前写入构建产物；不会改源码 Info.plist。
没有配置时会清除上次增量构建留下的这两个值。只提供一个值或格式错误时，打包会在构建/公证前终止。

## 每次发版

1. 同其他工作区确认发布基线，合并已验收改动，并为正式包设置递增的 `CURRENT_PROJECT_VERSION`。
   不复用已经发布过的构建号；本分支刻意没有占用下一个正式版本号。
2. 准备一份非空 UTF-8 更新说明，和已有 Developer ID / notarytool 配置。
3. 在独立输出目录打包；替换以下参数中的示例值：

```sh
export CLIPIO_DEVELOPER_ID='Developer ID Application: <existing identity>'
export CLIPIO_NOTARY_PROFILE='<existing keychain profile>'
zsh scripts/release-beta.sh \
  --derived-data /tmp/clipio-update-release-build \
  --output /tmp/clipio-release-68/Clipio-beta.zip \
  --updates-output /tmp/clipio-release-68/update-assets \
  --update-notes /path/to/release-notes.txt
```

脚本构建通用架构，注入配置，签名，提交 Apple 公证并装订，然后准备两个更新资产：
`Clipio-<build>.zip`、`appcast.xml`。这两个文件都在 `--updates-output` 目录。
更新 ZIP 从实际通过签名、公证和 Gatekeeper 检查的 App 生成，使用专属钥匙串密钥签名，
再以 App 内嵌公钥做独立 Ed25519 校验；同时核对 feed 的版本号、下载地址和 ZIP 长度。
生成失败则清除临时目录；已有输出目录会被拒绝。脚本不执行任何 GitHub 上传。

也可对已经配置、签名、公证的 App 单独生成资产：

```sh
python3 scripts/update-release.py prepare \
  --app /path/to/Clipio.app \
  --output /tmp/clipio-update-assets-68 \
  --sparkle-bin /path/to/SourcePackages/artifacts/sparkle/Sparkle/bin \
  --notes /path/to/release-notes.txt
```

首次发布时，先准备并检查专用 release，再上传版本包，最后上传 feed。
确认真实渠道验收通过后，再让旧用户手动安装引导版本。

## 验证

```sh
zsh tests/beta-surface-tests.sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p test_update_release.py
zsh tests/update-signature-tests.sh
python3 tests/synthetic-update-tests.py /path/to/built/Clipio.app /path/to/sparkle/bin
```

合成流程使用临时签名密钥和临时 App 副本，真正调用 Sparkle 生成 feed，验证真实 Ed25519 签名和失败清理；
只绕过该临时副本的 Developer ID/公证检查，并给副本重做 ad-hoc 签名。它不代表真实分发验收。

正式渠道必须另外完成一次真实的旧→新升级：

- 两个不同且递增构建号的 Developer ID 签名、公证正式包；旧包已内置同一地址和公钥。
- 在独立测试用户/测试 Mac 中核对“无新版”“发现新版”“稍后”“主动检查”和关闭自动检查。
- 核对更新说明、安装并重启、剪贴板历史、Star/收藏、设置、已有权限和快捷键。
- 断网/下载中断保留旧 App 可用；坏签名拒绝安装。
- 核对公开 feed/ZIP 可访问、macOS 版本要求、两种 CPU 架构。

参考：[Sparkle 设置](https://sparkle-project.org/documentation/)、[程序化初始化](https://sparkle-project.org/documentation/programmatic-setup/)、[更新行为选项](https://sparkle-project.org/documentation/customization/)。

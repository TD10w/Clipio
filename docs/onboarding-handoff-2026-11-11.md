# Clipio 三步上手指南

## 最新发布

2.7.3-beta.1（build 65）已发布，包含三页英文指南和系统管理的收集区菜单栏入口。PR #11/#12 均已合并，最终 ZIP/DMG 已签名、公证、staple 并通过公开下载对照。详见[发布证据](release-evidence-2.7.3-beta.1.md)。未替换日用应用；下方独立体验包与 build 64 的描述是发布前记录。

## 发布前追加：收集区入口遮挡

用户提供截图并批准先修复常驻收集入口。原实现把 NSPanel 手动放在菜单栏里，没有系统保留位置。已改为 NSStatusItem；只有拖文件时才显示菜单栏下方的接收面板，保留点击打开、拖入、弹开、Pin 与导出逻辑。

2.7.3 的最终候选使用 build 65；之前 build 64 的 ZIP/DMG 虽已公证，但没有发布，不可上传旧包。回归先在旧实现复现非空收集区产生可见浮层，再验证新实现没有闲置浮层、原生状态按钮可切到 Collection、拖动接收区在有/无刘海及偏移副屏上均低于菜单栏。单元测试增至 134 项；最终发布证据以 2.7.3 release 记录为准。

## 首次指南交付（发布前记录）

分支 `feature/onboarding-guide`。三页内容与英文措辞经过用户逐次确认：Find Clipio here / Clipboard / Collection。没有使用宣传式标题。

本地独立体验包：`build/onboarding-preview/Clipio.app`，bundle ID `com.clipio.app.onboardingpreview`。Debug、ad-hoc 签名，构建和 `codesign --verify --deep --strict` 通过；不是公证发布包。未自动启动。体验时先退出日用版，避免两份应用争用默认快捷键；无需拖进 Applications，体验数据使用独立容器。

- 首次启动完成准备后自动显示；已有用户更新后也只显示一次。
- 可前进、后退、跳过或关闭；后三种退出方式都会记录已看过。
- Get Started 关闭指南并打开 Clipboard。
- 齿轮菜单 → Getting Started，以及 Settings → General → Getting Started，均可重新从第一页查看。
- 快捷键读取当前配置；未配置时显示说明。截图使用隔离测试的四修饰键 J/K，不是产品默认值；产品默认仍是 ⌘⇧V / ⌘⇧C。
- 菜单栏图示跟随所选图标，包含剪刀文字图标的特殊处理。菜单图标被隐藏时，第一页提供 Show Menu Bar Icon 按钮。
- 所有图示是合成内容；没有读取个人剪贴板或文件作为图片素材。英文文案加入全部 31 个语言表。

## 实际窗口截图

来自本地构建运行的指南窗口，非 HTML 示意稿。默认图标与浅色三页、深色与未设置快捷键示例：

- [菜单栏入口](screenshots/onboarding-2026-11-11/01-entry.png)
- [剪贴板](screenshots/onboarding-2026-11-11/02-clipboard.png)
- [收集区](screenshots/onboarding-2026-11-11/03-collection.png)
- [深色入口](screenshots/onboarding-2026-11-11/04-entry-dark.png)
- [未设置快捷键](screenshots/onboarding-2026-11-11/05-unset-dark.png)
- [深色收集区](screenshots/onboarding-2026-11-11/06-collection-dark.png)

## 验证证据与边界

- 必需的 unsigned Debug 构建通过，日志 `/tmp/clipio-onboarding-required-build.log`。
- 全部 131 项单元测试通过，日志 `/tmp/clipio-onboarding-final-tests.log`。首轮 `ClipboardTests.testIgnoreAllApplicationsExcept` 有一次 2 秒超时；后续全组同项通过，没有改动剪贴板实现，也没有认定其间歇性已修复。
- 首次展示回归曾在无指南的基线上失败，证明可捕获功能缺失，日志 `/tmp/clipio-onboarding-red.log`。
- 界面回归覆盖翻页、返回、完成后打开剪贴板、跳过/关闭后重启不再出现、菜单和设置重新打开、实际自定义快捷键、未设置快捷键、Tab/Return/Escape，以及原有搜索/重开/双快捷键/Tab 位置。
- 最后整组 10 项 UI 中 7 项通过、3 项失败，日志 `/tmp/clipio-onboarding-verified-ui.log`。失败项为 `testTabKeepsHeaderAndWindowPositionStable`、`testSkipDoesNotAutomaticallyReappear`、`testWindowCloseDoesNotAutomaticallyReappear`；该轮日志明确出现其他应用弹窗与失焦干扰，不关闭或操作其他应用的弹窗。这三项随后在同代码单独一组 3/3 通过，日志 `/tmp/clipio-onboarding-interrupted-recheck.log`。因此相关 10 项分批通过，不宣称整组十项一遍全绿，也不宣称自动化焦点稳定性已修复。
- 首轮界面断言把 macOS StaticText 的 value 当作 label、把 MenuButton 当作 Button，已根据实际辅助功能树修正测试查询；未为此更改产品逻辑。
- 隐藏菜单图标恢复的自动化曾尝试用启动参数锁定布尔值，导致用户设置写入后仍被参数覆盖，不能代表普通用户的恢复行为。后续跨设置页的尝试没有可靠触发按钮动作，未确认是测试焦点/切页时序还是其他原因；不作为该场景通过的证据。最终单独验证设置首页重新打开指南；隐藏图标恢复仍待人工体验。
- 只读独立代码复核没有发现 Critical/Important 阻塞；补齐了进度朗读的资源键，并让截图显式指定 light/dark 外观。
- 已在实际 Debug 包的 Resources 中确认全部 31 份 Localizable.strings 包含指南文案；不只检查源码文件。

使用独立测试 bundle ID `com.clipio.app.onboardingtests`、内存历史库、命名剪贴板和临时 Collection 目录完成自动化。日用应用没有被替换，未合并、推送或公开发布。新用户是否无需解释就能找到入口，仍需要女朋友的实际使用反馈。

## 代码入口

- `Clipio/OnboardingController.swift`：窗口、启动一次与关闭记忆。
- `Clipio/Views/OnboardingView.swift`：三页、文案、快捷键与操作。
- `Clipio/Views/OnboardingIllustration.swift`：菜单栏和卡片合成示意。
- `Clipio/AppDelegate.swift`：启动与重新查看接入。
- `Clipio/Views/HeaderView.swift`、`Clipio/Settings/GeneralSettingsPane.swift`：两个查看入口。
- `ClipioUITests/OnboardingUITests.swift`：真实窗口回归。

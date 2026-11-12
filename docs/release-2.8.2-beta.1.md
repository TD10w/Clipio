# Clipio 2.8.2-beta.1

Fixes the update installer's cache-directory failure for Clipio's existing `com.clipio.app` bundle identifier by adopting the official Sparkle 2.9.3 fix. The app identity, clipboard history, collection and Star storage paths remain unchanged.

Users on 2.8.0 or 2.8.1 whose updater fails before installation should manually install this signed release once. The failing older updater cannot repair itself by downloading a newer app. Future in-app upgrades use the repaired component.

This includes the 2.8.1 attachment fixes: unpinned collection files can be dragged into attachment composers; accepted unpinned drops remove their cards while preserving referenced original files. Pinned, rejected and cancelled entries remain.

## 中文说明

修复更新安装器创建缓存目录失败的问题，采用 Sparkle 官方 2.9.3 修复。Clipio 的身份、历史记录、收集区和收藏数据路径保持不变。

如果 2.8.0 或 2.8.1 在安装更新前报错，请先手动安装本版一次。旧更新器在安装前就会失败，无法通过下载新包自行修复；后续版本使用修好的更新组件。

包含 2.8.1 的附件拖出修复：文件无需 Pin 即可拖入附件框；成功接收后自动移出未 Pin 卡片，磁盘原件保留。Pin、失败和取消的条目继续保留。

Requires macOS 14 or later. Universal Apple silicon and Intel build. Update installation requires the user's approval.

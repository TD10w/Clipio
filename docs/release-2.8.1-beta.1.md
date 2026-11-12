# Clipio 2.8.1-beta.1

## Fixes

- Files in the collection can now be dragged into chat attachment composers without pinning them first.
- After a destination accepts a drop, unpinned entries leave the collection. Referenced original files remain on disk when copied as attachments.
- Pinned entries remain available for reuse. Cancelled and rejected drops keep their entries.

Collection cleanup happens when the destination accepts the drop. Clipio cannot observe whether a chat message is subsequently sent or whether an asynchronous upload completes.

## 修复

- 收集区文件无需 Pin，即可拖入聊天附件框。
- 对方成功接收拖入后，未 Pin 的卡片自动移出收集区；作为附件复制时，磁盘原文件保留。
- Pin 的卡片继续保留，拖入失败或取消也会保留卡片。

卡片清理以目标接受拖入为准。Clipio 无法判断聊天消息是否最终发送，或后续上传是否成功。

Existing 2.8.0 users can choose Check Now in Settings → General to test the signed in-app update. Earlier versions without the update entry require a manual installation first. This release does not claim to resolve the separately reported menu-bar visibility or shortcut-recording issues.

Requires macOS 14 or later. Universal build for Apple silicon and Intel.

# WeChat video drop compatibility candidate

The owner supplied screenshots showing a WeChat video rejected by Clipio with “File unavailable” while another Dropzone collected the same MP4. Native drop logs show WeChat offered `public.file-url`, `NSFilenamesPboardType` and promised-file types, and Clipio accepted one direct file URL. No unrelated WeChat directories or message contents were scanned.

The direct-file importer treated every app-private URL as image-only. It rejected videos without image bytes and could incorrectly save a video's supplied thumbnail as a PNG. Regression fixtures reproduced both failures before the fix, using synthetic files under a temporary WeChat-like private directory.

The candidate copies app-private movies while their drag read grant is retained. Copying runs off the main actor in 64 KiB chunks, follows the existing 64 MiB owned-item limit and 128 MiB default total owned-storage limit, and never moves the source. The store owns the copy; drag-out staging remains readable after the unpinned card is consumed. Images retain their existing byte/pixel validation. Unknown-size file promises remain outside this correction; if the real WeChat URL cannot be read with its drag grant, that case still requires investigation.

All 192 unit tests passed after the correction, including private MP4 import without image data, preserving video bytes over a thumbnail, size rejection without silently importing the thumbnail, original-file retention, outgoing-copy lifetime and the preceding interaction suite. Logs: `/tmp/clipio-wechat-video-red.log`, `/tmp/clipio-wechat-video-limit-red.log`, `/tmp/clipio-wechat-video-final-tests.log`.

Real WeChat compatibility remains pending: drop the same video into the candidate, drag its collected card to Finder and confirm it opens as the full video. Synthetic bytes prove file preservation, not actual MP4 playback or WeChat sandbox grant behavior. No public release for this candidate has been made.

Candidate runtime checkpoint `b43c281` was Developer ID signed, notarized (`bac03155-9d70-4ab9-ae5b-f003ae743537`), stapled and Gatekeeper-validated. ZIP: ignored `build/WeChatVideoCandidate-70/Clipio-candidate.zip`. It retains the production update feed/key and Sparkle 2.9.3; its displayed version remains 2.8.2 (70), but it is a local candidate, not a replacement of the immutable public build 70 asset.

It was installed at `/Applications/Clipio.app` and restarted (PID 66993 at verification), with executable SHA256 `9e10c4b3bdf841f92d3fbb4abaa5c2855f082f1edc0eeafd44fd3b9ab92c52e9`. The official 2.8.2 reached through the successful in-app update is backed up at `build/Backups/before-wechat-video-20261112-125424/Clipio.app`. Required Debug build and candidate distribution logs: `/tmp/clipio-wechat-video-final-debug.log`, `/tmp/clipio-wechat-video-candidate.log`.

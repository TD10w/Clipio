# R3 取消 Star 后保持滚动位置

用户反馈：star 之后 unstar 会滚回卡片原来的历史位置，希望停在当前浏览位置。

原因：History.togglePin 在取消 Star 后主动设置 scrollTarget；收藏列表刷新隐藏选中项时也使用了会滚动的选择方法。

修复：Star 状态变化只更新顺序和选择，不主动滚动；搜索、筛选和键盘导航仍使用原有滚动行为。

验证：两个回归测试先失败（/tmp/clipio-unstar-red.log），修复后完整 186 项 ClipioTests 通过（/tmp/clipio-unstar-green.log）。项目规定 unsigned Debug build 通过（/tmp/clipio-unstar-required-build.log）；候选签名构建通过（/tmp/clipio-unstar-candidate-build.log）。

体验包：build/Review-Candidate-20261112-R3-Unstar/Clipio-Candidate-R3-Unstar.app，build 6704，沿用 com.clipio.app.candidate20261111 候选数据。退出旧候选再打开，不同时运行。没有替换正式日用版，没有发布。桌面连接不可用，实际屏幕滚动仍需用户体验确认。

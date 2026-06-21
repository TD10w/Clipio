# Clipio Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Rename the app's public identity to Clipio while preserving its Maccy-derived internals and clipboard-history location.

**Architecture:** Treat the rename as a configuration and presentation-layer change. Xcode project, target, products, bundle identifiers, and public labels become Clipio; internal Swift type names, source directories, shared scheme name, and the existing storage path remain unchanged for stability.

**Tech Stack:** Xcode project configuration, Swift/SwiftUI, property lists, XCTest, Git

---

### Task 1: Establish the failing identity audit

**Files:**
- Inspect: `Clip Barn.xcodeproj/project.pbxproj`
- Inspect: `Clip Barn.xcodeproj/xcshareddata/xcschemes/Maccy.xcscheme`
- Inspect: `Maccy/Info.plist`
- Inspect: `Maccy/Views/ListHeaderView.swift`

- [x] **Step 1: Run the desired-state audit before editing**

```bash
test -d "Clipio.xcodeproj" \
  && ! rg -n 'Clip Barns|Clip Barn|org\.p0deje\.Maccy' \
    CLAUDE.md AGENTS.md Maccy/Info.plist Maccy/AppDelegate.swift \
    Maccy/Views/ListHeaderView.swift Maccy/Settings \
    "Clipio.xcodeproj/project.pbxproj" \
    "Clipio.xcodeproj/xcshareddata/xcschemes/Maccy.xcscheme"
```

Expected: FAIL because the project directory, public labels, and bundle identifiers still use Clip Barn/Maccy identity.

### Task 2: Rename the Xcode project and build products

**Files:**
- Rename: `Clip Barn.xcodeproj` → `Clipio.xcodeproj`
- Modify: `Clipio.xcodeproj/project.pbxproj`
- Modify: `Clipio.xcodeproj/xcshareddata/xcschemes/Maccy.xcscheme`
- Modify: `Clipio.xcodeproj/project.xcworkspace/contents.xcworkspacedata`

- [x] **Step 1: Rename the project bundle**

```bash
mv "Clip Barn.xcodeproj" "Clipio.xcodeproj"
```

- [x] **Step 2: Update project identity**

Apply these exact mappings in `Clipio.xcodeproj/project.pbxproj`:

```text
Clip BarnUITests        -> ClipioUITests
Clip BarnTests          -> ClipioTests
Clip Barn.app           -> Clipio.app
Clip Barn               -> Clipio
org.p0deje.MaccyUITests -> com.clipio.app.uitests
org.p0deje.MaccyTests   -> com.clipio.app.tests
org.p0deje.Maccy        -> com.clipio.app
TEST_TARGET_NAME = Maccy -> TEST_TARGET_NAME = Clipio
```

Keep `Maccy`, `MaccyTests`, and `MaccyUITests` source-group paths unchanged. Update `productName` for the three targets to `Clipio`, `ClipioTests`, and `ClipioUITests` respectively.

- [x] **Step 3: Update shared scheme references**

Apply these exact mappings in `Clipio.xcodeproj/xcshareddata/xcschemes/Maccy.xcscheme`:

```text
Clip BarnUITests.xctest -> ClipioUITests.xctest
Clip BarnTests.xctest   -> ClipioTests.xctest
Clip Barn.app           -> Clipio.app
Clip BarnUITests        -> ClipioUITests
Clip BarnTests          -> ClipioTests
Clip Barn               -> Clipio
container:Clip Barn.xcodeproj -> container:Clipio.xcodeproj
```

Keep the scheme filename `Maccy.xcscheme` and test-plan reference `Maccy.xctestplan` unchanged.

- [x] **Step 4: Update workspace self-reference**

Ensure `Clipio.xcodeproj/project.xcworkspace/contents.xcworkspacedata` contains only a self-reference and no `Clip Barn.xcodeproj` path.

### Task 3: Update runtime and documentation identity

**Files:**
- Modify: `Maccy/Views/ListHeaderView.swift`
- Modify: `Maccy/AppDelegate.swift`
- Modify: `Maccy/Info.plist`
- Modify: `Maccy/About.swift`
- Modify: `Maccy/Observables/History.swift`
- Modify: `Maccy/Observables/SlideoutController.swift`
- Modify: `Maccy/Extensions/NSPasteboard.PasteboardType+Types.swift`
- Modify: `Maccy/Settings/*/AdvancedSettings.strings`
- Modify: `CLAUDE.md`
- Modify: `AGENTS.md`
- Modify: `README.md`

- [x] **Step 1: Update active app identifiers and labels**

Use `Clipio` for the header and public app name. Replace the old `org.p0deje.Maccy` runtime/defaults domain with `com.clipio.app` in active Swift and localized settings scripts. Preserve Swift type names such as `MaccyApp` and pasteboard API names such as `fromMaccy`.

- [x] **Step 2: Disable unsafe upstream updates**

Remove this pair from `Maccy/Info.plist`:

```xml
<key>SUFeedURL</key>
<string>https://raw.githubusercontent.com/p0deje/Maccy/master/appcast.xml</string>
```

Keep the Sparkle framework integration intact so a Clipio feed can be added later.

- [x] **Step 3: Make About attribution fork-safe**

Replace the public Maccy website/support strip with a single `Source` link to `https://github.com/TD10w/Maccy`. Retain original contributor credits and copyright attribution.

- [x] **Step 4: Update repository guidance**

Set the product name to Clipio, the bundle ID to `com.clipio.app`, and the required compile command project path to `Clipio.xcodeproj` in `CLAUDE.md` and `AGENTS.md`. Update the README title/intro and defaults examples for Clipio while retaining explicit attribution to the Maccy base project.

### Task 4: Verify the completed identity

**Files:**
- Verify: `Clipio.xcodeproj/project.pbxproj`
- Verify: `Clipio.xcodeproj/xcshareddata/xcschemes/Maccy.xcscheme`
- Verify: all modified runtime and documentation files

- [x] **Step 1: Re-run the desired-state identity audit**

Run the Task 1 audit again.

Expected: PASS with exit status 0 and no matching legacy public identity in the scoped active files.

- [x] **Step 2: Check Xcode resolves the renamed project and scheme**

```bash
xcodebuild -list -project "Clipio.xcodeproj"
```

Expected: project `Clipio`, target `Clipio`, test targets `ClipioTests` and `ClipioUITests`, and scheme `Maccy`.

- [x] **Step 3: Confirm effective build identity**

```bash
xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug -showBuildSettings \
  | rg 'PRODUCT_BUNDLE_IDENTIFIER|PRODUCT_NAME'
```

Expected: `PRODUCT_BUNDLE_IDENTIFIER = com.clipio.app` and `PRODUCT_NAME = Clipio` for the application target.

- [x] **Step 4: Run the required compile check**

```bash
xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`.

- [x] **Step 5: Review the final diff**

```bash
git diff --check
git status --short
git diff --stat
```

Expected: no whitespace errors; only Clipio rename files and the renamed project bundle are present.

- [x] **Step 6: Commit the verified checkpoint**

```bash
git add -A -- CLAUDE.md AGENTS.md README.md Maccy Clipio.xcodeproj "Clip Barn.xcodeproj"
git commit -m "Rename app to Clipio"
```

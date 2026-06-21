# Clipio Rename Design

## Goal

Rebrand the application from Clip Barn/Maccy to **Clipio** without destabilizing the clipboard engine or the in-progress shelf UI.

## Public identity

- Rename the Xcode project and application target to `Clipio`.
- Keep the shared Xcode scheme named `Maccy`, as required by the repository workflow.
- Set the application product/display name to `Clipio`.
- Change the application bundle identifier to `com.clipio.app`.
- Rename the unit-test and UI-test targets/products to use the Clipio name and update their host references.
- Replace user-visible Clip Barn/Maccy labels with Clipio, including the shelf header and About content.
- Keep the existing app icon for this rename checkpoint. Icon design belongs to the later UI/UX phase.

## Stability boundary

- Keep Swift type names, source directories, entitlements filenames, test source directories, and the `Maccy` scheme unchanged unless a build reference must change.
- Keep the existing `Maccy/Storage.sqlite` location so clipboard history remains available.
- Do not alter the card shelf, hover preview, drag behavior, or Liquid Glass styling.
- Preserve references to upstream Maccy where they are legally or technically relevant, such as attribution, source history, and comments.

## Update behavior

The fork must not silently install upstream Maccy releases over Clipio. The upstream Sparkle appcast will be removed from the Clipio application configuration. A Clipio update feed can be added later if releases are published.

## Migration expectations

Changing the bundle identifier makes macOS treat Clipio as a distinct application. Existing clipboard history remains at the shared storage location, but app preferences may return to defaults and macOS may require Accessibility and Launch at Login permission again.

## Verification

- Confirm no public Clip Barn labels or old application bundle identifier remain in active product configuration.
- Confirm project, target, product, test-host, and scheme references resolve correctly.
- Run the repository-required Debug compile check with code signing disabled and require `BUILD SUCCEEDED`.
- Launch verification remains a later product check; this checkpoint changes identity only.

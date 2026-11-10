#!/bin/zsh

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/make-dmg.sh <notarized Clipio ZIP or Clipio.app> <output .dmg>

Wrap an already notarized, stapled Clipio.app in a drag-to-Applications DMG,
then Developer ID sign, notarize and staple the DMG itself.

Required environment variables:
  CLIPIO_DEVELOPER_ID    Full "Developer ID Application: ..." identity
  CLIPIO_NOTARY_PROFILE  notarytool keychain profile name

Build the input first with scripts/release-beta.sh.
USAGE
}

fail() {
  print -u2 "Error: $1"
  exit 1
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { usage; exit 0; }
(( $# == 2 )) || { usage >&2; exit 2; }

input=${1:A}
output=${2:A}
developer_id=${CLIPIO_DEVELOPER_ID:-}
notary_profile=${CLIPIO_NOTARY_PROFILE:-}
[[ -n "$developer_id" ]] || fail "Set CLIPIO_DEVELOPER_ID to a Developer ID Application identity"
[[ "$developer_id" == "Developer ID Application:"* ]] || \
  fail "CLIPIO_DEVELOPER_ID must be a Developer ID Application identity"
[[ -n "$notary_profile" ]] || fail "Set CLIPIO_NOTARY_PROFILE to a notarytool keychain profile"
[[ -e "$input" ]] || fail "Input not found: $input"
[[ "$output" == *.dmg ]] || fail "Output must end in .dmg"
[[ ! -e "$output" ]] || fail "Refusing to overwrite existing output: $output"

work=$(mktemp -d "${TMPDIR:-/tmp}/clipio-dmg.XXXXXX")
trap 'rm -rf "$work"' EXIT
staging="$work/Clipio"
mkdir -p "$staging"

if [[ "$input" == *.zip ]]; then
  ditto -x -k "$input" "$staging"
else
  ditto "$input" "$staging/Clipio.app"
fi
app="$staging/Clipio.app"
[[ -d "$app" ]] || fail "No Clipio.app found in $input"

# Only package an app that is already notarized; the DMG does not fix the app.
xcrun stapler validate "$app"
spctl --assess --type execute "$app"

ln -s /Applications "$staging/Applications"

print "Creating DMG..."
mkdir -p "${output:h}"
hdiutil create -volname "Clipio" -srcfolder "$staging" -fs HFS+ -format UDZO -ov "$output" >/dev/null

codesign --sign "$developer_id" --timestamp "$output"
codesign --verify --strict "$output"

print "Submitting DMG to Apple notarization..."
xcrun notarytool submit "$output" --keychain-profile "$notary_profile" --wait
xcrun stapler staple "$output"
xcrun stapler validate "$output"
spctl --assess --type open --context context:primary-signature --verbose=2 "$output"

print "DMG ready: $output"

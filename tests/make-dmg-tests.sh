#!/bin/zsh

set -euo pipefail

project_dir=${0:A:h:h}
script="$project_dir/scripts/make-dmg.sh"
test_dir=$(mktemp -d /tmp/clipio-dmg-test.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT

fail() {
  print -u2 "$1"
  exit 1
}

[[ -x "$script" ]] || fail "Expected executable DMG script"
zsh -n "$script"

help_output=$("$script" --help)
[[ "$help_output" == *"notarize"* ]] || fail "Help must explain notarization"

touch "$test_dir/Clipio.zip"
if env -u CLIPIO_DEVELOPER_ID -u CLIPIO_NOTARY_PROFILE \
  "$script" "$test_dir/Clipio.zip" "$test_dir/out.dmg" >"$test_dir/no-id.log" 2>&1; then
  fail "DMG script must fail closed without a signing identity"
fi
grep -q "CLIPIO_DEVELOPER_ID" "$test_dir/no-id.log" || fail "Missing identity error must be actionable"

if env -u CLIPIO_NOTARY_PROFILE CLIPIO_DEVELOPER_ID="Developer ID Application: Test (TEAM)" \
  "$script" "$test_dir/Clipio.zip" "$test_dir/out.dmg" >"$test_dir/no-notary.log" 2>&1; then
  fail "DMG script must fail closed without a notary profile"
fi
grep -q "CLIPIO_NOTARY_PROFILE" "$test_dir/no-notary.log" || fail "Missing notary error must be actionable"
[[ ! -e "$test_dir/out.dmg" ]] || fail "No DMG may be produced on failure"

print "make-dmg tests passed"

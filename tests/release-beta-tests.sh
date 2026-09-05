#!/bin/zsh

set -euo pipefail

project_dir=${0:A:h:h}
release_script="$project_dir/scripts/release-beta.sh"
test_dir=$(mktemp -d /tmp/clipio-beta-release-test.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT

fail() {
  print -u2 "$1"
  exit 1
}

[[ -x "$release_script" ]] || fail "Expected executable beta release script"

help_output=$("$release_script" --help)
[[ "$help_output" == *"Developer ID"* ]] || fail "Help must explain Developer ID signing"
[[ "$help_output" == *"notar"* ]] || fail "Help must explain notarization"
[[ "$help_output" == *"--validate-only"* ]] || fail "Help must document validation-only mode"

if env -u CLIPIO_DEVELOPER_ID -u CLIPIO_NOTARY_PROFILE \
  "$release_script" --derived-data "$test_dir/derived" --output "$test_dir/Clipio-beta.zip" \
  >"$test_dir/missing-env.log" 2>&1; then
  fail "Beta release must fail closed when signing credentials are absent"
fi
grep -q "CLIPIO_DEVELOPER_ID" "$test_dir/missing-env.log" || \
  fail "Missing signing identity error must be actionable"

if env -u CLIPIO_NOTARY_PROFILE \
  CLIPIO_DEVELOPER_ID="Developer ID Application: Clipio Test (TESTTEAM)" \
  "$release_script" --derived-data "$test_dir/derived" --output "$test_dir/Clipio-beta.zip" \
  >"$test_dir/missing-notary.log" 2>&1; then
  fail "Beta release must fail closed when notarization credentials are absent"
fi
grep -q "CLIPIO_NOTARY_PROFILE" "$test_dir/missing-notary.log" || \
  fail "Missing notarization profile error must be actionable"

zsh -n "$release_script"

grep -q 'ARCHS="arm64 x86_64"' "$release_script" || fail "Beta build must be universal"
grep -q 'notarytool submit' "$release_script" || fail "Beta build must submit for notarization"
grep -q 'stapler staple' "$release_script" || fail "Beta build must staple the ticket"
grep -q 'spctl --assess' "$release_script" || fail "Beta build must run Gatekeeper assessment"
grep -q 'get-task-allow' "$release_script" || fail "Beta build must reject debug entitlements"
grep -q 'CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO' "$release_script" || \
  fail "Beta build must disable injected base entitlements"
grep -q 'XPCServices/Downloader.xpc' "$release_script" || \
  fail "Beta build must sign Sparkle helper code"
if grep -q 'OTHER_CODE_SIGN_FLAGS' "$release_script"; then
  fail "Beta build must not timestamp Swift Package intermediate objects"
fi

grep -q 'ENABLE_HARDENED_RUNTIME = YES;' "$project_dir/Clipio.xcodeproj/project.pbxproj" || \
  fail "Release must enable Hardened Runtime"

print "release-beta tests passed"

#!/bin/zsh
set -euo pipefail
project_dir=${0:A:h:h}
test_dir=$(mktemp -d /tmp/clipio-update-surface.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
# Execute the same gate used by production startup. No app launch or network.
swiftc "$project_dir/Clipio/UpdateConfiguration.swift" \
  "$project_dir/tests/update-configuration-tests.swift" -o "$test_dir/config-tests"
"$test_dir/config-tests"
python3 - "$project_dir/Clipio/Info.plist" <<'PY'
import plistlib
import sys
with open(sys.argv[1], 'rb') as file:
    info = plistlib.load(file)
assert not info.get('SUFeedURL'), 'Source must not contain an unprovisioned feed'
assert not info.get('SUPublicEDKey'), 'Release tooling injects the provisioned public key'
assert info['SUAllowsAutomaticUpdates'] is False, 'Installation requires user approval'
PY
print "beta-surface tests passed"

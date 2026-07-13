#!/bin/zsh

set -euo pipefail

project_dir=${0:A:h:h}
release_script="$project_dir/scripts/release-local.sh"
derived_data=$(mktemp -d /tmp/clipio-release-test.XXXXXX)
trap 'rm -rf "$derived_data"' EXIT

if [[ ! -x "$release_script" ]]; then
  print -u2 "Expected an executable local release script at $release_script"
  exit 1
fi

help_output=$("$release_script" --help)
[[ "$help_output" == *"--build-only"* ]] || {
  print -u2 "Expected --build-only to be documented"
  exit 1
}

"$release_script" --build-only --derived-data "$derived_data"

app_bundle="$derived_data/Build/Products/Release/Clipio.app"
[[ -d "$app_bundle" ]] || {
  print -u2 "Expected Release build at $app_bundle"
  exit 1
}

codesign --verify --deep --strict "$app_bundle"
git -C "$project_dir" check-ignore -q build/LocalRelease || {
  print -u2 "Expected local release build output to be ignored by Git"
  exit 1
}
print "release-local tests passed"

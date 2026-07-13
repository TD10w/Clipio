#!/bin/zsh

set -euo pipefail

project_dir=${0:A:h:h}
derived_data="$project_dir/build/LocalRelease"
build_only=false

usage() {
  cat <<'EOF'
Usage: scripts/release-local.sh [options]

Build an optimized, locally signed Clipio.app.

Options:
  --build-only                 Build and validate the app without installing it.
  --derived-data <path>        Store build output at this path.
  -h, --help                   Show this help.

Without --build-only, the script backs up the current /Applications/Clipio.app
to a temporary folder, installs the new build, and launches Clipio.
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --build-only)
      build_only=true
      ;;
    --derived-data)
      (( $# >= 2 )) || { print -u2 "Missing path after --derived-data"; exit 2; }
      derived_data="$2"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      print -u2 "Unknown option: $1"
      usage >&2
      exit 2
      ;;
  esac
  shift
done

print "Building Clipio Release..."
xcodebuild \
  -project "$project_dir/Clipio.xcodeproj" \
  -scheme Maccy \
  -configuration Release \
  -derivedDataPath "$derived_data" \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_ALLOWED=YES \
  build

app_bundle="$derived_data/Build/Products/Release/Clipio.app"
[[ -d "$app_bundle" ]] || { print -u2 "Release app was not produced at $app_bundle"; exit 1; }
codesign --verify --deep --strict "$app_bundle"

if $build_only; then
  print "Release app validated: $app_bundle"
  exit 0
fi

destination="/Applications/Clipio.app"
backup_dir=$(mktemp -d "${TMPDIR:-/tmp}/clipio-backup.XXXXXX")
backup_bundle="$backup_dir/Clipio.app"
backup_created=false
install_completed=false

restore_backup() {
  if $backup_created && ! $install_completed && [[ ! -e "$destination" ]]; then
    print -u2 "Restoring the previous Clipio.app..."
    mv "$backup_bundle" "$destination"
  fi
}
trap restore_backup EXIT

osascript -e 'tell application id "com.clipio.app" to quit' >/dev/null 2>&1 || true

if [[ -e "$destination" ]]; then
  mv "$destination" "$backup_bundle"
  backup_created=true
fi

ditto "$app_bundle" "$destination"
codesign --verify --deep --strict "$destination"
install_completed=true

print "Installed Clipio at $destination"
if $backup_created; then
  print "Previous app backup: $backup_bundle"
fi
open "$destination"

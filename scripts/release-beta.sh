#!/bin/zsh

set -euo pipefail

project_dir=${0:A:h:h}
derived_data=""
output="$project_dir/build/Beta/Clipio-beta.zip"
validate_only=""

usage() {
  cat <<'EOF'
Usage: scripts/release-beta.sh [options]

Build a universal, Developer ID signed, notarized Clipio beta ZIP.

Required environment variables for a new build:
  CLIPIO_DEVELOPER_ID    Full "Developer ID Application: ..." identity
  CLIPIO_NOTARY_PROFILE  notarytool keychain profile name

Options:
  --derived-data <path>  Store Xcode build output at this path (defaults to /private/tmp).
  --output <path>        Write the final notarized ZIP to this path.
  --validate-only <app>  Validate an already signed and stapled Clipio.app.
  -h, --help             Show this help.
EOF
}

fail() {
  print -u2 "Error: $1"
  exit 1
}

while (( $# > 0 )); do
  case "$1" in
    --derived-data)
      (( $# >= 2 )) || fail "Missing path after --derived-data"
      derived_data="$2"
      shift
      ;;
    --output)
      (( $# >= 2 )) || fail "Missing path after --output"
      output="$2"
      shift
      ;;
    --validate-only)
      (( $# >= 2 )) || fail "Missing app path after --validate-only"
      validate_only="$2"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
  shift
done

validate_signature() {
  local app_bundle="$1"
  local signature_info entitlements

  [[ -d "$app_bundle" ]] || fail "App bundle not found: $app_bundle"
  codesign --verify --deep --strict --verbose=2 "$app_bundle"

  signature_info=$(codesign -dv --verbose=4 "$app_bundle" 2>&1)
  [[ "$signature_info" == *"Authority=Developer ID Application:"* ]] || \
    fail "Artifact is not signed with Developer ID Application"
  [[ "$signature_info" == *"TeamIdentifier="* ]] || fail "Signed artifact has no Team ID"
  [[ "$signature_info" != *"TeamIdentifier=not set"* ]] || fail "Signed artifact has no Team ID"
  [[ "$signature_info" == *"runtime"* ]] || fail "Hardened Runtime is not enabled"

  entitlements=$(mktemp "${TMPDIR:-/tmp}/clipio-entitlements.XXXXXX")
  codesign -d --entitlements "$entitlements" "$app_bundle"
  if /usr/libexec/PlistBuddy -c "Print :com.apple.security.get-task-allow" "$entitlements" \
    >/dev/null 2>&1; then
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.get-task-allow' "$entitlements")" == "false" ]] || \
      fail "Release artifact contains get-task-allow"
  fi
  rm -f "$entitlements"
}

validate_distribution() {
  local app_bundle="$1"
  validate_signature "$app_bundle"
  xcrun stapler validate "$app_bundle"
  spctl --assess --type execute --verbose=4 "$app_bundle"
}

sign_sparkle_components() {
  local app_bundle="$1"
  local sparkle_bundle="$app_bundle/Contents/Frameworks/Sparkle.framework"
  local sparkle_version="$sparkle_bundle/Versions/B"

  [[ -d "$sparkle_bundle" ]] || return 0

  # Sparkle ships these helpers ad-hoc signed. Apple notarization requires
  # every nested executable to use a valid Developer ID certificate and a
  # secure timestamp, so sign from the deepest nested code outward.
  for item in \
    "$sparkle_version/XPCServices/Downloader.xpc" \
    "$sparkle_version/XPCServices/Installer.xpc" \
    "$sparkle_version/Updater.app"; do
    [[ -e "$item" ]] || continue
    codesign \
      --force \
      --sign "$developer_id" \
      --timestamp \
      --options runtime \
      "$item"
  done

  [[ -e "$sparkle_version/Autoupdate" ]] && codesign \
    --force \
    --sign "$developer_id" \
    --timestamp \
    --options runtime \
    "$sparkle_version/Autoupdate"

  codesign \
    --force \
    --sign "$developer_id" \
    --timestamp \
    --options runtime \
    "$sparkle_bundle"
}

if [[ -n "$validate_only" ]]; then
  validate_distribution "${validate_only:A}"
  print "Validated external beta app: ${validate_only:A}"
  exit 0
fi

developer_id=${CLIPIO_DEVELOPER_ID:-}
notary_profile=${CLIPIO_NOTARY_PROFILE:-}
[[ -n "$developer_id" ]] || fail "Set CLIPIO_DEVELOPER_ID to a Developer ID Application identity"
[[ "$developer_id" == "Developer ID Application:"* ]] || \
  fail "CLIPIO_DEVELOPER_ID must be a Developer ID Application identity"
[[ -n "$notary_profile" ]] || fail "Set CLIPIO_NOTARY_PROFILE to a notarytool keychain profile"
security find-identity -p codesigning -v | grep -F -- "$developer_id" >/dev/null || \
  fail "Developer ID identity is not available in this keychain"

if [[ -z "$derived_data" ]]; then
  derived_data=$(mktemp -d "/private/tmp/clipio-beta-build.XXXXXX")
else
  derived_data=${derived_data:A}
fi
output=${output:A}
[[ ! -e "$output" ]] || fail "Refusing to overwrite existing output: $output"

print "Building universal Clipio Release..."
xcodebuild \
  -project "$project_dir/Clipio.xcodeproj" \
  -scheme Maccy \
  -configuration Release \
  -derivedDataPath "$derived_data" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$developer_id" \
  CODE_SIGNING_ALLOWED=YES \
  ENABLE_HARDENED_RUNTIME=YES \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  build

app_bundle="$derived_data/Build/Products/Release/Clipio.app"
# Xcode also signs Swift Package intermediate object files when distribution
# signing is enabled. Timestamping those .o files fails on recent Xcode, so
 # timestamp the final app and nested distribution code explicitly after the
 # build has completed.
sign_sparkle_components "$app_bundle"
codesign \
  --force \
  --sign "$developer_id" \
  --timestamp \
  --options runtime \
  --entitlements "$project_dir/Maccy/Maccy.entitlements" \
  --generate-entitlement-der \
  "$app_bundle"
validate_signature "$app_bundle"

notary_dir=$(mktemp -d "${TMPDIR:-/tmp}/clipio-notary.XXXXXX")
trap 'rm -rf "$notary_dir"' EXIT
upload_zip="$notary_dir/Clipio-beta-upload.zip"
ditto -c -k --keepParent "$app_bundle" "$upload_zip"

print "Submitting Clipio to Apple notarization..."
xcrun notarytool submit "$upload_zip" --keychain-profile "$notary_profile" --wait
xcrun stapler staple "$app_bundle"
validate_distribution "$app_bundle"

mkdir -p "${output:h}"
ditto -c -k --keepParent "$app_bundle" "$output"
print "External beta artifact ready: $output"

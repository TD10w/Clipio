#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."

# A distinct bundle ID lets the test build run beside the owner's installed
# Clipio without activating or terminating their personal clipboard manager.
xcodebuild \
  -project "Clipio.xcodeproj" \
  -scheme "Maccy" \
  -derivedDataPath "${TMPDIR:-/tmp}/clipio-ui-tests" \
  test \
  -only-testing:ClipioUITests \
  CLIPIO_APP_BUNDLE_IDENTIFIER=com.clipio.app.uitesting \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_ALLOWED=YES

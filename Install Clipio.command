#!/bin/bash
#
# Double-click this file to build the latest Clipio and install it into
# /Applications. No Xcode needed — just double-click and wait.
#
cd "$(dirname "$0")" || exit 1

echo "Building Clipio (Release, optimized)…"
echo "(this can take a minute or two)"
if ! xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" \
      -configuration Release build CODE_SIGNING_ALLOWED=NO -quiet; then
  echo
  echo "❌ Build failed. Copy the messages above and send them to Claude."
  read -r -p "Press Return to close."
  exit 1
fi

APP=$(find ~/Library/Developer/Xcode/DerivedData/Clipio-*/Build/Products/Release \
      -maxdepth 1 -name "Clipio.app" 2>/dev/null | head -1)
if [ -z "$APP" ]; then
  echo "❌ Could not find the built app."
  read -r -p "Press Return to close."
  exit 1
fi

echo "Quitting any running copies…"
pkill -9 -f MacOS/Clipio 2>/dev/null

echo "Installing to /Applications/Clipio.app…"
rm -rf "/Applications/Clipio.app"
cp -R "$APP" "/Applications/Clipio.app"

echo "Launching…"
open "/Applications/Clipio.app"

echo
echo "✅ Done — Clipio is updated and running in your menu bar."
read -r -p "Press Return to close."

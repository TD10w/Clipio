#!/bin/zsh

set -euo pipefail

project_dir=${0:A:h:h}
settings="$project_dir/Maccy/Settings/GeneralSettingsPane.swift"
app_delegate="$project_dir/Maccy/AppDelegate.swift"

if grep -Eq 'SoftwareUpdater|automaticallyChecksForUpdates|checkForUpdates' "$settings"; then
  print -u2 "External beta settings must not expose unconfigured software updates"
  exit 1
fi

if grep -Eq 'SPUUpdater|SPUStandardUserDriver' "$app_delegate"; then
  print -u2 "Test startup must not initialize an unconfigured software updater"
  exit 1
fi

print "beta-surface tests passed"

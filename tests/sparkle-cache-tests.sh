#!/bin/zsh
set -euo pipefail

(( $# == 1 )) || { print -u2 'Usage: sparkle-cache-tests.sh <resolved Sparkle checkout>'; exit 2; }
sparkle_source=${1:A}/Sparkle
work=$(mktemp -d /tmp/clipio-sparkle-cache.XXXXXX)
trap 'rm -rf "$work"' EXIT

# Exercise the resolved dependency's real cache-path implementation. No Clipio
# launch, user-cache mutation or clipboard access is needed for this regression.
cat > "$work/main.m" <<'OBJC'
#import <Foundation/Foundation.h>
#import "SPULocalCacheDirectory.h"

int main(void) {
    @autoreleasepool {
        NSString *clipio = [SPULocalCacheDirectory cachePathForBundleIdentifier:@"com.clipio.app"];
        NSString *cacheRoot = [[clipio stringByDeletingLastPathComponent] lastPathComponent];
        if ([[cacheRoot pathExtension] isEqualToString:@"app"]) {
            fprintf(stderr, "FAIL: Clipio installation cache is inside an app-like directory: %s\n", cacheRoot.UTF8String);
            return 1;
        }
        NSString *normal = [SPULocalCacheDirectory cachePathForBundleIdentifier:@"com.example.clipio"];
        if (![[[normal stringByDeletingLastPathComponent] lastPathComponent] isEqualToString:@"com.example.clipio"]) {
            fprintf(stderr, "FAIL: ordinary reverse-DNS cache layout changed\n");
            return 1;
        }
        puts("Sparkle cache paths avoid an app-like directory for Clipio");
    }
    return 0;
}
OBJC

xcrun clang -fobjc-arc -framework Foundation -I "$sparkle_source" \
  -DSPU_OBJC_DIRECT_MEMBERS= -DSPU_OBJC_DIRECT= \
  '-DSPARKLE_BUNDLE_IDENTIFIER="org.sparkle-project.Sparkle"' \
  "$work/main.m" "$sparkle_source/SPULocalCacheDirectory.m" "$sparkle_source/SULog.m" \
  -o "$work/cache-tests"
"$work/cache-tests"

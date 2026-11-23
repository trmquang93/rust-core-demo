#!/usr/bin/env bash
# Usage: build-ios.sh [dev|release]   (default: release)
#   dev      debug profile, ONE slice (simulator; device if PLATFORM_NAME=iphoneos).
#   release  optimized + LTO, device + simulator slices.
# Output: build/lib/<sdk>/libgame_core.a + build/headers, linked directly by the app.
# Bindings are replaced only when the Rust API changed.
# No XCFramework: pack one separately (xcodebuild -create-xcframework) when sharing the library.
set -euo pipefail
export PATH="/opt/homebrew/opt/rustup/bin:$HOME/.cargo/bin:$PATH"
MODE="${1:-release}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT/game_core"

case "$MODE" in
  release) PROFILE_FLAG="--release"; PROFILE_DIR=release
           TARGETS=(aarch64-apple-ios aarch64-apple-ios-sim) ;;
  dev)     PROFILE_FLAG="";          PROFILE_DIR=debug
           if [ "${PLATFORM_NAME:-}" = iphoneos ]; then TARGETS=(aarch64-apple-ios)
           else TARGETS=(aarch64-apple-ios-sim); fi ;;
  *) echo "usage: $0 [dev|release]" >&2; exit 2 ;;
esac

# Host builds must not inherit Xcode's iOS SDKROOT.
host() { env -u SDKROOT -u IPHONEOS_DEPLOYMENT_TARGET -u LIBRARY_PATH cargo "$@"; }

for t in "${TARGETS[@]}"; do cargo build $PROFILE_FLAG --target "$t"; done

# Bindings: always generate to a temp dir, replace the real ones only when they differ,
# so Xcode does not recompile Swift after a logic-only Rust change.
GEN="$ROOT/build/gen"; TMP="$ROOT/build/gen.new"
host build   # host library: bindgen reads the metadata from it
rm -rf "$TMP"; mkdir -p "$TMP"
host run --bin uniffi-bindgen -- generate \
  --library target/debug/libgame_core.dylib --language swift --out-dir "$TMP"
if [ -d "$GEN" ] && diff -rq "$GEN" "$TMP" >/dev/null; then
  rm -rf "$TMP"; echo "bindings: unchanged"
else
  rm -rf "$GEN"; mv "$TMP" "$GEN"
  mkdir -p "$ROOT/ios/GameDemo/Generated"
  cp "$GEN/game_core.swift" "$ROOT/ios/GameDemo/Generated/"
  echo "bindings: regenerated"
fi

# Copy a file only when its content differs, so Xcode does not relink/recompile needlessly.
sync_file() { mkdir -p "$(dirname "$2")"; cmp -s "$1" "$2" || cp "$1" "$2"; }

# The app links these directly (build/lib/<sdk>/libgame_core.a + build/headers).
sync_file "$GEN/game_coreFFI.h" "$ROOT/build/headers/game_coreFFI.h"
sync_file "$GEN/game_coreFFI.modulemap" "$ROOT/build/headers/module.modulemap"
for t in "${TARGETS[@]}"; do
  case "$t" in aarch64-apple-ios-sim) SDK=iphonesimulator ;; *) SDK=iphoneos ;; esac
  sync_file "target/$t/$PROFILE_DIR/libgame_core.a" "$ROOT/build/lib/$SDK/libgame_core.a"
done

echo "OK ($MODE): ${TARGETS[*]}"

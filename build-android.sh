#!/usr/bin/env bash
# Usage: build-android.sh [dev|release]   (default: release)
#   dev      debug profile (fast incremental builds).
#   release  optimized + LTO.
# Bindings are replaced only when the Rust API changed.
set -euo pipefail
export PATH="/opt/homebrew/opt/rustup/bin:$HOME/.cargo/bin:$PATH"
MODE="${1:-release}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
NDK="$(ls -d "$SDK"/ndk/* | sort -V | tail -1)"
TC="$(ls -d "$NDK"/toolchains/llvm/prebuilt/*)"
API=24
TARGET=aarch64-linux-android

case "$MODE" in
  release) PROFILE_FLAG="--release"; PROFILE_DIR=release ;;
  dev)     PROFILE_FLAG="";          PROFILE_DIR=debug ;;
  *) echo "usage: $0 [dev|release]" >&2; exit 2 ;;
esac

export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$TC/bin/aarch64-linux-android$API-clang"
export CC_aarch64_linux_android="$TC/bin/aarch64-linux-android$API-clang"
export AR_aarch64_linux_android="$TC/bin/llvm-ar"

cd "$ROOT/game_core"
cargo build $PROFILE_FLAG --target "$TARGET"

APP="$ROOT/android/app/src/main"
# Bindings: always generate to a temp dir, replace the real ones only when they differ.
GEN="$ROOT/build/gen-kt"; TMP="$ROOT/build/gen-kt.new"
cargo build   # host library: bindgen reads the metadata from it
rm -rf "$TMP"; mkdir -p "$TMP"
cargo run --bin uniffi-bindgen -- generate --no-format \
  --library target/debug/libgame_core.dylib --language kotlin --out-dir "$TMP"
if [ -d "$GEN" ] && diff -rq "$GEN" "$TMP" >/dev/null; then
  rm -rf "$TMP"; echo "bindings: unchanged"
else
  rm -rf "$GEN"; mv "$TMP" "$GEN"
  mkdir -p "$APP/java"; rm -rf "$APP/java/uniffi"; cp -R "$GEN/uniffi" "$APP/java/"
  echo "bindings: regenerated"
fi

mkdir -p "$APP/jniLibs/arm64-v8a"
cp "target/$TARGET/$PROFILE_DIR/libgame_core.so" "$APP/jniLibs/arm64-v8a/"
echo "OK ($MODE): $TARGET"

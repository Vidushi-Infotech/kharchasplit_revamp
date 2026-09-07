#!/usr/bin/env bash
# Release build with Dart-side obfuscation + split debug info.
#
#   ./scripts/build_release.sh appbundle   # Play Store (default)
#   ./scripts/build_release.sh apk         # sideload / QA
#
# Why a script: `flutter build --release` alone ships readable Dart symbols
# in the AOT snapshot. `--obfuscate` strips them and `--split-debug-info`
# writes the symbol files needed to de-obfuscate Crashlytics stack traces.
# Without the second flag an obfuscated crash is unreadable.
#
# Symbol upload: after a store build, run
#   firebase crashlytics:symbols:upload --app=<ANDROID_APP_ID> build/symbols
# (needs the Firebase CLI and the app id from google-services.json). The
# script does it for you when FIREBASE_ANDROID_APP_ID is set and the CLI is
# on PATH.
set -euo pipefail

cd "$(dirname "$0")/.."

TARGET="${1:-appbundle}"
SYMBOLS_DIR="build/symbols"

if [[ ! -f android/key.properties ]]; then
  echo "error: android/key.properties is missing — this would be signed with the debug key." >&2
  echo "       Add the release keystore config before building for distribution." >&2
  exit 1
fi

mkdir -p "$SYMBOLS_DIR"

flutter build "$TARGET" \
  --release \
  --obfuscate \
  --split-debug-info="$SYMBOLS_DIR" \
  "${@:2}"

if [[ -n "${FIREBASE_ANDROID_APP_ID:-}" ]] && command -v firebase >/dev/null 2>&1; then
  echo "Uploading Dart symbols to Crashlytics…"
  firebase crashlytics:symbols:upload --app="$FIREBASE_ANDROID_APP_ID" "$SYMBOLS_DIR"
else
  echo "Symbols written to $SYMBOLS_DIR (set FIREBASE_ANDROID_APP_ID to auto-upload)."
fi

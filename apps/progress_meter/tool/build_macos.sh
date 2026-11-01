#!/usr/bin/env bash
# Direct Xcode project fallback when a sandbox prevents loading .xcworkspace.
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:-Release}"
if [[ $# -gt 0 ]]; then shift; fi
if [[ "$mode" != "Debug" && "$mode" != "Release" ]]; then
  echo "Usage: bash tool/build_macos.sh [Debug|Release]" >&2
  exit 2
fi
flutter pub get
if [[ "$mode" == "Release" ]]; then
  flutter build macos --release --config-only "$@"
else
  flutter build macos --debug --config-only "$@"
fi
(cd macos && pod install)
products="$PWD/build/macos/Build/Products"
xcodebuild -project macos/Pods/Pods.xcodeproj -scheme Pods-Runner \
  -configuration "$mode" -sdk macosx -derivedDataPath build/macos \
  -destination 'platform=macOS' SYMROOT="$products" \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=NO
xcodebuild -project macos/Runner.xcodeproj -scheme Runner \
  -configuration "$mode" -sdk macosx -derivedDataPath build/macos \
  -destination 'platform=macOS' CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=NO
# Ad-hoc signing is sufficient for a locally built application.
codesign --force --deep --sign - --entitlements "macos/Runner/$([[ "$mode" == "Debug" ]] && echo DebugProfile || echo Release).entitlements" "$products/$mode/Progress Meter.app"
echo "Built $products/$mode/Progress Meter.app"

#!/bin/bash
# Builds AMS Tracking for the iPhone simulator.   tools/build.sh [build|test]
# Two traps this script exists for: files under ~/Documents pick up extended attributes
# that codesign refuses, and derived data must live outside ~/Documents.
set -e
cd "$(dirname "$0")/.."
DD="${TMPDIR:-/tmp}/AMSTracking-build"
find . -path ./.git -prune -o -print0 | xargs -0 xattr -c 2>/dev/null || true
xcodegen generate
xcodebuild \
  -project AMSTracking.xcodeproj \
  -scheme AMSTracking \
  -destination "${DEST:-platform=iOS Simulator,name=iPhone 17 Pro}" \
  -derivedDataPath "$DD" \
  "${1:-build}"
echo
echo "App: $DD/Build/Products/Debug-iphonesimulator/AMSTracking.app"

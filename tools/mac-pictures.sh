#!/bin/bash
# Photographs pages of the Mac app, by day and by night, with the made-up sample data and without a click.
#   tools/mac-pictures.sh [out-folder]        (default: build/shots/mac)
# The app opens each page itself (App/Sources/PictureArgs.swift, only with -uiTesting = sample data in a
# throw-away folder) and `screencapture` takes the window. Look at every picture afterwards.
set -e
cd "$(dirname "$0")/.."
OUT="${1:-build/shots/mac}"; mkdir -p "$OUT"
DD="${TMPDIR:-/tmp}/AMSTracking-macpictures"
xcodegen generate >/dev/null
xcodebuild -project AMSTracking.xcodeproj -scheme AMSTracking -destination 'platform=macOS' -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD" || true
BIN="$DD/Build/Products/Debug/AMSTracking.app/Contents/MacOS/AMSTracking"
[ -x "$BIN" ] || { echo "no Mac app built"; exit 1; }
swiftc -O tools/winid.swift -o "$DD/winid"
SHOTS=(
"01-today|-section today -habit h_fast"
"02-today-parts|-section today -habit h_parts"
"03-stats|-section stats -habit h_work"
"04-lastweek|-section lastWeek -habit h_read"
"05-lastmonth|-section lastMonth"
"06-aspirations|-section aspirations"
"07-settings|-section settings"
"08-add|-section today -sheet add"
"09-grid|-section today -grid -habit h_fast"
)
for mode in light dark; do
  for s in "${SHOTS[@]}"; do
    name="${s%%|*}"; args="${s#*|}"
    "$BIN" -uiTesting -sample $args -$mode >/dev/null 2>&1 &   # the day/night switch LAST: in front of other switches the Mac app opened no window
    pid=$!
    sleep 5
    wid=$("$DD/winid" $pid | awk '$2==0 {print $1; exit}')
    [ -n "$wid" ] && screencapture -x -o -l "$wid" "$OUT/$mode-$name.png"
    kill $pid 2>/dev/null; wait $pid 2>/dev/null || true
  done
done
ls "$OUT" | wc -l

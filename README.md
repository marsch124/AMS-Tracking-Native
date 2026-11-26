# AMS Tracking

A habit tracker for iPhone, iPad and Mac, one app with one icon. It keeps daily habits, weekly targets, habits with
several parts, and start/stop habits for fasting, with streaks, a calendar you can correct, fasting stages and rings,
Stats, a written look back at last week and last month, and aspirations (one sentence about who you want to become,
answered by the habits that serve it).

- Your data is one file in iCloud Drive, merged habit by habit between devices, with a proved safety copy every day (30 kept).
- Siri ("start fasting in Tracking"), Shortcuts and the Home Screen icon menu change a fast directly.
- Daily reminder and icon number are local to each device. No server, no account, no analytics.
- A backup from the earlier web version of Tracking imports here (Settings, Import backup).

Needs iOS 17 or later, or macOS 14 or later.

## Build

```
tools/build.sh          # runs xcodegen, then builds for the iPhone simulator
tools/build.sh test     # builds and runs the tests
```

The Xcode project is generated from `project.yml` (XcodeGen). Releases go to TestFlight with `tools/release.sh`.

## Where things are

- `App/Sources` — the app (SwiftUI, one target for all three devices)
- `Tests`, `UITests` — small data tests and one screen test per screen
- `docs/spec` — the written specification: `01-native.md` (this app), `02-rules.md` (data and logic rules), `03-screens-web.md` (the screens inherited from the web version)
- `docs/what-to-test` — the TestFlight "What to Test" text of each version

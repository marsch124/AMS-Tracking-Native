# AMS Tracking — data and logic rules for the SwiftUI port

Source read: `js/app.js` v1.51 (5,654 lines), `js/icons.js`, `ios/App/App/Fasting.swift`, `CLAUDE.md`.
All line numbers refer to `js/app.js` unless stated. "Today" = device local time zone. All times stored as epoch **milliseconds** (integers).
Convention in this file: `H:MM` = `fmtDuration` (see 2.7).

---------------------------------------------------------------------
## 0. Things that are surprising or easy to get wrong (read first)

1. **Import never calls `migrate()`** (l.5027-5036). Only app start does (l.126). A backup without `settings` crashes the JS until the next launch. In Swift: always run the migration after decoding.
2. **There is no "weekly review card" and no "month review card" any more.** Today has two permanent buttons "Last week" and "Last month" (`renderReviewLinks`, l.1333). `settings.lastReviewWeek` and `settings.lastMonthReview` are **never read or written** by the code (only mentioned in comments l.1324 and in CLAUDE.md). They may still exist in old backups; keep them as optional ignored fields.
3. "Most consistent weekday" in CLAUDE.md is really **"strongest day" = weekday with the highest AVERAGE fast length** (`buildRhythmCard`, l.4187). Ties go to the earliest weekday.
4. A **fast counts for the day it ENDS on**, and `doneSet` for timer habits is derived from `sessions`; `habit.done` is unused for timers.
5. The eating-window countdown uses `goalHoursOn(habit, day after last end)` and ignores `session.g`; the ring/countdown of a running fast uses `session.g` first. `session.g` is no longer written by any UI (removed v1.46/47) but old data may contain it and it is still honoured.
6. Overlong guard (>24h) wins over "goal reached".
7. Weekly-target habits: streak counts WEEKS; the daily `currentStreak` is never used for them in the UI, but `isScheduled` returns true for every non-`daily` type.
8. `habit.days` is saved for every type (also weekly/timer) but only read when `type === 'daily'`.
9. Habit order = array order of `state.habits` (no order field). Archived habits stay in the array.
10. The backup JSON is the whole `state` object `JSON.stringify(state, null, 2)` — it includes `settings` (reminder ids, lastBackup, etc.).
11. Export writes `lastBackup` AFTER the share succeeds, so the exported file contains the OLD `lastBackup`.
12. Hint text in the calendar says "0 = skip day" but the hours sheet rejects hours <= 0 (toast); skip day is a separate button.

---------------------------------------------------------------------
## 1. Storage: localStorage key `amsTracking.v1` (STORE_KEY, l.5)

### 1.1 Root object `state`
```
{
  "version": 1,                 // only written by the first-run seed (l.152); never read. Optional.
  "habits":  [ Habit ],         // ORDER = display order
  "aspirations": [ Aspiration ],// created empty by migrate if missing
  "settings": { Settings }      // created {} by migrate if missing
}
```
`load()` (l.143): returns `JSON.parse(raw)` if the key exists; on parse error (or no key) returns the first-run seed:
```
{ version:1, habits:[{ id:newId(), name:"Intermittent Fasting", icon:"moon", color:"#7a5af8",
  type:"timer", days:[true x7], goalHours:16, createdAt:dateKey(today), done:{}, sessions:[] }] }
```
(`settings` and `aspirations` are then added by `migrate`.)

`newId()` (l.235): `"h" + base36(Date.now()) + 5 random base36 chars`. Aspirations use the same generator. ID is just an opaque string.

### 1.2 Habit
| field | type | meaning |
|---|---|---|
| `id` | string | unique |
| `name` | string | trimmed, non-empty. May contain `|` (multi-part, see 4) |
| `icon` | string | one of the icon names (below) |
| `color` | string | hex `#rrggbb`, one of PALETTE (below) — any hex accepted when reading |
| `type` | `"daily"` \| `"weekly"` \| `"timer"` | |
| `days` | [Bool] x7 | scheduled weekdays, **Monday-first** (Mon=index 0). Only used for `daily`. Always saved (default all true). At least one true (UI prevents all-false, l.4554) |
| `target` | Int 1…7 \| null | weekly: required count per week. Missing/0 treated as 1 (`habit.target \|\| 1`). null for daily/timer |
| `goalHours` | Number \| null | timer: default fast goal in hours (0<g<=48, decimals allowed) |
| `goalByDay` | [Number\|null] x7 \| null | timer: per-weekday goal override (Mon-first, keyed by the day the fast ENDS). null when no entry is set |
| `createdAt` | `"YYYY-MM-DD"` | creation day (may be missing in old data → treated as "today"/"existed always" depending on function) |
| `done` | { "YYYY-MM-DD": `1` \| [Int] } | daily/weekly completion map. Value `1` = done (for parts habits: "all parts"); array = indices of parts done (see 4). Timer habits: `{}` and unused |
| `skip` | { "YYYY-MM-DD": 1 } | excused days (vacation/skip). Optional (absent until first use) |
| `notes` | { "YYYY-MM-DD": string } | day notes, max 200 chars, trimmed. Optional |
| `sessions` | [Session] | timer habits only. Kept sorted ascending by `s` after every add/edit |
| `archived` | Bool | optional; true = hidden from Today/Stats/review (undo/restore sets it to `false`, not deleted) |
| `aspirationId` | string \| null | optional link to an Aspiration |
| `lastCelebrated` | string | optional, e.g. `"day7"`, `"week4"` (milestone memory, see 3.6) |

Session: `{ "s": startMs, "e": endMs | null, "g": hours? }`.
- `e == null` ⇒ running fast. `activeSession` = first session (array order) with no `e` (l.440). `lastFinishedSession` = last array element that has `e` (l.444) — array order (by start), not by end time.
- `g` optional goal (hours) for that single fast; takes precedence over habit goals (2.4). Never written by current UI.

Allowed colors (PALETTE, l.110): `#3b70f0 #e0447c #2fa96d #ee8b2c #d9463e #7a5af8 #2aa8c4 #c9a227` (blue, pink, green, orange, red, purple, teal, yellow). New habit default color = `PALETTE[state.habits.length % 8]` (l.4392). Default icon for a new habit: `meditate`.

Habit icon names (ICON_NAMES_HABIT, js/icons.js l.292, the 40 pickable ones):
`meditate dumbbell book guitar run sunrise books moon drop apple bike pen tooth broom sun timer heart pulse music bed pill glass coffee phoneOff smokeOff wineOff leaf shoe waves kettlebell bulb camera brush coin paw flower mountain chat snowflake stairs`.
ICON_PATHS also contains UI icons (sliders plus pencil check play stop x flame export import help scroll sprout chart trophy chevL chevR chevU chevD reorder target case bell grid) — `migrate` accepts any key of ICON_PATHS as valid, so a habit icon of e.g. `plus` is left alone.
Search keywords (EN/DE) per habit icon exist in `ICON_KEYWORDS` (icons.js l.301) — only for the icon picker search (name substring OR keyword substring, case-insensitive).

### 1.3 Aspiration
`{ "id": string, "title": string, "createdAt": "YYYY-MM-DD", "archivedAt"?: "YYYY-MM-DD" }`. "Live" = no `archivedAt` (`liveAspirations`, l.1113). Archiving sets `archivedAt = today`; undo deletes the key. Habits keep their `aspirationId` when the aspiration is archived (they simply count as unattached).

### 1.4 Settings (all optional except as migrated)
| key | type | rule |
|---|---|---|
| `layout` | `"list"` \| `"grid"` | migrate default `"list"`; Settings toggle flips |
| `theme` | `"auto"`\|`"light"`\|`"dark"` | migrate default `"auto"`; toggle cycles auto→light→dark→auto |
| `badge` | Bool | app-icon badge wanted (default off; `=== true` test, l.196) |
| `reminder` | `{ on:Bool, time:"HH:MM", id?, endpoint?, tz?, syncedAt?, dirty?, doneReported?{date:Bool}, lostPermission? }` | see 7.8. Only `on`, `time`, `lostPermission` matter natively |
| `lastBackup` | epoch ms | set on successful JSON export |
| `lastBackupNudge` | epoch ms | set when the backup toast is shown |
| `aspNudges` | { "quiet:<aspId>" \| "empty:<aspId>" \| "loose" : "YYYY-MM-DD" } | day-key of the Monday of the week the nudge was last SHOWN |
| `lastReviewWeek`, `lastMonthReview` | — | vestigial, never used (see 0.2) |

### 1.5 `migrate(st)` — every step (l.129-141)
Runs once at app start on the loaded (or seeded) state:
1. For every habit: if `EMOJI_TO_ICON[h.icon]` exists → replace by that name; else if `h.icon` is not a key of ICON_PATHS → `"sun"`.
   Emoji map (icons.js l.345): 🧘→meditate 💪→dumbbell 📖→book 🎸→guitar 🏃→run 🌅→sunrise 📚→books 🌙→moon 💧→drop 🥗→apple 🚴→bike ✍️→pen 🦷→tooth 🧹→broom ☀️→sun ⏱️→timer.
2. `st.aspirations = st.aspirations || []`.
3. `st.settings = st.settings || {}`.
4. `if (!settings.layout) settings.layout = "list"`.
5. `if (!settings.theme) settings.theme = "auto"`.
That is all. No other field is back-filled; every reader tolerates missing `done/skip/notes/sessions/days/target/createdAt/goalByDay/aspirationId` (`|| {}`, `|| []`, `|| [true x7]`). `reminderSettings()` (l.5184) additionally normalises: creates `{on:false,time:"20:00"}` if missing and resets `time` to `"20:00"` if it does not match `^([01]\d|2[0-3]):[0-5]\d$`.

### 1.6 JSON backup export (l.4827-4848)
- Content: `JSON.stringify(state, null, 2)` (whole state incl. settings, archived habits, aspirations).
- File name: `ams-tracking-backup-YYYY-MM-DD.json` (dateKey of today), MIME `application/json`; delivered through the share sheet (or download).
- On success: `settings.lastBackup = Date.now()`, save, toast "Backup saved". User cancel (AbortError) is silent; other errors `alert('Backup failed: …')`.

### 1.7 JSON import (l.5019-5045)
Accepts: any JSON file whose parsed value is truthy and has `habits` as an Array. Otherwise error `Import failed: Not an AMS Tracking backup` (or the JSON parse message). No per-field validation, no version check.
- **Replace, never merge**: `confirm("Replace current data with this backup (N habits)?")`; on OK `state = data` (whole root replaced: habits, aspirations, settings, everything). Cancel = nothing happens.
- Native only: if `settings.reminder.on` and notification permission is not granted → `reminder.on = false`.
- Then save, close settings, re-render. (`aspirations` may be absent after import → JS code does `(state.aspirations || [])` in readers but `state.aspirations.push` in the aspiration save would throw; port should migrate.)

### 1.8 Example backup (made-up data)
```json
{
  "version": 1,
  "habits": [
    {
      "id": "hm3k9x2ab1c",
      "name": "Intermittent Fasting",
      "icon": "moon",
      "color": "#7a5af8",
      "type": "timer",
      "days": [true,true,true,true,true,true,true],
      "goalHours": 16,
      "goalByDay": [16,16,16,16,14,null,null],
      "createdAt": "2026-08-30",
      "done": {},
      "skip": { "2026-11-20": 1 },
      "notes": { "2026-11-12": "Dinner party, ate late" },
      "aspirationId": "hm3ka0zz9q1",
      "sessions": [
        { "s": 1794254400000, "e": 1794315600000 },
        { "s": 1794340800000, "e": null }
      ]
    },
    {
      "id": "hm3k9y7fg4d",
      "name": "Medit | Brea | Cold",
      "icon": "meditate",
      "color": "#3b70f0",
      "type": "daily",
      "days": [true,true,true,true,true,true,true],
      "goalHours": null, "goalByDay": null, "target": null,
      "createdAt": "2026-09-01",
      "done": { "2026-11-24": [0,2], "2026-11-25": 1, "2026-11-26": [1] },
      "sessions": [],
      "lastCelebrated": "day7"
    },
    {
      "id": "hm3kb1c8pq2",
      "name": "Strength",
      "icon": "dumbbell",
      "color": "#ee8b2c",
      "type": "weekly",
      "days": [true,true,true,true,true,true,true],
      "target": 2,
      "createdAt": "2026-09-14",
      "done": { "2026-11-23": 1, "2026-11-25": 1 },
      "sessions": [],
      "archived": false
    }
  ],
  "aspirations": [
    { "id": "hm3ka0zz9q1", "title": "Strong and durable into my seventies", "createdAt": "2026-10-02" }
  ],
  "settings": {
    "layout": "list",
    "theme": "auto",
    "badge": false,
    "reminder": { "on": true, "time": "20:00" },
    "lastBackup": 1795000000000,
    "lastBackupNudge": 1795000000000,
    "aspNudges": { "loose": "2026-11-16" }
  }
}
```
(The two timestamps in the example are illustrative.)

---------------------------------------------------------------------
## 2. Dates, days, fasting-goal lookup

### 2.1 Primitives (l.241-258)
- `dateKey(d)` = local `YYYY-MM-DD` (zero-padded). `keyToDate(key)` = local midnight of that day.
- `addDays(d, n)`: calendar add (`setDate`), keeps time of day, DST-safe → in Swift use `Calendar.date(byAdding: .day)`.
- `weekdayIdx(d)` = `(getDay()+6)%7` → **Monday=0 … Sunday=6**. Day letters `M T W T F S S`.
- `weekStart(d)` = `addDays(d, -weekdayIdx(d))` (the Monday; the JS keeps the time of day — compare week starts only by `dateKey`, never by timestamp; l.353-358 documents a bug caused by that). Weeks are Monday-first everywhere.
- `isScheduled(habit, d)` (l.296): `type !== "daily"` → true; else `days[weekdayIdx(d)]` (default all true).
- Habit "done for day K" = `doneSet(habit)[K]` (l.261): non-timer → `habit.done` (truthy value: `1` or a non-empty array); timer → set of `dateKey(new Date(s.e))` for every session with an `e`.
- Skip for K = `habit.skip[K]`.

### 2.2 "A fast counts for the day it ENDS on"
Every timer statistic (done set, calendar, streaks, goal lookup, weekday rhythm, week/month stats) keys a session by `dateKey(end)`. A fast 20:00 Tue → 12:00 Wed counts for Wednesday. A running fast counts for nothing until it ends.

### 2.3 goalDayFor(session) (l.283)
- Finished (`e` set): `Date(e)`.
- Running: `s = Date(session.s)`; if `s.hour >= 12` → **next day** (`addDays(s,1)`), else same day (a morning start ends the same day).

### 2.4 Goal precedence (l.275-294)
`goalHoursOn(habit, day)`: `g = goalByDay?[weekdayIdx(day)]`; valid if non-null, finite and > 0 → `g`, else `habit.goalHours` (may be null).
`goalMsFor(habit, session)`: `h = session.g (truthy) || goalHoursOn(habit, goalDayFor(session))`; returns `h*3600000` or null. With no session: `habit.goalHours`.
Order: **session.g → goalByDay[weekday of goalDayFor] → habit.goalHours → none**.
Goal-met test for finished fasts (`fastDayStats`, l.427): `g = s.g || goalHoursOn(habit, Date(s.e))`; met when `!g` (no goal at all → counts as met) or `(e-s) >= g*3600000`. Per day: `ms[K] = sum of (e-s)` of all fasts ending that day; `met[K] = true` if ANY of them is met.

### 2.5 Edit-habit goal inputs (l.4576-4582)
Parse with comma→dot, valid if finite, 0 < v <= 48, else null. `goalByDay` = array of 7 parsed values if at least one is non-null, else null. Only saved for timer habits.

### 2.6 Backfilled fast (l.2083)
Hours h: valid when finite, 0<h<=48 (else toast "Please enter a fast length between 0 and 48 hours."). Recorded as `e = noon (12:00 local) of the chosen day`, `s = e - h*3600000`. Presets shown: unique of `[goalHoursOn(habit, day), 13, 15, 16, 18]` (non-null). Same preset list is also used for history import (`FAST_GOAL_PRESETS=[13,15,16,18]`).

### 2.7 fmtDuration (l.452)
`totalMin = floor(ms/60000)`; `"h:mm"` = `floor(totalMin/60)` (not padded, may exceed 24) + `":"` + 2-digit minutes. Negative never expected.

---------------------------------------------------------------------
## 3. Streaks, completion, milestones

### 3.1 Daily / timer: `currentStreak(habit, ref?)` (l.369)
`d = ref or today`. If `isScheduled(d)` and d not done → `d = d-1` (**today never breaks the streak while pending**). Then walk backwards (max 3700 days): unscheduled days are skipped silently (neither count nor break); scheduled day: done → `streak++`; not done but skip → excused (no count, no break); not done and not skip → stop. (A today that is unscheduled does not move `d`.) Works for timer habits via the ends-on-day set (all days scheduled).

### 3.2 Longest streak (l.387)
`keys = sorted done keys`; none → 0. Walk forward from `keyToDate(keys[0])` through today (max 3700 days): scheduled day: done → `run++`, `best=max`; not done and not skip → `run=0`; skip → untouched; unscheduled → untouched. Returns best. (Today not done does not matter since it is the last day.)

### 3.3 Weekly target (l.306-366)
- `weekDoneCount(habit, ws)` = number of the 7 days from Monday `ws` with `done` truthy.
- `weekHasSkip` = any skip key in those 7 days.
- `weeklyStreak(habit, ref?)` (l.324): `target = habit.target||1`; `w = weekStart(ref or today)`; `streak = 1 if this week's count >= target else 0` (**week in progress counts once met but never breaks**); then previous weeks (max 530): met → `streak++`; not met and **no skip in that week** → stop; not met but the week contains a skip day → excused (continues, no count).
- `weeklyStats(habit)` → `{weeksMet, weeksTotal, best}` (l.339): `start = min(createdAt (default today), earliest done key)`; iterate weeks from `weekStart(start)` through the current week (max 530). Per week: `met = count>=target`; `inProgress = dateKey(w)==dateKey(thisWeek)`; `excused = !met && weekHasSkip`. `weeksTotal++` if `(!inProgress || met) && !excused`. If met: `weeksMet++; run++; best=max(best,run)`; else if `!inProgress && !excused` → `run = 0` (an unmet in-progress or excused week leaves the run intact).

### 3.4 Completion % (l.407)
`start = min(createdAt (default today), earliest done key)`; `scheduled` = count of days from start through today (max 3700) that are scheduled and not skip. `doneCount = number of done keys` (**all done days, including on unscheduled days**). `total = max(scheduled, doneCount)`; `pct = scheduled ? round(100*doneCount/total) : 0`. Displayed `"{pct}% ({done} of {total} days)"`.

### 3.5 "x days to your record" (l.4331)
On the Stats card: `cur` = current streak (weeks for weekly), `best` = longest. Shown when `cur > 0 && best - cur > 0 && best - cur <= (weekly ? 1 : 3)`. Text `"{gap} day(s)|week(s) to your record"` (singular when gap == 1). Disappears once `cur >= best`.

### 3.6 Milestones (l.466-514)
- Day milestones `[7,14,30,50,100,200,365,500,730,1000]`; week milestones `[4,10,26,52,104]` (weekly habits).
- `maybeCelebrateStreak(habit)` is called only after a **live check-off that turns a day from not-done into done**: `toggleToday` (when it becomes done), `togglePart` (when the day goes from no parts to ≥1), `swipeDone` (non-timer, not already done; for parts habits only if no part was done before). Never from backfills (long-press yesterday, calendar taps, parts sheet), never for timer habits (they have only the personal-best fast celebration).
- `value = weekly ? weeklyStreak : currentStreak` (after the tick). If `value` ∈ list: `tag = ("week"|"day") + value`; if `habit.lastCelebrated === tag` → nothing; else store `habit.lastCelebrated = tag`, save, show celebration "`{value}-day|week streak!`" with sub text = habit name. So each milestone fires once per habit, remembered in `habit.lastCelebrated` (only the LAST tag is remembered).
- Achievements card (l.4230): per non-archived habit, `best = weekly ? weeklyStats.best : longestStreak`; earned chips = every milestone `<= best` (suffix `w` for weekly else `d`, e.g. `7d`, `4w`); the next milestone (first `> best`) as hollow chip. Timer habits use day milestones with `longestStreak`.

### 3.7 Personal-best fast (l.1507)
In `endFast`: `others` = the habit's finished sessions except the one just ended; if `others.length >= 3` and the new duration is **strictly greater than** the max duration of `others` → celebrate "Personal best fast!" with sub `"{H:MM} h · {habit name}"`. Also fires for a Siri/menu stop (same `endFast`).

---------------------------------------------------------------------
## 4. Multi-part habits (v1.27/1.28, l.1376-1452)

- `habitParts(habit)`: null if `type === "timer"` or the name has no `|`. Otherwise `name.split("|")`, trimmed, empties removed; valid only if **2 ≤ count ≤ 4**, else null (a name with 5+ parts or only one non-empty part is a plain name).
- Storage: `done[K]` = sorted array of part indices (e.g. `[0,2]`); legacy/“all” = `1`. An empty array is **never** stored — the key is deleted.
- `donePartsOn(habit, K)`: no value → `[]`; array → itself; `1` → all indices of current parts (or `[0]` if the habit currently has no valid parts).
- The day counts as done (streaks, stats, calendar, badge, week dots) when **any** part is done (non-empty array is truthy). There is no "all parts required" rule anywhere.
- Tap logic on the round button (`countPartTap`, l.1437): taps are counted within a **320 ms** window (`PART_TAP_MS`); each tap restarts the window; the part index = `min(tapCount, parts.count) - 1` (extra taps clamp to the last part). When the window closes → `togglePart(idx)`. Counter is per habit (tapping another habit's button discards the pending count).
- `togglePart(habit, idx)` (today only): remove today's skip; `before = donePartsOn(today)`; toggle idx in the set (kept sorted); empty → delete `done[today]`, else store the array. Celebration only if before was empty and after is non-empty. Toast `"{part name} done|cleared"` with Undo (restores the previous array, or deletes the key). Tapping a part chip on the card toggles that part directly.
- Long-press (500 ms) on the round button = open the parts sheet for **yesterday** (instead of "mark yesterday done"). Tapping a calendar day of a parts habit also opens the parts sheet (no done→skip→empty cycle).
- Parts sheet save (`closePartsSheet`, l.2024): chosen set non-empty → `done[K] = sorted array`, delete `skip[K]`, toast `"a, b saved"`; empty selection → delete both `done[K]` and `skip[K]` ("Day cleared"); "Skip day" button → delete `done[K]`, `skip[K]=1` ("Marked as a skip day"). Each has Undo (exact snapshot of done+skip for that day). Backfills never celebrate.
- Swipe right on a parts card = "did the whole set": if already all parts done → toast "Already done today"; else remove today's skip, `done[today] = 1`; message "All parts marked done" (Undo restores previous array/deletion + skip). Celebrates only when no part was done before.
- CSV: column `parts` lists the part names of that day, joined `", "`, only for parts habits on done days.

---------------------------------------------------------------------
## 5. Fasting

### 5.1 Start / stop / edit
- Today card round button toggles: running → `endFast`, else `startFast` (l.1489). Fasting card has no long-press.
- `startFast(habit, goalH, at, msg)` (l.1514): push `{s: at||now, e: null}` (+`g` only if goalH given — the UI passes null); re-sort sessions by `s`; toast `"Fast started"` (or custom) with Undo = remove that session.
- `endFast(habit, active, at, msg)` (l.1498): `active.e = at||now`; toast `"Fast ended — H:MM h"` with Undo = `e = null`; then personal-best check (3.7). **No length cap on stopping** (a >48h session can result; the edit sheet will then refuse to save it unless fixed).
- Swipe right on idle fasting card = open the record-a-fast hours sheet for today (2.6); on a running fast = stop it. Swipe left on a timer: "A fast is running — stop it first" if running, else mark today skip. Skip rules in 7.5.
- Edit fast sheet (l.2757-2825): shows start (and end if finished). Save validation, in order: start valid ("Please enter a valid start time."), start not in the future ("The start can't be in the future."); if finished: end valid, `end > start` ("The end must be after the start."), `end - start <= 48h` ("A fast can be at most 48 hours."), `end <= now + 60 s` ("The end can't be in the future."). A running fast's start can be edited, no other check. Re-sort by `s`. Delete removes the session (toast "Fast deleted" / "Running fast deleted", Undo re-inserts + re-sorts). No overlap checks anywhere.
- History calendar tap on a day (timer): not done + has skip → remove skip; done → open editor for the LAST session (array order) that ends that day (never destructive); otherwise open the hours sheet for that day. Hours-sheet "Skip day" button sets `skip[K]=1`.

### 5.2 Today card for a timer habit (l.636-829, 677-688)
Let `active = activeSession`, `goalMs = goalMsFor(habit, active)`.

**Running:**
- Big number = `fmtDuration(now - active.s)`.
- Label (first matching branch):
  1. `elapsed > 24h` → "still fasting? / tap timer to fix" (overlong; amber classes). **Wins over goal reached.**
  2. `goalMs && elapsed >= goalMs` → "goal reached".
  3. `goalMs` → two lines: `"{H:MM of goalMs-elapsed} left"` and `"goal HH:MM"` where HH:MM = local clock of `active.s + goalMs` (24-h, zero-padded).
  4. else "fasting".
- Ring (only when `active && goalMs`): `progress = min(1, (now - s)/goalMs)`; colour **red `#d9463e` if progress < 1/3, yellow `#e0a80f` if < 2/3, else green `#2fa96d`**; stroke grows with progress (full circle at 1). It is still drawn after 24h.
- Tapping the number opens the edit sheet for the running fast.

**Idle:**
- `last = lastFinishedSession` (array order), `sinceEnd = now - last.e`.
- `nextGoal = last ? goalHoursOn(habit, addDays(Date(last.e), 1)) : null` (the next fast ends the day after the last one did; `session.g` ignored).
- If `last && nextGoal && sinceEnd < 24h`: number = `fmtDuration(sinceEnd)`; `nextStart = last.e + max(0, 24 - nextGoal)*3600000`; label "eating" + second line: if `nextStart > now` → **`"until HH:MM"`** (clock of nextStart) else **`"time to fast"`**. (Reads "6:22 eating, until 19:01".)
- Else if `last`: number = `fmtDuration(last.e - last.s)`, label "last fast".
- Else (no fasts): play icon, label "tap to start".
- With a recorded last fast, tapping the number opens that fast's editor.

### 5.3 Fasting stages (l.2565, 2572)
```
0–4h   Digestion    "the body is still processing the last meal"  #d9463e
4–12h  Settling in  "blood sugar and insulin drift down"           #e0a80f
12–16h Fat burning  "the body leans on its fat stores"             #7bc496
16–20h Deep fast    "ketosis territory for many people"            #2fa96d  (16h+ = still Deep fast)
```
Current stage = the last stage whose `from <= elapsedHours` (so ≥16h = Deep fast). Track is 0–20 h, marker clamped at 20h. Labels 0h 4h 12h 16h "20h+". Text "Now: {stage} · H:MM h". Hint: "A popular approximation from fasting literature — every body is different. Not medical advice."

### 5.4 Fasting calendar circle (l.1758-1776)
For past days and today (non-future) of a timer habit, in this order:
1. day is done (a fast ended on it): hours = `round(ms[K]/3600000)` (sum of all fasts ending that day); class **met** if `met[K]` (2.4; also met when no goal), else **under** ("fell short").
2. else today **and** a fast is running: hours = `round((now - active.s)/3600000)`, class **running**.
3. else skip day: "–" (skip-day style, habit colour).
4. else empty circle.
Future days: skip-marked → "–" (tap removes the skip); else disabled. Months navigable up to 12 months ahead (`next` disabled when shown month ≥ current month + 12). Legend: goal met / fell short / running / skip day.

### 5.5 Fast statistics ("Fasts" card, l.2640-2705)
Over `finished = sessions with e`: Average = `fmtDuration(mean(e-s)) + " h"`; Longest = max; "Goal met" = number of DAYS in `fastDayStats.met` (`"N day(s)"`); "Total fasts" = count. Recent list = last 10 finished (array order) newest first; running fast listed first as "In progress — started {weekday, HH:MM}". Bar chart: last 30 finished (needs ≥ 2); bar height = `max(3, v/maxV*plotH)`, `maxV = max(all durations, habit.goalHours*3600000 or 0) * 1.12`; dashed goal line only from `habit.goalHours` (not per weekday), label "goal {goalHours}h".

### 5.6 Fasting rhythm insights (`fastRhythm`, l.4148; card l.4177)
- Only when **≥ 5 finished fasts**; otherwise no card.
- `startMin` = **circular mean** of start clock times: for each session `a = (hour*60+minute)/1440*2π`; sum cos/sin; `frac = atan2(Σsin, Σcos)/(2π)`, `+1` if negative; `startMin = round(frac*1440) % 1440` → shown `HH:MM` as "usual start".
- `avgByDay[0..6]` = mean duration of fasts grouped by **weekday of the END day** (Mon=0), null where no fast. `avgAll` = mean of all.
- Tiles: "usual start" `HH:MM`; "strongest day" = short weekday name of the highest `avgByDay` (first one wins ties; "–" if none); "avg fast" = `fmtDuration(avgAll) + "h"`.
- Bars per weekday Mon→Sun: label hours with one decimal and a **decimal comma** (`7,5`) (empty for null); bar height fraction = `max(0.06, v/max)`; null weekdays show a dim 4 px stub.

### 5.7 Week/month fast figures
- `weekFastStats(habit, ws)`: finished fasts whose `e` is in `[ws, ws+7 days)`: `{n, avg}`. `monthFastStats(y,m)`: fasts with `e` in the month.
- Row text: `"{n} fast(s) · Ø H:MM h"` or `"no fasts"`. Delta vs previous period average (only if both exist): `(d<0 ? "–" : "+") + fmtDuration(|d|)`; colour class up/down/flat (flat only if exactly 0, text still "+0:00").

### 5.8 Fast notes (what-to-try) — see 7.4 (timer part).

---------------------------------------------------------------------
## 6. Siri / Home Screen menu hand-off (v1.51)

### 6.1 Target habit
`fastingHabit()` (l.5555) = **first habit in array order with `type === "timer"` and not archived**, else none.

### 6.2 Queue (Fasting.swift)
UserDefaults keys: `ams.fasting.status` (JSON `Status {habit:String?, since:Double? (ms of running fast start or nil), goalH:Double? (running fast's goal hours), goalHours:Double?, goalByDay:[Double?]? Mon-first}`) and `ams.fasting.pending` (JSON `[Step {a:"start"|"stop", t: ms, src:"siri"|"menu"}]`). Queue capped at 50 (oldest dropped). The page pushes the status on every save (`mirrorFastingStatus`, l.5616, only when the JSON changed; `goalH = goalMsFor(running)/3600000`; `goalByDay` entries invalid → null). `takePending()` returns and clears the queue; the page calls it at launch, on return to foreground, and on the native "pending" event; steps are **sorted ascending by `t`** and applied in order.
Home-screen quick action: no fasting habit → none; running → "Stop Fasting" subtitle "Since {short time}"; else "Start Fasting". Siri phrases: "Start fasting in Tracking" etc. (see Fasting.swift l.229-243).
`effective()` (Swift, replays the queue over `status.since`): `start` sets `since = t` only if `since == nil`; `stop` clears `since` only if `t > since`.

### 6.3 `applyFastAction(action, at, src)` (l.5564) — rules
- `habit = fastingHabit()`; `now`; `t = min(at || now, now)`; `bySiri = (src == "siri" && now - t > 60 s)` (asked while the app was closed ⇒ **suppress "ignored" toasts and use special wording**).
- No fasting habit: toast "No fasting habit found" (suppressed if bySiri), return false.
- `action == "toggle"` → `active ? "stop" : "start"` (used by the `?fast=toggle` web link).
- **start**: if a fast is already running → ignored; toast `"Already fasting — H:MM h"` (suppressed if bySiri); false. Else `startFast(habit, null, t, bySiri ? "Siri: fast started at HH:MM" : default)`. The new session starts at `t` (Siri's time), no `g`.
- **stop**: if no running fast **or `t <= active.s`** → ignored; toast "No fast is running" (suppressed if bySiri). Else `endFast(habit, active, t, bySiri ? "Siri: fast ended at HH:MM — H:MM h" : default)` (personal-best check still runs).
- Unknown action → false. `?fast=start|stop|toggle` URL uses `at = now`, `src="link"`.
- Siri's own spoken answers (computed natively at once): not opened yet → "Open Tracking once, then try again."; no habit → "Tracking has no fasting habit."; start while running → "You are already fasting, since {clock} — {h/min}."; stop with none → "No fast is running."; start → "Fast started at {clock}." + " Goal {g} h, until {clock}." if a goal exists; stop → "Fast ended after {X h Y min}." + " Goal of {g} h met." / " Goal was {g} h.". Native goal for Siri = running fast's `goalH` from the page if it is the page's running fast, else `goalByDay[weekday of expected end day]` (start hour >= 12 → next day), else `goalHours`.

---------------------------------------------------------------------
## 7. Other behaviour and screens

### 7.1 Daily / weekly Today card & basic actions
- Tap round button: parts habit → tap counting (4); otherwise `toggleToday`: removes today's skip, toggles `done[today]` (`1` / delete), celebrates if now done. Long-press 500 ms (non-timer): `markYesterday` — if `done[yesterday]` truthy → toast "Yesterday is already done"; else remove yesterday's skip, set `done = 1`, toast "Yesterday marked done" (Undo restores done+skip). Never celebrates.
- Daily card number = `currentStreak` ("day"/"days"); weekly card number = `"{count}/{target}"` of this week (`target-met` styling when `count >= target`), label "this week", sub line `"{weeklyStreak} week(s)"`.
- Week dots Mon→Sun of the current week: scheduled? (`!isScheduled` → off-day), done → filled, else skip → dashed. Tap = open that day in the habit's calendar.
- Swipe (threshold 72 px): right = done today (`swipeDone`): if `doneSet[today]` → "Already done today"; timer (running → stop; idle → hours sheet); else remove skip, `done[today]=1`, toast "Marked done" (Undo restores done + skip), celebrates. Left = skip today (`swipeSkip`): done today → "Already done today — nothing to skip"; already skip → "Today is already a skip day"; timer running → "A fast is running — stop it first"; else `skip[today]=1`, toast "Today marked as skip day" (Undo).
- Long-press 450 ms on the card body then drag = reorder (`state.habits` becomes visible order + archived habits kept at the END in their old relative order; toast "Habits reordered" with Undo = previous order).
- History calendar day tap cycle (non-timer, non-parts), `toggleHistoryDay` l.1936: done → skip (delete done, set skip); skip → empty; empty → done. Today ring outline. Future days: only already skip-marked future days are tappable (removes the skip); empty future days disabled. Note mode: tap writes a day note.
- Day note: trimmed, `slice(0,200)`; empty text deletes the note. Delete habit: confirm `Delete “{name}” and all of its history? This cannot be undone.`; removes it from `state.habits` (aspirations untouched). Archive: `archived = true` (toast with Undo = `archived=false`); Settings › Archived list has Restore (`archived=false`).
- Vacation range (l.1896): from/to days (to >= from, **max 92 days**); targets = this habit or (checkbox, default ON when more than one active habit) all non-archived habits; for every day in range: days that are already done or already skip are left alone, others get `skip=1`. Undo removes exactly the newly added skips. Toasts "N day(s) skipped" / "N days skipped for M habits".
- Edit habit: type can be switched daily⇄weekly (history untouched, `habit.target = sheet.target` for weekly else null); timer type can neither be entered nor left. Weekly target options 1…7; default when a daily is switched = number of scheduled days (min 1), new habit default 3. Goal fields saved only for timer.
- Year card (current year): weekly → "Current streak N week(s)", "Longest streak", "Weeks met X of Y" (weeklyStats); others → "Current streak", "Longest streak", "Completion {pct}% ({done} of {total} days)". Other years: "Days completed {done} of {scheduled non-skip days up to today}".
- Aspirations are attached from either side (habit.aspirationId ⇄ aspiration sheet). Saving an aspiration: habits chosen get `aspirationId = id`; habits previously under it but unticked get `null`.

### 7.2 Stats screen (`renderStats`, l.4292)
Per non-archived habit (in order), a card with 4 tiles:
`streak` = `weeklyStreak`/`currentStreak`, `best` = `weeklyStats.best`/`longestStreak` (unit suffix `wk` for weekly else `d`), `this month`, `last month`:
- `monthStats(habit, y, m)` (l.4124): `start = max(first of month, tracked-from)` where tracked-from = `min(createdAt, earliest done day)`; `end = min(last day of month, today)`; for each day: `dn++` if done; `sched++` if scheduled and not skip. `pct = sched ? round(100*dn/sched) : 0`.
- Tile value: weekly → `"{dn}×"`; else `sched ? "{pct}%" : "–"`.
Then the record nudge (3.5), then a 30-day strip (today and the 29 before, oldest first: done = filled, skip = dashed, else empty). Tapping the card opens the habit detail.
After the habit cards: a rhythm card for every non-archived timer habit that has ≥5 finished fasts (5.6), then the Achievements card (below). With no active habits: text "No habits yet."
**Achievements** (l.4230): tiles "days tracked" = Σ over non-archived habits of the number of done days (`doneSet` size; timer = days a fast ended on), "best streak" = max `longestStreak` over non-weekly habits shown as `"{n}d"`, "longest fast" = longest session `e-s` over all non-archived habits `"H:MMh"` or "–". Then per habit the milestone chips (3.6).

### 7.3 "Last week" screen (`renderNotes` l.3858) and the week report
Week reported = `ws = weekStart(today) - 7 days` (the Monday of the week that just ended). Subtitle "D Mon – D Mon".

`weekReport(ws)` (l.1242) — habits included: non-archived AND (`!createdAt` OR `createdAt <= ws`), i.e. **existed for the whole week**. Per habit row `days[0..6]` state, precedence: `done` > `skip` > `off` (not scheduled) > `empty`.
- timer: `mid = "{n} fast(s) · Ø H:MM h"` / "no fasts"; `met = null` (not judged); delta = avg vs previous week (5.7).
- weekly: `count = weekDoneCount`, `mid = "{count}/{target}×"`, `met = count >= target`; `deltaValue = weeklyStreak(h, ws+6d) - weeklyStreak(h, ws-1d)`; `unit = week`.
- daily: `dn` = done days that week (any day), `sched` = scheduled and not skip days; `mid = "{dn}/{sched} days"`; `met = sched > 0 && dn >= sched`; `deltaValue = currentStreak(h, ws+6d) - currentStreak(h, ws-1d)`.
- delta text for deltaValue: `v<0 ? "–" : v>0 ? "+" : "±"` + |v|; class up/down/flat.
- Totals: `judged` = rows with `met !== null`, `met` = count of rows met, `ticks` = number of `done` day marks in all rows.
Screen sections, in order:
1. Chart "Habits completed each day": `perDay[i]` = number of rows with `done` on weekday i; `ceiling = max(rows.count,1)`; bar height % = `round(n/ceiling*100)`. Caption: total 0 → "Nothing was ticked last week."; else `"{total} in all, out of {ceiling} habits a day. {DayName} carried the most, with {perDay[best]} of {ceiling}."` (best = first max).
2. Headline: `judged ? "{met}/{judged}" + (judged==1 ? "habit on target" : "habits on target") : "{ticks}" + ("day ticked"|"days ticked")`. Then one row per habit (icon, name, mid, delta, 7 day marks).
3. "The week in words" (summary paragraphs, 7.4) with two share buttons (text / picture). Empty text: if there is any non-archived habit → "Nothing to summarise yet. Everything you track began during or after last week, so there is no complete week to report on — there will be on Monday." else "Nothing to summarise yet. Add a habit and give it a week."
4. "Your aspirations": per live aspiration `"{ran}/{total}"` (or "—"), text `"{ran} of {total} habit(s) ran last week"` + `", {met} of {judged} did what it|they asked"` (if judged>0) or "No habits under this yet"; plus "Quiet for N weeks. Is it still true?" when quiet >= 3.
5. "How it went" = `lastWeekNotes()`; 6. "What to try next week" = `weekNotes()` (empty text: "Nothing worth saying yet. A weekday pattern needs a few weeks before it is a pattern rather than a coincidence, and a confident sentence about a coincidence would be worse than this one."); 7. "Something new?" = `habitSuggestions(3)`.
Opening this screen "marks seen" aspiration nudges (see 7.6).

**Week summary paragraphs** (`weekSummaryParagraphs`, l.3418) — returns [] if no report rows:
1. `"Between {D Month} and {D Month} you ticked {ticks} day(s) across {rows} habit(s). {clauses joined as proseList}."` + (if judged>0): all met → ` Everything with a target made it.`; 0 met → ` Nothing with a target made it, which is worth a moment rather than a shrug.`; else ` That is {met} of {judged} targets met.`
   Clauses: timer → `"{n} recorded {k} fast(s) averaging {H:MM}"` / `"{n} recorded nothing"`; weekly → `"{n} reached {c} of {t}"` / `"{n} came up short at {c} of {t}"`; daily → `"{n} had nothing scheduled"` (sched=0), `"{n} ran every one of its {sched} days"` (dn>=sched) else `"{n} ran {dn} of {sched} days"`. `proseList`: "a", "a and b", "a, b and c".
2. If any live aspiration has habits: per aspiration `Towards “{title}”, {ran} of {total} habit(s) ran` + (quiet>=3: ` — nothing has under it for {quiet} weeks now`) + `.` ; all joined by a space.
3. If `lastWeekNotes()` non-empty: their `text`s joined by space.
4. `notes = weekNotes().slice(0,2)`: if non-empty → `"Looking further back than one week: "` + each note: `body` if the note has a habit and the body contains the habit's name, else `"{title}. {body}"`, joined by space; else if `lastWeekNotes()` was empty → "There is not enough history yet to say anything about patterns. A weekday that costs you, or a run you tend to break, needs several weeks before it is a pattern rather than a coincidence."
5. `habitSuggestions(1)[0]` if any: `If you wanted something new, “{name}” ({daily | N times a week}) is one to consider. {why}`.
Shared text = `"My week, {D Mon} – {D Mon}\n\n"` + paragraphs joined by blank lines.

### 7.4 Notes ("What to try next week") — exact rules
Constants: `NOTE_WEEKS = 8`, `NOTES_SHOWN = 3`. `ws` = Monday of the last completed week. `recentWeeks(ws,n)` = the n Mondays ending at `ws`, oldest first (includes `ws` itself).

**`weekdayMisses(habit, ws, n)`** (l.2894): over the 8 weeks, for each day: skip if after today, before `createdAt`, skip-marked, or not scheduled. `sched[wd]++`; `miss[wd]++` if not done. Returns miss/sched arrays + totals.
**`secondMissRate`** (l.2923): builds the sequence of done/not-done over only scheduled, non-skip days (not before `createdAt`) from the Monday 7 weeks before `ws` through today; `misses` = count of not-done items that have a following item; `doubles` = those whose next item is also not done; `rate = misses ? doubles/misses : null`.

**`weekNotes()`** (l.3077) builds candidates `{habit, score, topic, title, body}`; for non-archived habits that are not timers:
1. *Weekday that slips* — **daily only**, needs `totalMiss >= 5 && totalSched >= 12`; worst = weekday with the most misses (first on ties); `share = miss[worst]/totalMiss`; fires if `miss[worst] >= 3 && share >= 0.3 && sched[worst] >= 3`. score `3 + share`, topic `weekday`. Title `"{Day} is where {name} slips"`; body `"{miss[worst]} of your last {totalMiss} misses fell on a {Day}. Decide this week what {Day}'s version looks like — the shortest one that still counts — rather than deciding on the day."`
2. *Weekly: one short* — weekly only: over the 8 weeks `nearly` = weeks with `count == target-1`, `short` = weeks with `count < target`. If `nearly >= 2`: score 3.5, topic `weekly-target`, title `"{nearly} weeks ended one short"`, body `"{name} finished on {target-1} of {target} in {nearly} of the last 8 weeks. One more day in each and they would all have counted. Being at {max(target-2,1)} by Thursday is what buys room for a bad day at the weekend."`
3. *Weekly: the day that decides* — weekly, `short >= 3 && met(=8-short) >= 2`: per weekday count blank days in failed weeks (`blankShort`) and in met weeks (`blankMet`); `lift = blankShort/short - blankMet/met`; best = max lift (strictly greater, starts at 0, first wins ties). Fires if `bestLift >= 0.5 && blankShort[worst] >= 3`. score 3.8, topic `weekly-target`, title `"The weeks that fail have a {Day} in common"`, body `"{name} came up short {short} times, and {Day} was blank in {every one | N of them} — against {blankMet[worst]} of the {met} weeks you made the target. That is the day that decides it, whatever the rest of the week looks like."` ("every one" when `blankShort[worst] == short`).
4. *Recovery* — **daily only**, `sm.misses >= 6`: if `rate >= 0.5` → score 4, topic `recovery`, title `"With {name}, one miss usually becomes two"`, body `"{doubles} of your {misses} missed days were followed by another. That makes the day after a miss the most valuable day you have — do a token version of it rather than nothing, and the run survives."`; else if `rate <= 0.25` → score 2, title `"You come back well on {name}"`, body `"Only {doubles} of {misses} misses turned into two days off. That recovery is doing more for the total than any perfect week would — keep missing singly."`
Aspiration notes (all live aspirations, `aspirationCoverage(ws)`; each uses the nudge cooldown, 7.6):
5. `quiet >= 3 && nudgeAllowed("quiet:"+id)` → score 4.2, topic `aspiration`, habit = first habit under it or null, title `“{title}” has gone quiet`, body `"Nothing has run under it for {quiet} weeks. That is either a run of bad weeks or a sign it is no longer what you want. Both are worth knowing, and only you can say which."`; else if `total == 0 && nudgeAllowed("empty:"+id)` → score 3.9, title `“{title}” has no habits under it`, body `"Nothing is being tracked towards it, so nothing can be said about it week to week. Edit a habit and use Serves, or let this one go."`
6. If at least one live aspiration exists and `unattachedHabits()` non-empty and `nudgeAllowed("loose")` → score 2.4, topic `aspiration`, habit = first loose, title `"{name} serves nothing"` (1) or `"{N} habits serve nothing"`, body `"It is|They are tracked but not attached to any aspiration. That is a perfectly good answer — not everything has to ladder up to something. It is only worth saying once."`
Timer habits (non-archived): `sess` = finished fasts; `recent` = those with `e >= ws - 7*7 days` (start of the 8-week window, `addDays(ws, -49)` at midnight). Needs `recent.length >= 6`:
7. If `goalHours` set: `avg` = mean duration; `gap = goalMs - avg`. `gap >= 20 min` → score 3, topic `fast-length`, title `"Your fasts average {H:MM} against a {goalHours}h goal"`, body `"Over {n} fasts you are {H:MM of gap} short on average. That is usually the stop time rather than the start — a fixed hour to eat is easier to hold than a fixed length."`; `gap <= -20 min` → score 2, title `"You are running past your {goalHours}h goal"`, body `"{n} fasts averaged {H:MM}. Either the goal is set lower than what you actually do, or the extra is unplanned — worth deciding which."` (uses `habit.goalHours` only, not per-weekday).
8. Start drift: `half = floor(n/2)`; sessions sorted by `e` ascending; `early = meanStartMin(first half)`, `late = meanStartMin(second half incl. middle one when odd)` (circular mean as 5.6); `diff = late-early` wrapped into [-720, 720]; if `|diff| >= 25` → score 2.6, topic `fast-drift`, title `"You have been starting {|diff|} minutes {later|earlier}"`, body `"The first half of these {n} fasts began around {HH:MM}, the second half around {HH:MM}. "` + later: `"A later start pushes the whole rhythm, and the hour you eat is the easier end to fix."` / earlier: `"Whatever changed is working in your favour — it is worth knowing what it was."`
**Selection** (l.3299-3326): sort by score descending (stable); drop duplicates with the same key `(aspiration id | habit id | "") + "|" + topic` (keep the first/highest); then take up to 3, first pass only one note per owner (aspiration id / habit id / ""), second pass fills remaining slots (up to 3) with further notes of already-covered habits in order.

**`lastWeekNotes()`** (l.2969) — about ONE week vs the previous 8; non-archived non-timer habits only; max **2** results, sorted by score desc, one per habit.
`prior` = the 8 weeks before `ws`, skipping weeks that end before `createdAt` (`ws' +6 < createdAt`); if `prior.length < 3` → no note.
- Weekly habit (`count = weekDoneCount(ws)`, `target`):
  - met (`count >= target`): `since` = number of leading prior weeks (nearest first) that did NOT meet; if `since >= prior.length` → score 4 `"{name} made {target} for the first time in {prior.length} weeks — {count} of {target}."`; else `since >= 2` → score 3.5 `"{name} hit {target} again after {since} weeks of not quite getting there."`; else `run` = 1 + consecutive met prior weeks; `run >= 3` → score 2.8 `"{run} weeks in a row at {target} or better for {name}. That is the run to protect."`
  - not met: `run` = consecutive met prior weeks (nearest first); `run >= 2` → score 3.6 `"{name} ended on {count} of {target}, after {run} weeks that made it. One week is not a trend — the week after a broken run is the one that decides."`
- Daily habit: weekly rate = `dn/sched` (sched = scheduled, non-skip days; weeks with sched=0 dropped); if last week `sched == 0` → none; need `rates.length >= 3` over prior weeks; `rate = dn/sched`, `best = max(rates)`, `avg = mean(rates)`:
  - `rate > best` → score 4 `"{dn} of {sched} on {name} — better than any of the last {rates.length} weeks."`
  - else `rate <= avg - 0.25` → score 3.4 `"{name} ran {dn} of {sched}, against {round(avg*100)}% usually. Worth a thought about what was different, before it settles in."`
  - else `rate == 1 && sched >= 5`: `run` = 1 + consecutive prior weeks with `sched>0 && dn==sched`; `run >= 2` → score 2.6 `"{run} clean weeks in a row on {name}."`

**Habit suggestions** (l.3337-3380): the fixed list `SUGGESTED_HABITS` (12 entries: Walk 30 minutes/shoe/daily, Strength/dumbbell/weekly 2, Mobility 10 min/leaf/daily, Lights out by 22:30/bed/daily, No phone after 21:00/phoneOff/daily, Read 20 minutes/book/daily, Water, 2 litres/glass/daily, Breathing, 5 minutes/waves/daily, Three lines in a journal/pen/daily, Weigh in/pulse/weekly 1, Time outdoors/mountain/daily, Call someone/chat/weekly 1; each with a `match` keyword string and a `why` sentence — copy them from l.3337-3362). A suggestion is dropped when any word (split by whitespace of `match + " " + lowercase name`) longer than 3 chars is a substring of any existing habit name (lowercased, ALL habits incl. archived). The shelf rotates: `week = floor(weekStart(today).timeMs / (7*86400000))`; picks `free[(week+i) % free.length]` for `i < min(count, free.length)`. "Add this habit" opens the new-habit sheet prefilled (type, icon, target, name); nothing is created until saved.

### 7.5 Aspirations (l.1113-1220, 3665-3854)
- `habitsUnder(id)` = non-archived habits with that `aspirationId`. `unattachedHabits()` = non-archived habits whose aspiration is missing/archived/none.
- `habitActiveIn(habit, ws)` = at least one done day in the 7 days.
- `habitMetIn(habit, ws)`: timer → null (not judged); weekly → `count >= target`; daily → `sched > 0 && dn >= sched` (sched = scheduled, non-skip days).
- `silentWeeks(aspId, ws)`: 0 if it has no habits; else count weeks backwards from `ws` (i = 0 is `ws` itself, max 53) in which **no** habit under it was active, stopping at the first active week. **Quiet = silentWeeks >= 3.**
- `aspirationCoverage(ws)` per live aspiration: habits, `total`, `ran` (active that week), `judged` (habits with non-null met), `met`, `quiet`.
- **Nudge cooldown** (`NUDGE_COOLDOWN_WEEKS = 4`, l.1195): `nudgeAllowed(key)` = no entry, or `round((weekStart(today) - keyToDate(entry)) / 7 days) >= 4`. `markNudged(key)` sets `settings.aspNudges[key] = dateKey(weekStart(today))`. Keys: `"quiet:<id>"`, `"empty:<id>"`, `"loose"`. Marking happens when the "Last week" screen **renders the note** (not when the note is merely computed for the summary prose).
- Aspirations screen: per live aspiration card `"{ran}/{total}"` or "—", subtitle "N of M habit(s) ran last week"/"No habits under this yet", chips for its habits (ran ones highlighted), and "Nothing has run under this for N weeks. Is it still true?" at quiet >= 3; plus a "Not attached to anything" card (count) only when ≥1 live aspiration exists and ≥1 loose habit. Starter sentences for a blank new aspiration: "Strong and durable into my seventies", "Healthy enough to keep doing what I love", "Calm, rested and clear-headed", "Someone who finishes what he starts". Empty-state text "Nothing here yet. An aspiration is one sentence about who you are becoming — the thing your habits are actually for. Once you have one, every week says how many of its habits ran, and one that goes quiet gets asked about rather than left sitting there."
- Aspiration save requires a non-empty trimmed title.

### 7.6 Month review (l.3526-3658)
Screen "Last month": `lastMonthPeriod()` = previous calendar month (January → December of previous year). Title "{Month name} in review", subtitle year. Rows: non-archived habits with `!createdAt || createdAt < first of that month`. If none: "Nothing to review yet. Everything you track began during or after {Month}, so there is no complete month to report on."
Row content: timer → `"{n} fast(s) · Ø H:MM h"`/"no fasts" + delta vs month before; weekly → `"{dn}× checked off"` (`monthStats.dn`) + delta `±/+/–` N`×` vs previous month; daily → `"{dn}/{sched} days"` (monthStats) and `best` = `bestRunInMonth` shown as the flame number plus sub text `"Longest run of the month: N day(s)."`. `bestRunInMonth`: longest consecutive-done run inside that month over scheduled days up to min(month end, today); skip excused; unscheduled ignored.
Chart "Ticks in each week of {Month}": up to 6 Monday-first calendar weeks overlapping the month; each bar = total done days of all listed habits (`doneSet`) on days inside that month only; label under the bar = day-of-month the week began (1st of month for a partial first week is the Monday's date number as in the code: `w.start.getDate()` of the Monday). Bar % = `round(n/max(1,maxN)*100)`. Caption: total 0 → "Nothing was ticked in {Month}."; else `"{total} in all. The week of {D Month} was the strongest, with {n}. Numbers under the bars are the day each week began."` (strongest = first max).

### 7.7 Backup nudge (l.4804)
Runs once, 2.5 s after launch. Shows only if the user has data (some habit has ≥1 done day (`doneSet`) or ≥1 session), AND `now - settings.lastBackup (default 0) >= 30 days` AND `now - settings.lastBackupNudge (default 0) >= 30 days`. Then `lastBackupNudge = now`, save, toast (12 s) with a "Back up" button that triggers export: `"Last backup: {days} days ago"` (days = floor((now-lastBackup)/86400000), only when lastBackup exists and days > 0) else `"No backup yet — your data lives only on this phone"`. (30 days = `30*86400000` ms exactly.)
Settings note (`updateBackupNote`): none → "No backup yet." (stale style if data); 0 days → "Last backup: today."; 1 → "Last backup: yesterday."; else "Last backup: N days ago." (stale style if N > 30).

### 7.8 App-icon badge and daily reminder
- **Badge** (l.198-216): active only if badges supported, notification permission granted and `settings.badge === true` (else the badge is cleared). Count = non-archived habits that are `isScheduled(today)` and neither done nor skip today, excluding timer habits with a running fast. 0 clears the badge. Recomputed on every save. (Weekly and timer habits count as scheduled every day.)
- **Reminder** (settings.reminder.{on,time}, default time `"20:00"`; native, l.5314-5355): on every save/launch/foreground, cancel ids 4400…4429 and, if `on` and permission granted, plan the next **30 days**: for day i (0…29) at `time` local: skip if that moment `<= now + 5 s`; `s = summarizeDay(thatDay)`; skip the day if `s.open` is empty; schedule id `4400+i`, title `"AMS Tracking"`, body `reminderBody(s)`. Replanning is debounced 400 ms.
  `summarizeDay(when)` (l.5218): over non-archived habits scheduled on `when` (`isScheduled`): `total++`; a habit is **open** (name listed in array order) unless done or skip-marked that day, or (for today only) a timer with a running fast. For future days nothing is ticked yet, so all scheduled non-skip-marked habits are open.
  `reminderBody`: 1 open → `"Still open: {name}"`; >1 → `"{N} still open: {names joined ", "}"`; 0 open → `"Time to fill in your tracked items."` (never scheduled since empty days are skipped).
  If permission is revoked: `on=false`, `lostPermission = (state is denied)`. Imported `on:true` without permission is switched off. Time change in native mode simply re-plans (toast "Reminder moved to HH:MM"); enabling toast "Reminder on — every day at HH:MM".

### 7.9 Other settings behaviour
Safety copy (native): after each save, whole `localStorage` JSON text is written (debounced 600 ms; immediate when the app goes to background) to `Library/amsTracking.v1.json`; at start, if storage is empty and the file exists and has a `habits` array, it is restored. (In Swift this is the primary store — keep a safe copy.) Theme/layout labels "Theme: auto|light|dark", "Layout: list|grid".

---------------------------------------------------------------------
## 8. CSV export and fasting-history import

### 8.1 CSV export (`exportCsv`, l.4860)
Two files, semicolon-separated, decimal commas (DACH Excel), no BOM, lines joined with `\n`, no trailing newline, UTF-8. Names: `ams-tracking-days-YYYY-MM-DD.csv`, `ams-tracking-fasts-YYYY-MM-DD.csv` (today's dateKey). Shared together via the share sheet (or two downloads); toast "CSV exported".
`csvField(v)`: `String(v)`; if it contains `"`, `;` or newline → wrapped in `"` with inner `"` doubled; else as is.
**days file**: header `date;habit;type;status;parts;note`. For EVERY habit in `state.habits` (archived included, array order): keys = sorted union of `Object.keys(doneSet)`, `Object.keys(skip)`, `Object.keys(notes)`; per key one row: `K ; csvField(name) ; type ; status ; csvField(partsText) ; csvField(note)` where `status` = `done` if done, else `skip` if skip, else empty (a note-only day); `partsText` = for parts habits on done days: part names of `donePartsOn` joined `", "`, else empty. (Timer habits: `done` = end days.)
**fasts file**: header `habit;start;end;hours`. For every habit, every session with an `e` (array order): `csvField(name) ; "YYYY-MM-DD HH:mm" (local start) ; "YYYY-MM-DD HH:mm" (local end) ; hours` with `hours = ((e-s)/3600000).toFixed(2)` using **a comma** as decimal separator (e.g. `16,25`). Running fasts are omitted.

### 8.2 Fasting-history import (`parseHistoryText`, l.4910; sheet l.4967-5003)
Target = first non-archived timer habit (none → "No fasting habit to import into.", save disabled). Text is split by `\r?\n`; per line (trimmed; empty lines skipped):
1. **Header skip**: if the line matches `/date|start|habit|hours/i` and does **not** start with a digit → skipped (not counted unreadable).
2. Split: if the line contains `;` → by `;`; else if it contains a tab → by tab; else by `,`. Each field trimmed, **empty fields removed**.
3. Special case for the comma format with a decimal-comma hour: no `;`/tab in the line, exactly 3 parts, and parts[1], parts[2] are both 1-2 digit integers (`"2026-08-15,14,5"`) → parts become `[parts[0], parts[1] + "." + parts[2]]` (i.e. 14.5 hours).
4. Date-time parser `dt(v)`: regex `^(\d{4})-(\d{2})-(\d{2})[ T](\d{1,2}):(\d{2})` (local time; extra characters after the minutes are ignored), else null.
5. Recognised shapes, first match wins:
   a. `parts.length >= 3 && dt(parts[1]) && dt(parts[2])` → `{s: dt(parts[1]), e: dt(parts[2])}` (the exported fasts.csv row: habit;start;end;hours).
   b. `parts.length >= 2 && dt(parts[0]) && dt(parts[1])` → `{s,e}` (start;end).
   c. `parts.length >= 2 && parts[0] matches ^\d{4}-\d{2}-\d{2}$` → `h = parseFloat(parts[1] with "," → ".")`; valid if finite and 0<h<=48 → `e = noon (12:00) of that day`, `s = e - h*3600000`.
6. Accept the session only if `e > s`, `e - s <= 48 h` and `e <= now`; otherwise the line counts as `bad` ("unreadable line").
Preview: `existing` = `fastDayStats(habit).ms` keys (days where a fast already ends); `fresh` = sessions whose end-day is NOT in `existing`; `dupes = sessions.length - fresh.length`. Message `"Found N new fast(s)"` + `" · D already recorded"` + `" · B unreadable line(s)"` + `"."`; empty input shows nothing; Save disabled when no fresh.
Save: from `fresh`, keep only the **first** per end-day (so one fast per day), push to `habit.sessions` (no `g`), re-sort by `s`, toast `"{n} fast(s) imported"` with Undo (removes exactly those sessions).

---------------------------------------------------------------------
## 9. Quick reference of constants
- `DAY_MILESTONES [7,14,30,50,100,200,365,500,730,1000]`, `WEEK_MILESTONES [4,10,26,52,104]`.
- `NOTE_WEEKS 8`, `NOTES_SHOWN 3`, `NUDGE_COOLDOWN_WEEKS 4`, lastWeekNotes max 2, min 3 prior weeks.
- Streak walk caps: 3700 days (daily), 530 weeks (weekly). Silent-weeks cap 53.
- `PART_TAP_MS 320`; swipe trigger 72 px; long-press: yesterday 500 ms, drag-reorder 450 ms.
- Fast limits: edit/backfill/import max 48 h; overlong guard on card 24 h; end-in-future tolerance 60 s; Siri "asked while closed" threshold 60 s.
- Ring thirds: `< 1/3` red `#d9463e`, `< 2/3` yellow `#e0a80f`, else green `#2fa96d`.
- Skip range max 92 days; note max 200 chars; backup nudge 30 days; reminder default 20:00; native reminder window 30 days, ids 4400–4429.
- Calendar can be browsed up to 12 months ahead.

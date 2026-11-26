# AMS Tracking — screen-by-screen spec for the native SwiftUI rebuild

Source (read only): `/Users/martinschabbauer/Documents/01 Leisure/30 App Development/AMS Tracking`
(`index.html`, `css/style.css`, `js/app.js` v1.51, `js/icons.js`). Line numbers below are `js/app.js` unless named.
The web app is one page with six "screens" (Today, Detail, Stats, Last week, Last month, Aspirations) and a stack of bottom sheets. All text is English. Dates use the device locale (`toLocaleDateString`); times are 24 h.

---------------------------------------------------------------------------
## 0. Foundations

### 0.1 Sizing
- Root font = iOS "body" = **17 pt**; every size below is `rem` x 17 (so 1 rem = 17 pt, 0.8824 rem = 15 pt, 0.7647 rem = 13 pt, 0.5294 rem = 9 pt). The whole app follows Dynamic Type. In SwiftUI: use text styles / `@ScaledMetric` with 17 as base.
- Screen content max width 560 pt, centred; side padding 16; top padding = safe area + 12; bottom padding = safe area + 40 (Today: safe area + 104 to clear the floating bar).
- Fonts: system (SF). Weights used: 500/600/700/800 (800 for numbers and titles), tabular digits for numbers.
- Page title (`.page-title`): 40 pt (2.3529 rem) weight 800, letter-spacing -0.5, margin 6 top / 4 side. Subtitle: 15 pt (0.8824 rem) weight 500, dim colour, margin 2 top 18 bottom.
- Corner radii: habit card 20; detail card 22; list button 14; note card 16; lw chart/hero 18; sheet top corners 24; chips 12 (pill chips 999); calendar day 12; pixel 4; primary/ghost buttons 16.
- Screen transitions: deeper screens push in from the right (translateX 64 -> 0, 0.24 s), going back to Today slides in from the left. Sheets slide up (40 pt, 0.22 s) and are dragged down to close (threshold 90 pt) - native `.sheet` with detents does this.

### 0.2 Colours
**Habit palette (exact, in this order; new habit gets `PALETTE[habits.count % 8]`):**
| # | name | hex |
|---|------|-----|
| 1 | blue | `#3b70f0` |
| 2 | pink | `#e0447c` |
| 3 | green | `#2fa96d` |
| 4 | orange | `#ee8b2c` |
| 5 | red | `#d9463e` |
| 6 | purple | `#7a5af8` |
| 7 | teal | `#2aa8c4` |
| 8 | yellow | `#c9a227` |

**Theme tokens** (Settings > Theme cycles auto -> light -> dark; "auto" follows the system):
| token | light | dark | use |
|---|---|---|---|
| bg | `#f2f4f8` | `#0d1117` | page / sheet background |
| surface (= card-fallback) | `#ffffff` | `#161b26` | cards, list buttons, chips, calendar sheet |
| text | `#16181d` | `#eceef2` | primary text |
| text-dim | `#656d7a` | `#8d93a1` | labels, hints, empty dots text |
| border | black 7 % | white 8 % | empty pixels, empty calendar days, tracks, week-dot background, dividers |
| shadow | `0 2 10 rgba(20,30,60,.06)` | `0 2 10 rgba(0,0,0,.35)` | all cards |
| danger | `#e5484d` | same | Delete, destructive text |
| accent (blue, "buttons, links, Update") | `#3b70f0` | same | primary button fill, selected chip border, links, "Undo" in toast (light mode toast uses `#7ea4f7`, dark `#2c5fd8` because the toast is inverted) |
| stale (amber text) | `#7a5b06` | `#e0a80f` | backup older than 30 days / "No backup yet." (if data), aspiration "Is it still true?", |
| chart-ink (week/month bars) | `#24925c` | `#2fa96d` | bar fill in Last week / Last month charts |
| toast bg / fg | = text / = bg (inverted) | | |
| bottom-bar / celebrate card | = surface | | |

**Card tints (Today card background):** `color-mix(in oklab, <habitColor> 17 %, <surface>)` — i.e. 17 % habit colour blended into white (light) / `#161b26` (dark) in **OKLab** (not sRGB: sRGB washes purples out). The Add/Edit live-preview card uses 10 % instead of 17 %. SwiftUI: build with `Color.mix(with:by:in:.perceptual)` (iOS 18) or convert to OKLab by hand.

**Fixed semantic colours (same in light/dark):**
- Done/target-met/goal-reached green `#2fa96d` (also "up" deltas, `.target-met` number, goal-reached number+label, swipe-right ring).
- Down delta / ring red phase / "running" calendar circle `#d9463e`.
- Warning amber `#e0a80f` (ring middle phase, over-24 h fast number+label, stage 2).
- Swipe-left ring colour = text-dim. Gold `#c9a227` = Achievements trophy + its three tile numbers.
- Fasting stages: Digestion `#d9463e`, Settling in `#e0a80f`, Fat burning `#7bc496` (light green), Deep fast `#2fa96d` (deep green).
- Ring track = border colour.
- Habit colour always means "that habit" (text, icon, done fills, dots). Blue accent never stands for a habit.

### 0.3 Icons
See section 9. Everything is drawn on a 24 x 24 grid, `stroke=currentColor`, `stroke-width 1.7`, `stroke-linecap/linejoin round`, `fill none` (a few shapes carry `fill`). Sizes: pill-button icon 21 pt; action-button icon 23 pt (grid 22); habit-name icon **32 pt** in list, **22 pt** in grid (+2 pt right margin); detail title icon 34 pt (27 pt for names 13-20 chars, 23 pt for > 20); stat flame 18 pt (+3 left margin), weekly sub-line flame 12 pt; chip icon 25 pt; type-picker icon 23 pt (accent colour); list-button icon 20 pt; empty-state sprout 64 pt accent; celebrate flame 52 pt.

### 0.4 Data model (needed to understand every screen) — `localStorage["amsTracking.v1"]`
```
state = { version:1, habits:[Habit], aspirations:[Asp], settings:{layout:'list'|'grid', theme:'auto'|'light'|'dark',
          badge?:bool, reminder?:{on,time,...}, lastBackup?:ms, lastBackupNudge?:ms, aspNudges?:{key:dateKey}} }
Habit = { id, name (<=40), icon (one of 40 names), color (hex), type:'daily'|'weekly'|'timer',
          days:[7 bools Mon-first] (daily only), target:1..7|null (weekly), goalHours:num|null, goalByDay:[7 num|null]|null (timer),
          createdAt:'YYYY-MM-DD', done:{ 'YYYY-MM-DD': 1 | [partIdx,...] }, skip:{ 'YYYY-MM-DD':1 }, notes:{ 'YYYY-MM-DD':text<=200 },
          sessions:[{s:ms, e:ms|null, g?:hours}] (timer; e=null = running fast), archived?:bool, aspirationId?:id|null, lastCelebrated?:'day7'|'week4'... }
Asp = { id, title (<=80), createdAt, archivedAt? }
```
Rules you must port exactly (functions at the given lines): `dateKey/keyToDate/addDays/weekdayIdx` (Mon=0) 243-258; `doneSet` 261 (timer: a day is done when a fast **ended** on it); `goalHoursOn/goalDayFor/goalMsFor` 275-294 (goal belongs to the day the fast ENDS; a running fast predicts: start >= 12:00 -> ends tomorrow); `isScheduled` 296; `weekDoneCount/weeklyStreak/weeklyStats` 306-366 (weeks Monday-first, current week counts once met but never breaks the streak, weeks with a skip are excused); `currentStreak/longestStreak/completionStats` 369-422 (today pending does not break streak; skip days neutral); `fastDayStats` 427; `fmtDuration` = `h:mm`; milestone lists 466-467.
First launch with no data seeds ONE habit: name "Intermittent Fasting", icon `moon`, colour `#7a5af8`, type timer, goalHours 16, all 7 days.
Multi-part habits: a non-timer habit whose name contains `|` and splits into 2-4 non-empty parts ("Medit | Brea | Cold") (`habitParts` 1383). `done[key]` then = array of part indices; legacy `1` = all parts; empty array never stored (key deleted).

### 0.5 Toasts / Undo bar (used everywhere) — `showToast` 520
Pill at bottom centre (above the floating bar: safe area + 92; elsewhere safe area + 22), inverted colours (bg = text colour, fg = bg colour), radius 999, padding 12/18, text 15 pt weight 600, max width screen - 32, slides up 16 pt. Optional action button on the right, default label **"Undo"** (800 weight, 15 pt, `toast-undo` colour). Auto-hides after **5 s** (Update toast 12 s, note-peek 7 s, backup nudge 12 s). Tapping the button hides it and runs the action. Only one toast at a time (a new one replaces).
Every message, verbatim:
- "Habits reordered" (Undo) · "Marked done" (Undo) · "All parts marked done" (Undo) · "Already done today" · "Already done today — nothing to skip" · "Today marked as skip day" (Undo) · "Today is already a skip day" · "A fast is running — stop it first"
- "Yesterday marked done" (Undo) · "Yesterday is already done"
- "{Part} done" / "{Part} cleared" (Undo) · parts sheet: "Marked as a skip day", "{A, B} saved", "Day cleared" (Undo each)
- "Fast started" · "Fast started — goal {n}h" (only when a goal was passed; never from a tap now) · "Fast ended — H:MM h" (all Undo; start-undo removes the session, stop-undo sets e=null)
- "Fast deleted" / "Running fast deleted" (Undo re-inserts)
- Siri/pending steps: "Siri: fast started at HH:MM", "Siri: fast ended at HH:MM — H:MM h" (Undo), "Already fasting — H:MM h", "No fast is running", "No fasting habit found"
- skip range: "{n} day(s) skipped" / "{n} days skipped for {m} habits" (Undo removes exactly the days it added; no Undo button if nothing was added); errors "Please pick a first and a last day.", "The last day must not be before the first day.", "A range can cover at most 92 days (about 3 months)."
- Hours sheet: "Please enter a fast length between 0 and 48 hours."
- Fast edit errors: "Please enter a valid start time.", "The start can't be in the future.", "Please enter a valid end time.", "The end must be after the start.", "A fast can be at most 48 hours.", "The end can't be in the future."
- Habit archived: "“{name}” archived" (Undo) · "Aspiration archived" (Undo)
- Today-note peek: toast shows the note text with action **"Edit"** (7 s)
- Year pixel tap: "Mon, 5 Oct — done" / "— skip day" / "— not done" + " · {note}"
- Import fasting history: "{n} fast(s) imported" (Undo)
- Backup: "Backup saved"; nudge "Last backup: {n} days ago" or "No backup yet — your data lives only on this phone" with action **"Back up"** (12 s); "CSV exported"; "Poster shared"/"Poster saved", "Report shared"/"Report saved", "Could not create the report", "Nothing to summarise yet", "Summary copied", "Could not share the summary"
- Update: "Version {x} is ready" (action **"Update"**, 12 s; web only); "You're on the latest version (v1.51)"; "Update check failed — are you online?"
- Badge: "The count will now show on the app icon", "The count is off the app icon", "Not allowed — turn notifications on for Tracking in iPhone Settings", "This device cannot show a badge on the app icon"

### 0.6 Milestone celebration — `celebrate` 471, `maybeCelebrateStreak` 504
Full-screen overlay, **never blocks touches**. Centre card (surface, radius 24, padding 26/34, soft shadow `0 10 40 rgba(0,0,0,.25)`), pops in (scale .6 -> 1, 0.35 s spring-ish), shows for **2.1 s**, then fades/scale to .85 over 0.3 s. Contents top to bottom: **flame icon 52 pt in the habit colour**; text 21 pt weight 800; sub-line 14 pt weight 600 dim.
- Confetti: 26 bits (10 x 10, radius 3, every 3rd a circle) from screen centre (left 50 %, top 45 %), colours = habit colour + the next 4 palette colours that differ from it, fly out 90-240 pt at random angle (dy -40), rotate +-270 deg, scale to .6, fade over 1.5 s. Skipped when Reduce Motion is on.
- Streak text: `"{value}-day streak!"` / `"{value}-week streak!"`, sub = habit name. Day milestones **7, 14, 30, 50, 100, 200, 365, 500, 730, 1000**; week milestones **4, 10, 26, 52, 104**. Fires once per milestone (`habit.lastCelebrated = 'day7'`). Only from live check-offs (tap, swipe, part toggle) — never from yesterday/backfills/calendar.
- Personal best fast (on stopping a fast, needs >= 3 other finished fasts and the new one longer than all): text "Personal best fast!", sub "H:MM h · {habit name}".

---------------------------------------------------------------------------
## 1. TODAY screen (`#screen-today`, `data-testid` of the list: `habit-list`)

No header, no greeting, no counter. Top to bottom:
1. **Habit list** `#habit-list` (`data-testid="habit-list"`): one card per non-archived habit in stored order. List layout = vertical stack, gap 10. Grid layout (Settings > Layout) = 2 equal columns, gap 12, `align-items:start`.
2. **Review links** `#review-links` (margin 16 top, 4 bottom, column, gap 8): two permanent full-width buttons, min height 48, padding 12/14, radius 14, 1 pt border colour border, surface, shadow, text 15 pt weight 700, left-aligned: [`bulb` icon 18 pt accent] **"Last week"** [chevron-right 15 pt dim]; same with **"Last month"** (also `bulb`). Tap -> push Last week analysis / Last month screens. Not dismissible.
3. **Empty state** (only when no non-archived habits): centred, margin-top 12 vh, dim: `sprout` icon 64 pt accent; **"No habits yet"** (h2, text colour); "Tap **＋** to add your first habit.<br>Daily check-offs and start/stop timers<br>(like intermittent fasting) are supported."
4. **Floating bottom bar** (`.bottom-bar`, fixed, centred, bottom = safe area + 14, surface, radius 999, padding 7/9, gap 8, shadow `0 6 24 rgba(0,0,0,.18)`): three 48 pt round buttons without shadow, in order **Stats** (`chart` icon, aria "Statistics", id `btn-stats`), **Add** (`plus`, "Add habit", `btn-add`), **Settings** (`sliders`, "Settings", `btn-settings`, **`data-testid="settings"`**). The "gear" is the `sliders` icon (three lines with knobs). Icon-only buttons (no word) — only these are allowed per house rules.

Live refresh: every 20 s while Today is visible and any timer habit has a running fast or any finished fast (so the elapsed/eating-window numbers move); also on returning to foreground.

### 1.1 Common card anatomy (list layout) — `buildCard` 611
Card: row, `align-items:center`, gap 12, padding 11/14, radius 20, background = 17 % tint of habit colour, shadow, whole card tappable. Left to right:
1. **Action wrap** 56 x 56 (3.2941 rem) containing the 48 pt (2.8235 rem) round action button, centred. Optional ring SVG around it (fasting only, 66 x 66 viewBox, r=30, stroke 6, round cap, rotated -90 deg so it starts at 12 o'clock; track = border colour; progress dasharray 188.5).
2. **Main column** (flex): the **name line** then the **week dots**.
   - Name line: 17 pt (1 rem) weight 700, one line, ellipsis; habit icon (32 pt, habit colour) + 6 pt gap + name. Name steps down to **15 pt** if > 15 characters, **13 pt** if > 24, and additionally is *measured*: if still truncated, step down one size (15 -> 13); only at 13 pt does an ellipsis stay.
   - Optional **note dot** right after the name (only when `notes[today]` exists): 8 pt circle in the habit colour with a 2.5 pt halo (same colour 25 %); 6 pt horizontal padding. Tap -> toast with the note text and action "Edit" (7 s) -> day-note sheet. Stops propagation.
   - **Week dots**: 7 circles M T W T F S S (Monday first, Mon = this week's Monday), 16 pt (0.9412 rem), gap 5, letter 9 pt weight 700. Default background = border colour, letter dim. **Done day**: fill habit colour, white letter. **Skip day** (not done): transparent, 1.5 pt inner ring in habit colour, letter habit colour, 75 % opacity. **Not scheduled** (daily habit, that weekday off): 45 % opacity. Tap a dot -> open Detail for that habit with the calendar on that day's month, that day flashing (see 4.1); stops propagation.
3. **Stat column** (right-aligned, padding-right 2): `stat-number` 24 pt (1.4118 rem) weight 800, tracking -0.5, tabular, habit colour; `stat-label` 10.5 pt (0.6176 rem) weight 700, tracking 0.8, UPPERCASE, dim, margin-top 2.
Card tap (anywhere not consumed by a child) -> open Detail. Long-press-then-move reorders (1.6), horizontal swipe acts (1.5).

### 1.2 Card kind: DAILY check — action button
- Not done today: transparent circle with an inner ring 3 pt in the habit colour (icon colour = habit colour), no icon.
- Done today: filled circle in the habit colour, white **check** icon (23 pt); right after a live check-off the tick "draws itself" (stroke-dash 30 -> 0, 0.3 s, delay 0.05 s; off with Reduce Motion). Shadow `0 3 8 rgba(0,0,0,.12)`; press scale .9 (0.12 s).
- **Tap**: toggles today (done <-> not done; also clears a skip mark for today). On becoming done: tick animation + milestone check. No toast (silent, no Undo).
- **Long-press 500 ms** (button only): marks **yesterday** done -> toast "Yesterday marked done" (Undo) or "Yesterday is already done". Context menu suppressed. After a long press the following tap is swallowed. For a multi-part habit the long-press opens the Parts sheet for yesterday instead.
- Stat: `{streak}` + flame icon (18 pt) in habit colour; label "day" (streak = 1) or "days".

### 1.3 Card kind: WEEKLY target
Same button/dots/gestures as daily. Stat column (3 lines): number **"{count}/{target}"** (e.g. "4/6", this week's ticks / habit.target), habit colour, turns **green `#2fa96d`** when count >= target; label **"this week"**; sub-line (10.5 pt, 700, tracking .3, dim, 85 % opacity): `{weekStreak}` + tiny flame (12 pt) + " week" / " weeks". Week dots show all 7 days (weekly has no off-days).

### 1.4 Card kind: MULTI-PART (daily or weekly, name "A | B | C", 2-4 parts)
- Name line is replaced by: icon + one **text button per part** separated by a dim "|" (50 % opacity, 4 pt padding each side). Done parts today: habit colour, weight 800. Not done: dim, weight 700. Tap a part word -> toggles exactly that part (toast "{Part} done"/"{Part} cleared", Undo). Part words are not truncated/measured like a plain name (the stored name length still drives the size step).
- Circle is checked as soon as **any** part is done (streaks/dots treat the day as done).
- **Tap-count on the big circle**: each tap restarts a **320 ms** window; when it closes, count 1 toggles part 1, 2 -> part 2, 3 -> part 3 (extra taps clamp to the last part). While counting, the part about to be toggled is highlighted (background 18 % of its colour, a 0.32 s scale 1.14 -> 1 pulse). Tapping a part word cancels the pending count.
- **Swipe right** = all parts done ("All parts marked done"; "Already done today" if all already done). **Long-press circle** opens the Parts sheet (4.9) for yesterday.

### 1.5 Card kind: START/STOP (fasting, type `timer`)
The card gets class `zoned`: padding-bottom 23, `position:relative`, week dots one size smaller (14 pt circles, 8 pt letters, gap 3). **Three tap zones** separated by faint dashed vertical dividers (1.5 pt dashed, text colour at 22 %, 40 pt tall, centred, at x = -7 pt from the left edge of the main column; a second one at -7 pt from the left of the stat column **only when the edit zone exists**). Tiny labels (8.5 pt (0.5294 rem), weight 700, tracking .9, UPPERCASE, dim, 80 % opacity, overlay at bottom 4 pt, left/right 14 pt, gap 12, non-interactive) sit under the zones: 
| zone | label | tap does |
|---|---|---|
| round button (left, label centred under the 56 pt wrap) | **"start"** (idle) / **"stop"** (fasting) | idle: start a fast now (toast "Fast started", Undo removes it). Running: end it now (toast "Fast ended — H:MM h", Undo reopens). No long-press on this button. |
| middle (name + dots, label left-aligned, flexible) | **"stats"** | open Detail |
| right stat number (label right-aligned) | **"edit"** — only shown when a running fast OR any finished fast exists | running: open Edit-fast sheet (4.11) on the running fast ("Fast in progress"). Idle with a last fast: open that fast in Edit-fast ("Edit fast"). Cursor pointer on the number. |
Everything else on the card taps through to Detail (tap on the stat label also opens Detail).
- **Button**: idle = hollow ring + **play** icon in habit colour. Running = filled habit colour, white **stop** icon, pulsing halo (box-shadow 0 -> 8 pt of habit colour 30 %, 1.6 s loop).
- **Ring** (only while running and a goal exists): progress = elapsed / goal, max 1; stroke colour **red `#d9463e` below 1/3, amber `#e0a80f` from 1/3 to 2/3, green `#2fa96d` from 2/3 on**; at progress >= 1 the arc is green.
- **Stat column while running** (elapsed `H:MM` = number, habit colour, 24 pt):
  - elapsed > 24 h: number + label turn **amber** `#e0a80f`; label "still fasting?<br>tap timer to fix".
  - elapsed >= goal: number + label **green**; label **"goal reached"**.
  - goal set: label 2 lines — "{H:MM} left" / "goal {HH:MM}" (second line in habit colour = clock time the goal is hit).
  - no goal: label "fasting".
- **Stat column idle**:
  - last fast ended < 24 h ago and a goal exists for the *next* day (`goalHoursOn(last.e + 1 day)`): number = time since last stop (`H:MM`), label "eating" + line 2: "until HH:MM" (habit colour; = last end + (24 - nextGoal) h) while in the future, else **"time to fast"**.
  - else if any fast exists: number = last fast's duration, label **"last fast"**.
  - no fast ever: number = play icon (habit colour), label **"tap to start"**.
- Goal for the running fast: `session.g` if present, else `goalHoursOn(habit, goalDayFor(session))`.
- **Swipe right**: stop running fast (via toggle, own toast) or open the Record-hours sheet (4.10) for today when none runs; "Already done today" if a fast already ended today. **Swipe left**: skip today ("A fast is running — stop it first" when running).

### 1.6 Gestures on a card (`setupCardGestures` 991) — one finger, three verbs
Touches that start on the action button, a week dot or the note dot do **not** start card gestures.
- **Swipe horizontally** (|dx| > 14 and |dx| > 1.6 x |dy|): the card follows the finger (translateX clamped to +-120). At |dx| > **72 pt** it is "armed": card gets a 2.5 pt ring — **green `#2fa96d` for right**, **dim text colour for left**. Release armed right -> `swipeDone` (mark today done; "Marked done" + Undo; skip mark on today removed and restored by Undo; milestone check). Release armed left -> `swipeSkip` (today skip day; "Today marked as skip day" + Undo; refuses if done/already skipped/fast running). Release unarmed: snaps back (0.18 s). The tap that follows is swallowed.
- **Vertical move > 10 pt** = scroll (cancels everything).
- **Long-press 450 ms on the card body then drag** = reorder: card lifts (scale 1.03, shadow `0 10 28 rgba(0,0,0,.28)`, opacity .92), the list re-orders live under the finger (works in the grid too); on drop the order is saved (archived habits keep their place at the end) and toast "Habits reordered" (Undo). Cancel = revert. In SwiftUI use `.onMove`/drag-and-drop (Martin's rule: always drag, never arrows).

### 1.7 Grid layout (`state.settings.layout === 'grid'`) — card class `gcard`
Column: padding 12/13, radius 20, gap 8, overflow hidden, min-width 0. Row 1 (`grid-top`, space-between): **stat column on the left** (left-aligned, fills width; label ellipsised on one line) and the **action wrap on the right** (56 pt). Row 2: name line (16 pt (0.9412 rem), margin-bottom 6, icon 22 pt) then week dots (16 pt circles, gap 4). The fasting card in grid has **no zone labels / dividers** (those exist only in list layout) but keeps the same tap behaviour (number tap = edit, rest = Detail). Habit icons stay 22 pt in grid (cards are narrow).

---------------------------------------------------------------------------
## 2. STATS screen (`#screen-stats`) — opened from the bottom-bar chart button

Header row: `[‹ Today]` pill button (`btn-stats-back`, chevron-left + the word "Today", 16 pt weight 600, surface, shadow, radius 999). Title **"Stats"**, subtitle **"All habits at a glance"**. Then three full-width list buttons (surface, radius 14, 15 pt weight 600, 15 padding, margin 14 bottom): `bulb` **"Last week’s analysis"** (`btn-notes`), `grid` **"Last month"** (`btn-month`), `mountain` **"Aspirations"** (`btn-asp`). Then, per non-archived habit (stored order), a **stat card** (`detail-card stats-card`: surface, radius 22, padding 18, margin-bottom 16, whole card tappable -> Detail):
1. Title row: habit icon (19 pt habit colour) + name, 18 pt weight 800 one line ellipsis.
2. Four tiles in a 4-column grid (gap 8), each centred: number 21 pt (1.2353 rem) weight 800 habit colour; label 10.5 pt UPPERCASE 700 dim. Tiles: **streak** `{cur}{unit}`, **best** `{best}{unit}`, **this month**, **last month**. Unit = "d" (daily/timer) or "wk" (weekly). Month value: weekly `"{n}×"` (ticks that month), others `"{pct}%"` (done / scheduled-unskipped days up to today) or "–" when nothing scheduled.
3. Record nudge (only when streak > 0 and best - streak between 1 and 3 days / exactly 1 week): flame icon + "{gap} day(s)|week(s) to your record", 14 pt weight 700 in habit colour.
4. **30-day strip**: 30 squares (grid 30 columns, gap 3, 4 pt radius), oldest left = 29 days ago, today right. Done = habit colour; skip = transparent with 1.5 pt inner ring in habit colour at 55 % opacity; else border colour.
Then, for each timer habit with **>= 5 finished fasts**, a **rhythm card** ("{icon} {name} rhythm" title): 3 tiles — "usual start" (circular mean of start clock times, `HH:MM`), "strongest day" (weekday short name with the highest average end-day fast), "avg fast" (`H:MM` + "h") — all numbers in habit colour; then 7 bars Mon-Sun (height 90 pt, gap 7): value text above each bar (10 pt, hours with one decimal and **comma**, e.g. "16,2"), bar width max 26 radius 7/7/4/4, habit colour at 55 % opacity except the strongest day (100 %), empty weekday = 4 pt border-colour stub at 50 %; day letters under (10 pt dim, strongest day in text colour). Code `fastRhythm` 4148, `buildRhythmCard` 4177.
Last, the **Achievements** card (title: `trophy` icon in gold `#c9a227` 22 pt + "Achievements"): 3 tiles in gold — "days tracked" (sum of done days over all habits), "best streak" (`{n}d`, max longest streak of non-weekly habits), "longest fast" (`H:MMh` or "–"); then one row per habit: name line (icon + name, 14 pt 700), then chips for every earned milestone (`7d`, `14d`, … or `4w`, `10w`, … — filled with the habit colour, white 12.5 pt 800, pill) plus one **dashed hollow chip** for the next milestone to aim for (dim text, 1.5 pt dashed border). NB: How-it-works says Achievements are "at the top" but the code puts the card **last** (4365).
Empty: dim hint "No habits yet." Back button -> Today (slide back).

---------------------------------------------------------------------------
## 3. LAST WEEK analysis (`#screen-notes`) — `renderNotes` 3858
Header `[‹ Today]`; title **"Last week’s analysis"**; subtitle = date range of the **week that ended** ("12 Oct – 18 Oct", Monday to Sunday of last week). Sections top to bottom (all stop-propagation free; habit rows/cards tap -> Detail):
1. **Chart card** (`lw-chart`, surface, radius 18, padding 16/16/14): heading (12.5 pt 800 UPPERCASE dim, tracking .7) **"Habits completed each day"**; 7 columns (height 116, gap 7): a track (border colour, radius 8) with a bar in chart-ink (radius 8/8/0/0, height = count / number of habits x 100 %), day letter M T W T F S S below (11 pt 800 dim). Caption (13.5 pt dim): "Nothing was ticked last week." or "{total} in all, out of {n} habits a day. {Weekday} carried the most, with {k} of {n}." Only drawn when at least one habit existed for the whole week (`weekReport` 1242: excludes archived habits and those created after the week began).
2. **Hero card** (`lw-hero`): header line: figure (30 pt 800, **green if all targets met**) + label "habit on target"/"habits on target" (judgeable = daily + weekly habits; fasting not judged) — if nothing judgeable: ticks count + "day ticked"/"days ticked". Then one **row per habit**: top line = icon (18 pt), name (14.5 pt 700, ellipsis), mid text (14 pt 800; **green when met**) = daily "5/7 days" · weekly "3/3×" · timer "3 fasts · Ø 16:05 h" or "no fasts", delta (13 pt 800: green `+`, red `–`, dim `±`; daily/weekly deltas are streak change this week vs last with a flame icon; timer = average duration change "±H:MM"); second line = 7 squares (flex, max 45 pt, radius 9, letter 11 pt 800): **done** = habit colour fill + white letter; **skip** = transparent with 2 pt dashed habit-colour border; **off** (not scheduled) = border-colour fill at 45 % opacity; **empty** = border-colour fill, dim letter. Row divider 1 pt border colour.
3. **"The week in words"** section (heading 13 pt 800 UPPERCASE dim): `summary-box` (surface, radius 16, padding 16/18/4) with 3-5 prose paragraphs (15 pt, line-height 1.62) built by `weekSummaryParagraphs` 3418: (1) what happened ("Between {d} and {d} you ticked N days across M habits. {clauses}. …"), (2) aspiration coverage ("Towards “{title}”, 2 of 3 habits ran…"), (3) how last week compares to the recent normal (`lastWeekNotes`), (4) up to 2 patterns from 8 weeks (`weekNotes`) or the "not enough history yet" sentence, (5) one habit suggestion. Two outline buttons (`wr-cta`: full width, 1 pt accent border, radius 12, accent text 14 pt 700, `export` icon 16 pt): **"Send this summary as text"** (share sheet with text "My week, {d} – {d}\n\n…", clipboard fallback "Summary copied") and **"Send the week as a picture"** (renders the 1080 x 1350 week poster PNG and shares it, 6.3). If no complete week: dashed empty box: "Nothing to summarise yet. Everything you track began during or after last week, so there is no complete week to report on — there will be on Monday." (or "Nothing to summarise yet. Add a habit and give it a week." with no habits).
4. **"Your aspirations"** (only if aspirations exist): note-cards (surface, radius 16, padding 14/16): title (14 pt 800) + figure "{ran}/{total}" or "—" right (dim); body "{ran} of {total} habit(s) ran last week, {met} of {judged} did what it asked." or "No habits under this yet."; amber line "Quiet for {n} weeks. Is it still true?" when quiet >= 3. Tap -> Aspirations screen.
5. **"How it went"** (if `lastWeekNotes()` non-empty; max 2): cards with the habit icon + name and the sentence; tap -> Detail.
6. **"What to try next week"** with hint "Read from your own data. Every note names the figure it came from, so you can disagree with it.": up to 3 cards (`weekNotes()`, icon + title + body; aspiration notes without a habit use a dim `mountain` icon and open Aspirations). Empty: "Nothing worth saying yet. A weekday pattern needs a few weeks before it is a pattern rather than a coincidence, and a confident sentence about a coincidence would be worse than this one."
7. **"Something new?"** with hint "Only ideas. Nothing here is added until you add it.": 3 suggestion cards (icon in accent, name, right "daily" or "{n}× a week", the "why" sentence, then outline button `plus` **"Add this habit"** which opens the New-habit sheet pre-filled with name/icon/type/target — nothing is created until Save).
The rule engine (thresholds: 8 weeks of history, >= 3 prior weeks, weekday share >= 30 %, topics weekday / weekly-target / recovery / aspiration / fast-length / fast-drift) lives in `js/app.js` **2879-3416** (`recentWeeks` … `weekNotes`), `SUGGESTED_HABITS` 3337-3364 (12 canned habits, rotated by ISO week), `habitSuggestions` 3366, `ASPIRATION_STARTERS` 1215, `aspirationCoverage/silentWeeks/nudgeAllowed` 1113-1208. Port that block verbatim; it is pure arithmetic. Aspiration nudges are marked as "seen" only when displayed on this screen (`markNudged`).

---------------------------------------------------------------------------
## 4. LAST MONTH (`#screen-month`) — `renderMonthScreen` 3597
Header `[‹ Today]`. Title = "{Month name} in review" (the month that just ended; Jan -> December of previous year), subtitle = year. Habits created during/after that month are excluded. If none: dashed box "Nothing to review yet. Everything you track began during or after {Month}, so there is no complete month to report on."
1. Chart card: heading "Ticks in each week of {Month}"; one column per calendar week touching the month (Monday-first, up to 6), bar = ticks in-month that week / max week; label under each bar = the **day-of-month number the week began** (e.g. 29, 6, 13…); caption "{total} in all. The week of {d MMMM} was the strongest, with {n}. Numbers under the bars are the day each week began." or "Nothing was ticked in {Month}."
2. Hero card: one row per habit — icon, name, mid, delta: timer "N fasts · Ø H:MM h" / "no fasts" + average change vs the month before; weekly "{n}× checked off" + "+3×"/"–2×"/"±0×"; daily "{done}/{scheduled} days" + a **flame icon with the longest run in the month** (green when > 0) and a second line "Longest run of the month: N day(s)." Tap -> Detail.

---------------------------------------------------------------------------
## 5. ASPIRATIONS (`#screen-asp`) + aspiration sheet
Header `[‹ Today]`; title **"Aspirations"**, subtitle **"What the habits are for"**. List (`renderAspirations` 3665): empty -> dashed box "Nothing here yet. An aspiration is one sentence about who you are becoming — the thing your habits are actually for. Once you have one, every week says how many of its habits ran, and one that goes quiet gets asked about rather than left sitting there."
Per live aspiration a card (no colour of its own): title (14 pt 800) + figure "{ran}/{total}" or "—" (dim) at right; body (dim) "{ran} of {total} habit(s) ran last week" / "No habits under this yet"; a wrap of **habit chips** (pill, 1 pt border, 13 pt 600 dim, icon 14 pt in the habit's colour; **solid (border-colour fill, text colour) = that habit ran last week, hollow = did not**); amber (stale colour) line when quiet >= 3 weeks: "Nothing has run under this for {n} weeks. Is it still true?". Tap card -> aspiration sheet (edit). Then (only if >= 1 aspiration and some habits unattached) a card "Not attached to anything" (title dim, count at right) "Perfectly fine — a habit does not need an aspiration. Edit a habit and use *Serves* if you want to attach one." with the loose habits as plain chips.
Bottom: list button `plus` **"Add an aspiration"** (`btn-asp-add`).

**Aspiration sheet** (`#sheet-asp`): handle, title **"New aspiration"** / **"Edit aspiration"**; hint "One sentence about who you are becoming. No date, no number — the habits carry those."; label AS "ASPIRATION" + text field (max 80, placeholder "e.g. Strong and durable into my seventies", 17 pt, padding 14, radius 14); (new only) label "OR START FROM ONE OF THESE" + 4 chips (starter sentences: "Strong and durable into my seventies", "Healthy enough to keep doing what I love", "Calm, rested and clear-headed", "Someone who finishes what he starts") — tap fills the field; label "WHICH HABITS SERVE IT?" + multi-select habit chips (icon + name; a habit already under another aspiration shows "· {other title}" in dim; empty note "No habits yet — add one first and it can be attached here."); (edit only) ghost text button `import` **"Archive this aspiration"** (archives, habits become unattached, toast Undo); actions **Cancel** / **Save** (blank title: focus the field, do nothing). Save applies membership: habits ticked get this id, unticked ones that had it lose it.

---------------------------------------------------------------------------
## 6. HABIT DETAIL (`#screen-detail`)
Header: `[‹ Today]` (`btn-back`), spacer, round `pencil` button (`btn-edit`, aria "Edit habit") -> Add/Edit sheet. Title: icon (habit colour, 34 pt) + name (40 pt 800; 30 pt for 13-20 chars, 23 pt for > 20). Subtitle: timer **"Start / stop timer habit"**, weekly **"Weekly target · {n}× per week"**, daily **"Daily habit"**.
Body cards in order: **[1] calendar card** → timer only: **[2] Fasting stages**, **[3] Fasts** → **[4…] one year card per year** (descending; current year always, plus every year that has a done day). Below: ghost button `import` **"Archive habit"** (`btn-archive`; archives, goes to Today, toast “name” archived + Undo) and red text button **"Delete habit"** (`btn-delete`; native confirm: "Delete “{name}” and all of its history? This cannot be undone." — destructive, no Undo).
The screen re-renders every 20 s while a fast runs (stages marker and today's running-hour circle stay live).

### 6.1 Calendar card (`buildHistoryCard` 1614)
- Header row: month title ("November 2026", 21 pt 800; 18 pt when the extra button shows) left; right a group of 38 pt round pill buttons (icon 18 pt): [`pen` **note mode** toggle (aria "Note mode"; **on = accent fill + white icon**)] [`target` **jump to today** — only when the shown month is not the current one] [`chevL` previous] [`chevR` next (disabled at 40 % opacity when the shown month is >= 12 months ahead)]. **Swipe left/right on the card** (|dx| >= 50 and > 1.5 x |dy|) changes the month the same way (left = next).
- Hint (13 pt dim): note mode "Note mode: tap a day to write or edit its note."; timer "Tap a day to record a forgotten fast (0 = skip day) or to edit a recorded one."; else "Tap a day to cycle: done → skip day → empty."
- Grid: 7 columns Monday first, gap 6; weekday letters M T W T F S S (11.5 pt 700 dim) then leading blanks, then days 1..N. Day cell = button, width fill (max 42 pt), square, radius 12, number 14.5 pt 600 tabular, background border colour.
  - **Non-timer, past/today**: done = fill habit colour + white number; skip = transparent, 2 pt **dashed** habit-colour border, number habit colour, 75 % opacity; not scheduled = 50 % opacity; **today = 2 pt inset habit-colour outline**; has note = 4 pt dot at the bottom centre of the cell (current colour; white on a done cell); the target day after a week-dot jump flashes once (scale 1 -> 1.18 -> 1.05 with accent glow ring 3 pt, 0.9 s, delay .25 s; static 2.5 pt accent ring with Reduce Motion).
  - **Future**: disabled, transparent, 45 % opacity — except a **future skip day** (planned vacation) which is drawn like a skip day and a tap **un-marks** it.
  - **Timer cells** (`cal-fast`): transparent, 54 pt tall, column, date on top (11 pt 700 dim; today's date in text colour) and an **hour circle** (30 pt, 13 pt 800 tabular) below: **done day** -> rounded total fasted hours that ended on that day, **green `#2fa96d`** fill white number if that day's goal was met (or no goal), **grey** (border colour, text colour) if it fell short; **today with a running fast** -> **red `#d9463e`** circle with the live hours so far; **skip day** -> 2 pt dashed circle in the habit colour with an "–" (heavy dash); empty past day -> hollow 1.5 pt ring in border colour; today empty -> ring in dim colour 2 pt; future -> faint ring at 35 %.
  - **Taps** (not note mode): non-timer cycles **empty -> done -> skip -> empty** (code: done -> skip, skip -> empty, empty -> done; no toast, no milestone). Multi-part habits open the Parts sheet (4.9) instead. Timer: day with a recorded fast -> opens that day's (last) fast in Edit-fast (4.11); empty day -> Record-hours sheet (4.10); skip day -> removes the skip; future non-skip -> disabled. **Note mode**: any past/today day (and future skip days) -> Day-note sheet (4.12).
- Timer legend line under the grid (11.5 pt 600 dim, 12-pt dots, wraps): ● goal met (green) ● fell short (grey) ● running (red) ◌ skip day (dashed, habit colour).
- **"Skip several days (vacation)…"** button (`skip-range-btn`: dashed 2 pt border colour, radius 12, transparent, dim text 13.5 pt 600, `case` icon 18 pt) -> Skip-range sheet (4.8).
- **Month notes list** (when the shown month has notes; top border, 8 pt padding): rows of [day number, habit colour, 800, right-aligned min 20] + [note text 14 pt]; tap -> Day-note sheet.

### 6.2 Year pixel grid card (`buildYearCard` 2121)
Header: year (21 pt 800) left, round `export` button (38 pt, aria "Share {year} as a poster") right -> year poster (6.2). Grid: `repeat(auto-fill, minmax(14 pt, 1fr))`, gap 4 (≈ 18 columns on a 390 pt phone); for each day Jan 1…Dec 31 in order; **before day 1 of each month an extra cell holds the month letter** J F M A M J J A S O N D (9 pt 800 dim, centred, same square size). Pixel: square, radius 4. States: **done** = habit colour; **skip (past)** = transparent with 1.5 pt inner ring in habit colour at 55 %; **empty past** = border colour; **future** = border colour at 35 %; off-day = same as empty. Tap a past/today pixel -> toast with date, status, note (see 0.5). Below: stat rows (15 pt, key dim 500, value 700 tabular, row padding 5):
  - current year, weekly: "Current streak" `N week(s)`, "Longest streak" `N week(s)`, "Weeks met" `a of b`.
  - current year, others: "Current streak" `N day(s)`, "Longest streak", "Completion" `"{pct}% ({done} of {total} days)"`.
  - earlier years: "Days completed" `"{done} of {scheduledPast}"`.

### 6.3 Fasting stages card (timer only, `buildStagesCard` 2572)
Title **"Fasting stages"** (22 pt 800). SVG track viewBox 320 x 48: four rounded bars (height 12, y 16, radius 6) from x=10 to x=310 across **0–20 h** (x = 10 + h/20 x 300): Digestion 0–4 (red), Settling in 4–12 (amber), Fat burning 12–16 (light green), Deep fast 16–20 (deep green), 1 pt gaps between; non-current bars drop to 30 % opacity while a fast runs. Tick labels under (10 pt 700 dim): "0h" "4h" "12h" "16h" centred, "20h+" right-aligned. While running: a vertical marker line (2.4 pt round, text colour, y 5–31) with a 2.6 pt dot on top at the elapsed hour (clamped to 20 h). Line under (14.5 pt 600): "Now: **{Stage}** · H:MM h" (stage name in its colour) — idle: dim hint "While a fast runs, a marker shows which stage you are in." Then a divider and four rows (10 pt colour dot, name 14.5 pt 700 + range "0–4h"/"4–12h"/"12–16h"/"16h+" dim, description dim 13 pt): "Digestion — the body is still processing the last meal", "Settling in — blood sugar and insulin drift down", "Fat burning — the body leans on its fat stores", "Deep fast — ketosis territory for many people"; while running, non-current rows at 55 % opacity. Footer hint: "A popular approximation from fasting literature — every body is different. Not medical advice."

### 6.4 Fasts card (timer only, `buildSessionCard` 2640)
Title **"Fasts"**. If finished fasts exist: stat rows "Average" `H:MM h`, "Longest" `H:MM h`, "Goal met" `{n} day(s)` (days whose goal was met), "Total fasts" `N`. **Fast chart** (needs >= 2 finished fasts; last 30): SVG 320 x 118, bars (one per fast, width = clamp(3…14, slot-2), min height 3, radius 3, habit colour; height scaled to max(longest, goal) x 1.12), baseline in border colour, **dashed goal line** (1.3 pt, dash 5 4, dim 75 %) with right-aligned label "goal {n}h" at habit.goalHours (not per-day goals); caption "Last {n} fasts · tap a bar to edit that fast."; tap a bar -> Edit-fast. Hint "Tap a fast to correct its times or delete it." then a list (row: left date "Mon, Oct 5" dim, right duration "H:MM h" 700; divider 1 pt): first the running fast "In progress — started Mon 20:13" (text colour 600) + live "H:MM h", then up to the **10 most recent** finished fasts (newest first, date = end date). Each row taps to Edit-fast. With none: "No completed fasts yet — press the round button on the card to start one."

### 6.5 Year poster (share image) — `renderYearPoster` 2219
1080 x 1350 PNG, always light palette (bg `#f2f4f8`, card white `#ffffff` radius 44 inset 50, text `#16181d`, dim `#7a7f8a`, empty `#e8ebf1`), SF font. Habit icon 96 px at (106,104) in the habit colour; name 66 px 800 (shrinks to fit 730 px, min 30) at (228,162); year 42 px 800 dim at (228,220). Grid: 12 month rows x up to 31 columns, cell 22 px radius 6, x-pitch from width 866, row pitch 46, first row y=306, month letter 26 px 700 dim at x=106; done = habit colour; skip = dashed 2.4 px outline (dash 4/3) in habit colour; empty = `#e8ebf1`, future days at 45 % alpha. Three stat tiles centred at y=1030 (value 86 px 800 in habit colour, label 30 px 600 dim at y=1080): current year weekly -> "{n}" week streak / "{n}" best streak / "{a}/{b}" weeks met; current year other -> day streak / longest streak / completion %; past year -> days done / days scheduled (2 tiles). Footer "AMS Tracking · {year}, pixel by pixel" 26 px 600 dim centred y=1236. File name `ams-tracking-{slug}-{year}.png`; shares via share sheet.
### 6.6 Week poster (share image) — `renderWeekPoster` 2365
Same canvas. "My week" 62 px 800; date range "12 Oct – 18 Oct" 34 px 700 dim; top right big "{met}/{judged}" (70 px 800, green when all) + "habits on target" 27 px (or ticks + "days ticked"); divider at y=252; per habit a block (icon 52 px, name 800 shrinking, right side mid-text 40 px 800 green when met, delta 32 px 800 green/red/dim, then 7 rounded squares (done = habit colour + white letter, skip = dashed outline, empty = `#e8ebf1`, off = 50 % alpha) with letters M T W T F S S); footer "AMS Tracking · my week in review". File `ams-tracking-week-{YYYY-MM-DD}.png`.

---------------------------------------------------------------------------
## 7. ADD / EDIT HABIT sheet (`#sheet-edit`) — `openSheet` 4388, `renderSheetChips` 4457
Bottom sheet (bg = bg colour, radius 24, padding 10/20, max height 88 vh scrollable, grab handle 40 x 5). Title **"New habit"** / **"Edit habit"** (24 pt 800). Top to bottom:
1. **Live preview** (`sheet-preview`, non-interactive): a mini Today card (10 % tint) that updates on every keystroke/choice: round button (hollow ring in the colour; play icon for timer), icon + name (name or placeholder **"Your habit"**; same 15/13 pt steps by length), week dots (today's dot filled in the chosen colour unless daily and that weekday is switched off; dots of off-days at 45 %), stat "1" + flame with label "day"/"week" (daily/weekly) or play icon with "tap to start" (timer).
2. **NAME** label (13 pt 700 UPPERCASE dim, tracking .4, margin 16/8) + text field `f-name` (max 40, placeholder **"e.g. Meditate"**, autofocus when new). Hint: a `|` in the name makes parts (see 1.4).
3. **ICON** label + search field `f-icon-search` (type search, placeholder **"Search icons… (e.g. coffee, schlafen)"**, 16 pt, radius 12) + wrapping grid of the **40 habit icon chips** (44 x 44 squares, radius 12, surface, shadow, icon 25 pt, aria-label = icon name; selected = 2 pt accent border). Filter: case-insensitive substring of the icon **name** or of its EN/DE keywords. No match: "No icons match — clear the search to see all." Default icon = first in list (meditate); on edit = the habit's icon.
4. **COLOR** label + 8 round colour chips (44 x 44 chip containing a 26 pt circle in the palette colour; selected = accent border). Default = `PALETTE[habits.count % 8]`.
5. **TYPE** label + three stacked buttons (surface, radius 16, 2 pt transparent border / accent when selected, padding 11/12, icon left in accent 23 pt, name 15 pt 700, description 12.5 pt dim): `check` **Daily check** "Tick it off once a day"; `target` **Weekly target** "Hit a number per week, on any days"; `timer` **Start / Stop** "One button toggles a timer, e.g. fasting". When **editing**, the Start/Stop option is disabled (and all three disabled if the habit already is a timer); daily <-> weekly may be switched (history untouched). When switching a note appears (dim 12.5 pt): to weekly "Every day you have ticked stays. The streak will count weeks that reached the target, instead of days in a row."; to daily "Every day you have ticked stays. The streak will count days in a row again, on the days you choose below."
6. **TIMES PER WEEK** (weekly only): seven number chips 1…7 (44 x 44, 12.5 pt 700 dim, selected accent border + accent text). Default 3; switching from a daily habit starts at its number of scheduled days.
7. **FASTING GOAL (HOURS)** (timer only): number field `f-goal` (decimal, 1–48, step .5, placeholder "e.g. 16") + seven small optional fields M T W T F S S (`gbd-row`, label 10 pt dim above each, field 14 pt centred, radius 10) + hint "Optional: a different goal for certain days — the day a fast *ends* on. Empty days use the goal above." Values outside (0,48] are stored as null; if all seven empty `goalByDay=null`.
8. **SERVES** (only if >= 1 live aspiration): pill chips, one per aspiration title plus **"Nothing in particular"** (single choice, selected = accent border).
9. **ON WHICH DAYS?** (daily only): seven chips M T W T F S S (multi-select, at least one stays on — tapping the last selected day does nothing).
10. Buttons: ghost **Cancel** (`btn-sheet-cancel`) and full-colour accent **Save** (`btn-sheet-save`; blank name -> focuses the name field, does nothing). Tapping the dim backdrop or dragging down also cancels. Save (edit): updates name/icon/colour/days/aspiration; timer: goal + goalByDay; daily<->weekly: type + target (target null for daily); then reopens Detail. Save (new): appends habit with `createdAt = today`, `done:{}`, `sessions:[]`, then Today. Habit order index = append.

---------------------------------------------------------------------------
## 8. SMALL SHEETS

### 8.1 Record-hours sheet (`#sheet-hours`) — `openHoursSheet` 2064 (opened by calendar tap on an empty timer day, or swipe-right on an idle fasting card)
Title **"Fast on {Mon, 5 Oct}"**; label "HOW MANY HOURS?"; chips of presets = unique(goalHoursOn(day), 13, 15, 16, 18) shown as "{n}h" (`goal-chip`: auto width min 52 pt, 15 pt 700); **tapping a chip saves immediately** (no Save needed); number field `hours-input` (decimal, 0.5–48, step .5, placeholder "Or type the hours…", accepts comma); ghost text button **"Mark as skip day instead"** (`btn-hours-skip`); **Cancel** / **Save** (saves the typed number). Saving creates a finished fast **ending at 12:00 on that day**, start = end - hours. Invalid -> toast (see 0.5). Returns to Today if opened from there, else refreshes Detail.

### 8.2 Edit-fast sheet (`#sheet-fast`, `data-testid="sheet-fast"`) — `openFastSheet` 2757
Title **"Edit fast"** (finished) or **"Fast in progress"** (running). Label STARTED + `datetime-local` field (`data-testid="fast-start"`); for finished fasts label ENDED + `datetime-local` (`fast-end`, hidden while running); line "Duration: H:MM h" (live, dim; running uses now as end); red text button **"Delete this fast"** (`btn-fast-delete`, toast Undo restores); **Cancel** / **Save** (`data-testid="fast-save"`). Validation in 0.5; sessions re-sorted by start. No goal chips (goal is only set in Edit habit; a fast's own `g` is kept).

### 8.3 Skip-several-days sheet (`#sheet-skiprange`) — `openSkipRangeSheet` 1882
Title **"Skip several days"**; hint "On holiday or out sick? Every day in the range becomes an excused skip day — streaks survive, and days already done stay done."; labels FIRST DAY / LAST DAY with date pickers (both default today); checkbox row **"Apply to all habits"** (default ticked when > 1 non-archived habit); **Cancel** / **Mark skip days**. Rules: max 92 days, to >= from; days already done or already skipped are left alone; Undo removes exactly what was added.

### 8.4 Parts sheet (`#sheet-parts`) — `openPartsSheet` 1971
Title = "Yesterday · Thu, 8 Oct" / "Today · …" / plain date; label "TAP THE PARTS YOU DID"; one toggle chip per part (selected = accent border; pre-ticked from the day's existing parts); ghost text button **"Mark as skip day instead"**; **Cancel** / **Save**. Save with parts ticked -> done = those parts, skip cleared ("{A, B} saved"); **Save with none ticked empties the day (done and skip) -> "Day cleared"**; skip button -> "Marked as a skip day". All with Undo; never fires a milestone. Opened by long-press on the circle (yesterday) or a calendar tap.

### 8.5 Day-note sheet (`#sheet-note`) — `editDayNote` 1841
Title **"Note for {Thu, 8 Oct}"**; multi-line field `note-input` (max 200, 3 rows, placeholder "e.g. skipped, travel day", autofocus when new); red text **"Delete this note"** (only when a note exists); **Cancel** / **Save** (empty text deletes the note). Opened from the calendar (note mode or future skip), the month-notes list, or the Today note dot's "Edit".

### 8.6 Import fasting history sheet (`#sheet-histimport`)
Title **"Import fasting history"**; hint "Paste rows from another app's export. Understood formats, one fast per line:" • `2026-08-15;14` (day; hours — also with , . or tab) • `2026-08-15 19:00;2026-08-16 11:00` (start; end) • rows from this app's own fasts.csv; multiline field (6 rows, 13 pt tabular, placeholder "2026-08-01;13 / 2026-08-02;14,5 / …"); live preview line "Found {n} new fast(s) · {n} already recorded · {n} unreadable line(s)." or "No fasting habit to import into."; **Cancel** / **Import** (disabled until >= 1 new fast). Target = first non-archived timer habit. Duplicate rule: a day that already has a fast is skipped; one fast per end-day; 0 < hours <= 48; end <= now. Parser `parseHistoryText` 4910.

### 8.7 Reorder sheet (`#sheet-reorder`) — NB web uses arrows
Title "Reorder habits"; one row per habit (all, including archived; surface, radius 14, padding 10/12): icon + name; two 40 pt round `chevU`/`chevD` buttons (disabled at the ends, 30 % opacity). Button **Done**. Martin's rule for native is drag-to-reorder — use `List` + `.onMove`/EditButton (on the Mac, a custom handle).

### 8.8 Archived habits sheet (`#sheet-archived`)
Title "Archived habits"; hint "Archived habits keep all their history and can be restored any time."; rows (icon + name + accent pill button **"Restore"**, 14 pt 700 white, restores and refreshes Today); empty "Nothing here — archive a habit from its detail view." **Done**.

---------------------------------------------------------------------------
## 9. SETTINGS sheet (`#sheet-settings`, `data-testid="sheet-settings"`) — opened by the Settings button
Title "Settings". Rows are full-width list buttons (surface, radius 14, 15 pt weight 600, icon 20 pt + 7 gap, padding 15, margin-bottom 10), in this order:
1. `export` **"Send last week's report"** (`btn-week-report`) — shares the week poster PNG for the week that ended.
2. `export` **"Export backup (JSON)"** (`btn-export`, `data-testid="export-backup"`) — shares `ams-tracking-backup-YYYY-MM-DD.json` (pretty JSON of the whole state); sets `lastBackup`; toast "Backup saved"; on failure alert "Backup failed: …".
3. `import` **"Import backup"** (`btn-import`) — file picker JSON; needs `habits` array else alert "Import failed: Not an AMS Tracking backup"; confirm "Replace current data with this backup ({n} habits)?"; replaces everything (in the iPhone app a backup's "reminder on" is turned off until permission is granted).
4. `chart` **"Export CSV for Excel"** (`btn-csv`) — shares two files: `ams-tracking-days-{date}.csv` (header `date;habit;type;status;parts;note`, status done/skip/empty, parts = part names) and `ams-tracking-fasts-{date}.csv` (`habit;start;end;hours`, decimal comma, semicolon separated, `"` quoting).
5. `timer` **"Import fasting history"** (`btn-histimport`) -> sheet 8.6.
6. `sunrise` **"Show the count on the app icon"** (`btn-badge`, `data-testid="badge-toggle"`, `data-on` 0/1) — toggles to "Hide the count on the app icon"; asks notification permission; badge = count of non-archived scheduled habits not done/skipped today and without a running fast; disabled text "App icon badge not supported here".
7. **Daily reminder row** (`row-reminder`, `data-testid="reminder-row"`, `data-on`): a button `bell` + **"Daily reminder: off"/"Daily reminder: on"** (`reminder-toggle`) and a time field (`reminder-time`, `data-testid="reminder-time"`, default **20:00**, 4.4 em wide, bg = page bg; **accent fill + white text when on**). Below it a hint line (13 pt dim, hidden when empty, `reminder-note`): on -> "Every day at {time} — also when the app is closed." (or "… — the new time goes out when you are online."), off/lost permission -> "Off — notifications were turned off for Tracking in iPhone Settings.", unsupported -> "Needs the app on your Home Screen.", else "Pick the time, then tap to turn it on." Native: schedule local notifications for the next 30 days at that time; body = "Still open: {name}" / "{n} still open: {a, b}" / "Time to fill in your tracked items."; dropped for today when everything scheduled is done (`planNativeReminders` 5323).
8. `sunrise` **"Check for app update"** (`btn-update`, `data-testid="check-update"`) — **hidden in the iPhone app** (updates arrive via TestFlight); omit natively.
9. `reorder` **"Reorder habits"** (`btn-reorder`) -> 8.7 (Settings closes first).
10. `grid` **"Layout: list"/"Layout: grid"** (`btn-layout`) — toggles layout immediately.
11. `moon` **"Theme: auto"/"Theme: light"/"Theme: dark"** (`btn-theme`) — cycles auto -> light -> dark.
12. `import` **"Archived habits ({n})"** (`btn-archived`) -> 8.8.
13. Two collapsible folds (surface, radius 14; summary row 15 pt 600 with a "›" that rotates 90 deg when open): **`help` "How it works"** and **`scroll` "Version history"** (an entry per version, newest first: `<h4>v1.51 — 26 Nov 2026</h4>` tagline + bullet list; text lives in `index.html` lines 252-819 — rebuild the whole How-it-works text and the full history from there; version history text at 332-818). How it works ends with the section **"Signs in this app"** (lines 308-328): Big circle with a tick = done today; Plus = add a new habit; Flame + number = streak days/weeks; Week dots M–S (filled done / dimmed not scheduled / dashed outline skip day; tap opens that day); Skip day (hollow dashed; in fasting calendar dashed circle with dash); Small dot next to a name = today has a note (tap to read; calendar dot under a day = note); Pencil = edit habit / note mode; Pixel grid solid/pale/dashed/very faint; Fasting ring red/yellow/green; Fasting calendar circles green/grey/red-live/dashed; Amber text = out of date/needs a look; Stage colours (red Digestion, yellow Settling in, light green Fat burning, deep green Deep fast); small capital words under the fasting card; Moon (icon menu "Start Fasting"); Fork and knife (icon menu "Stop Fasting", line "Since 20:13"); Number on the app icon; Red button text/red Delete = removes for good, blue word "Undo" takes back; Blue = buttons/links/Update; a habit's own colour always means that habit.
14. Footer note (centred, 13 pt dim, line-height 1.5): backup line ("No backup yet." / "Last backup: today." / "yesterday." / "{n} days ago." — shown in **amber/stale 700** when no backup and data exists, or older than 30 days) · storage line (web: "Storage: protected"/"not yet protected" + " · {n} KB"; iPhone: "Storage: inside the app, with a safety copy") · "All data is stored only on this device." · version `data-testid="app-version"`: **"AMS Tracking v1.51"** (+ " · iPhone app" natively).
15. Single ghost button **Close** (`btn-settings-close`).
Backup nudge: 2.5 s after launch, if there is data and no backup within 30 days and no nudge within 30 days -> toast with "Back up" action (opens the share of the JSON backup).

---------------------------------------------------------------------------
## 10. Fasting via Home Screen quick action / Siri (iPhone app) — `applyFastAction` 5564
Acts on the **first non-archived timer habit**. Quick action shows ONE entry: "Start Fasting" (SF Symbol `moon`) when none runs, "Stop Fasting" (SF Symbol `fork.knife`, subtitle "Since 20:13") while running (see `ios/App/App/Fasting.swift` lines 235/242). A start while running is ignored; a stop needs a running fast that began before the request time. Steps asked while the app was closed are applied in order with Siri's own time; toasts in 0.5.

---------------------------------------------------------------------------
## 11. Icons (file `js/icons.js`, 357 lines)
Conventions: `viewBox="0 0 24 24"`, `fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"`; the objects `ICON_PATHS` (lines 6-291) hold the body of each SVG. `ICON_NAMES_HABIT` (292-299, picker order), `ICON_KEYWORDS` (301-343), `EMOJI_TO_ICON` (345-350, only for migrating v1.0 data), `icon(name)` (352). Unknown name falls back to `sun`. Shapes are "wobbly ink": cubic Bezier paths + a few `<ellipse>` with `transform="rotate(...)"`. A few shapes carry a heavier stroke (`chart` bars `stroke-width="2.6"`).

**Habit icons — name (line) : search words (EN + DE), picker order:**
meditate(10) meditation yoga zen calm mindfulness meditieren achtsamkeit · dumbbell(16) workout gym strength weights lift training hantel kraft fitness · book(21) read reading lesen buch lernen · guitar(26) music instrument practice gitarre musik üben · run(31) running jog cardio laufen joggen rennen sport · sunrise(38) morning early wake dawn morgen aufstehen sonnenaufgang · books(43) study learn school exam studieren lernen bücher · moon(49) night sleep fasting evening nacht mond fasten abend · drop(53) water hydrate drink wasser trinken tropfen · apple(57) food fruit healthy eating diet essen obst gesund ernährung · bike(62) cycling bicycle ride fahrrad radfahren · pen(68) write journal diary schreiben tagebuch stift · tooth(73) teeth dental floss brush zähne zahn putzen · broom(76) clean tidy chores putzen aufräumen haushalt · sun(81) day light outside sonne tag draussen · timer(86) stopwatch time fasting track timer zeit uhr · heart(92) love health family herz liebe gesundheit · pulse(95) heartbeat cardio health fitness puls herzfrequenz · music(98) song listen practice note musik lied hören · bed(104) sleep rest bedtime nap schlafen bett ruhe · pill(108) medicine vitamin supplement tablette medikament vitamine · glass(112) water drink hydrate glas wasser trinken · coffee(117) caffeine cup tea kaffee tee koffein tasse · phoneOff(122) screen time no phone digital detox handy bildschirmzeit · smokeOff(127) quit smoking no cigarette rauchen aufhören zigarette nichtraucher · wineOff(132) no alcohol sober drink less alkohol nüchtern verzicht · leaf(137) nature vegan plant green natur pflanze vegan blatt · shoe(141) walk steps hike spazieren gehen schritte schuhe · waves(145) swim swimming water sea schwimmen wasser meer wellen · kettlebell(150) workout gym strength swing kettlebell kugelhantel training · bulb(154) idea learn think practice idee lernen denken glühbirne · camera(158) photo photography picture foto fotografieren kamera · brush(162) paint art draw creative malen kunst zeichnen pinsel · coin(166) money save budget finance geld sparen finanzen münze · paw(171) dog pet walk cat hund gassi haustier katze pfote · flower(178) garden plant water nature blume garten pflanze giessen · mountain(186) hike climb outdoor wandern berg klettern · chat(190) language talk speak practice sprache sprechen reden chat · snowflake(194) cold shower ice winter kalt dusche eis winter · stairs(198) stairs steps climb treppe stufen steigen.
(The exact search string is copied from `ICON_KEYWORDS`; the picker filter is `name.includes(q) || keywords.includes(q)` on lowercase input.)

**UI icons (full path data; all `viewBox 0 0 24 24`, stroke style above). Use as the "marks" the native app redraws:**
- `check` (tick in the big circle): `M5.2 12.8 C7 14.3 8.4 15.9 9.4 17.7 C11.7 13.2 14.9 9.2 19 6`
- `plus`: `M12.1 5.4 L11.9 18.6 M5.4 12.1 L18.6 11.9`
- `x`: `M7.2 7.5 C10.3 10.4 13.4 13.5 16.6 16.8 M16.9 7.2 C13.6 10.3 10.4 13.5 7.4 16.7`
- `play`: `M9.2 6.7 C12.1 8.3 14.7 10 16.9 11.9 C14.7 13.9 12.2 15.6 9.3 17.2 C9 13.7 9 10.2 9.2 6.7 Z`
- `stop` (rounded square): `M8.1 8.3 C10.7 8 13.3 8 15.9 8.2 C16.1 10.7 16.1 13.2 15.9 15.7 C13.3 16 10.7 16 8.2 15.8 C8 13.3 8 10.8 8.1 8.3 Z`
- `flame` (streak): `M12.3 3.6 C13.6 6.2 15.9 8.1 17 10.6 C18.2 13.3 17.3 16.5 15 18.3 C12.7 20.2 9.4 20 7.3 18 C5.2 16 4.9 12.8 6.4 10.4 C7 9.4 7.8 8.5 8.4 7.5 C9 9 9.1 10.1 8.7 11.6 C11 10.2 12.4 7 12.3 3.6 Z` + inner `M12.2 12.6 C13.1 13.7 13.3 15.1 12.6 16.2 C11.9 17.3 10.5 17.6 9.5 16.9`
- `pencil` (edit): `M5.3 18.7 L5.9 15.5 L15.8 5.4 C16.6 4.6 17.9 4.7 18.6 5.5 C19.3 6.2 19.3 7.4 18.6 8.2 L8.6 18.2 Z` + `M14.9 6.5 L17.6 9.1`
- `pen` (note-mode button; also a habit icon): `M6 18.9 C6.3 17.1 6.7 15.8 7.3 15.1 L16.3 5.4 C17 4.6 18.2 4.6 18.9 5.3 C19.6 6 19.6 7.2 18.9 7.9 L9.6 17.4 C8.9 18 7.6 18.5 6 18.9 Z` + `M15.4 6.5 L17.8 8.8` + `M12.4 19.3 C14.4 18.9 16.4 18.9 18.4 19.2`
- `chart` (Stats; also CSV row): `M4.9 19.2 C9.6 18.9 14.3 18.9 19 19.2` + bars `M7.4 16.4 L7.5 11.9 M12 16.5 L12.1 6.8 M16.6 16.4 L16.7 9.6` at **stroke-width 2.6**
- `sliders` (**the Settings button — there is no gear**): lines `M4.5 7 L19.6 6.8 M4.4 12.1 L19.5 12 M4.5 17.2 L19.6 17` + three knob ellipses filled with the surface colour: `cx 9 cy 6.9`, `cx 15.2 cy 12`, `cx 7.6 cy 17.1` (`rx 1.7 ry 1.6`)
- `moon`: `M13.8 4.1 C10.5 5.1 8.3 8.2 8.5 11.8 C8.7 15.4 11.3 18.3 14.7 18.9 C13 19.9 10.9 20.2 9 19.6 C5.6 18.5 3.4 15.1 3.8 11.5 C4.2 7.9 7 5 10.6 4.3 C11.7 4.1 12.7 4 13.8 4.1 Z` + stars `M16.9 6.9 L17 7 M18.9 10.5 L19 10.6 M17.6 14.4 L17.7 14.5`
- `export` (**share**, also year/week share): `M5 15.6 C5 17.1 5.2 18.5 5.6 18.9 C7.7 19.3 16.3 19.3 18.4 18.9 C18.8 18.5 19 17 19 15.5` + `M12 4.6 L12.1 14.1 M8.8 7.8 C9.9 6.6 11 5.6 12.1 4.5 C13.2 5.6 14.2 6.7 15.2 7.8` ; `import` (Archive / Import): same tray + `M12.1 4.6 L12 14 M8.8 10.9 C9.9 12 10.9 13.1 12 14.1 C13.1 13 14.1 11.9 15.2 10.8`
- chevrons: `chevL` `M14.6 5.7 C12.2 7.7 10.2 9.8 8.7 12 C10.3 14.3 12.3 16.4 14.5 18.3` · `chevR` `M9.4 5.7 C11.8 7.7 13.8 9.8 15.3 12 C13.7 14.3 11.7 16.4 9.5 18.3` · `chevU` `M5.7 14.8 C7.7 12.4 9.8 10.4 12 8.9 C14.3 10.5 16.4 12.5 18.3 14.6` · `chevD` `M5.7 9.4 C7.7 11.8 9.8 13.8 12 15.3 C14.3 13.7 16.4 11.7 18.3 9.6`
- `target` (jump to today; Weekly-target type): ellipses `cx12 cy12 rx8.1 ry7.9 rotate(5)`, `cx12 cy12.1 rx4.6 ry4.4 rotate(-7)` + dot `M11.9 12 L12.1 12.1`
- Others (copy from the file): `bulb` 154 (Last week), `grid` 285 (Last month, Layout), `mountain` 186 (Aspirations), `bell` 280 (reminder), `case` 275 (vacation), `trophy` 253 (Achievements), `help` 235 (How it works), `scroll` 240 (Version history), `sprout` 244 (empty state), `reorder` 266, `timer` 86 (Start/Stop type), `sunrise` 38 (badge / update rows).
- **Fork-and-knife and gear do NOT exist in `icons.js`.** Fork and knife is only an SF Symbol (`fork.knife`) used in the iOS quick action (`Fasting.swift`); draw it in the same style if it is needed in the app UI. Settings uses `sliders`.
- App icon: `icons/icon.svg` (512, flat `#2f6fe0`, 3 x 3 day-grid: white ticks for done cells, open rounded squares for empty cells, one 1.9 stroke on the 24-grid scaled 14.5).

---------------------------------------------------------------------------
## 12. `data-testid` / element-id cheat sheet
`data-testid`: `habit-list`, `habit-name` (card name line), `habit-icon` (icon span on a card), `settings` (bottom-bar Settings), `sheet-settings`, `export-backup`, `badge-toggle`, `reminder-row`, `reminder-toggle`, `reminder-time`, `check-update`, `app-version`, `sheet-fast`, `fast-start`, `fast-save`. (The old `version-pill` no longer exists.) Everything else is found by id: `btn-stats btn-add btn-settings btn-stats-back btn-notes btn-month btn-asp btn-asp-add btn-back btn-edit btn-archive btn-delete btn-sheet-cancel btn-sheet-save f-name f-icon-search f-icons f-colors f-goal f-goalbyday f-target f-days f-serves sheet-preview btn-week-report btn-export btn-import btn-csv btn-histimport btn-badge btn-reminder reminder-time btn-update btn-reorder btn-layout btn-theme btn-archived btn-settings-close btn-fast-save btn-fast-delete btn-fast-cancel fast-start fast-end btn-skiprange-save btn-skiprange-cancel skip-from skip-to skip-all hours-chips hours-input btn-hours-save btn-hours-skip btn-hours-cancel parts-chips btn-parts-save btn-parts-skip btn-parts-cancel note-input btn-note-save btn-note-delete btn-note-cancel hist-input hist-preview btn-hist-save btn-hist-cancel toast toast-msg toast-undo celebrate`. Suggested SwiftUI `accessibilityIdentifier`s = the same strings.

---------------------------------------------------------------------------
## 13. Gotchas for the port
- "A day done" differs by type: timer -> a fast **ended** that day; the day goal for green/grey circles uses the **end day**.
- Weeks are always Monday-first; `weekStart(d)` must be compared by day key, not timestamp (v1.x bug).
- Streak rules: today pending never breaks it; skip days never break or extend it; weekly: running week never breaks the streak.
- `done` values are `1` or `[partIdx]` — both truthy; keep that.
- Backfills (yesterday, calendar, parts sheet, range) never fire milestones; only live check-offs do.
- Swipe, long-press-drag and button long-press must not collide: card gestures ignore touches that start on the action button, a week dot or the note dot.
- Web has Reorder with arrows and a Layout/Theme *toggle rows*; Martin's standing rule asks for drag-to-reorder everywhere and a visible word on every symbol-only button (the web bottom bar has none — it is the allowed exception for + and the gear-equivalent).
- Achievements card sits at the BOTTOM of Stats (How-it-works text says top).
- Settings has no "Close"-less variant; Cancel/Save only on edit sheets; Settings, Reorder, Archived use Close/Done.

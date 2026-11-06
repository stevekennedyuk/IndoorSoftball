# Indoor Softball

Score keeper and half-inning timer for indoor softball — iPhone, iPad and Apple Watch (SwiftUI, iOS 17 / watchOS 10).

## Scoring rules (all configurable in Settings)

| Event | Default | Notes |
|---|---|---|
| Batter reaches 1st / 2nd / 3rd off the bat | +1 / +2 / +3 | `pointsPerBase` × bases (0 = outdoor variant) |
| Batter home off the hit | +4 | 4 × per-base; if per-base is 0 the batter scores like a run |
| Runner (already on base) crosses home | +1 | `runPoints` |
| Home run off the back wall | +5, plus +1 per runner on base | asks 0–3 runners on base; outdoor variant 4 |
| Batter out / runner out | −1 | `outPoints` |
| Runner out at home by the catcher | −2 | `outAtHomeByCatcherPoints` |
| Correction | ±1 | manual fix-ups |

* Innings default 2 (Away bats then Home bats = 1 inning); time per half default 5:00 in 30 s steps; warning at 1:00 left.
* Outs never end a half — only the clock does. When time is up the clock turns red and flashes (with haptics and sound), shows overtime, and **scores can still be entered until the next half is started**.
* Each half keeps a plus tally and a minus tally; the half's score is their sum and can be negative.
* Highest total wins, so −5 beats −10. Ties stand – there are no extra innings.
* Settings carry forward to every new game until changed. A game in progress keeps the settings it started with.
* Presets: "Indoor rules" (1/base, HR 5) and "Outdoor variant" (0/base, HR 4).

## Screens

**iPhone / iPad** — Game tab (scoreboard with AT BAT highlight, big colour-coded clock, half tally, scoring pad, entry log, line score, pinned "Start next half / End Game" button), History (all finished games, share as text), Settings. On iPad the scoreboard and clock sit beside the scoring pad.

**Watch** — vertical pages: Clock (with mini scoreboard) → Scoring pad → Tallies/line score → Controls (next half, ±30 s, corrections, settings, end/discard).

The end-of-game summary shows final scores, the winner, the line score, and for each inning each half's + / − / net with the score at the end of the inning; tap a half to see its individual entries.

## Sync

Each device scores its own game. Settings changed on the phone or watch are copied to the other; finished games are copied both ways so History on the phone includes games scored on the watch. (iPad has no paired watch.)

## Project layout

```
Shared/                     both targets
  Model/   GameSettings, ScoreEvent + ScoringRules, Game/HalfInning/HalfTimer, GameReport
  Engine/  GameStore (all rules/timing), Persistence (JSON in Application Support),
           GameFeedback (platform hooks), AlertScheduler (notifications), SyncManager (WatchConnectivity)
  UI/      Theme, Components, LineScoreView, GameSummaryView, SettingsForm
IndoorSoftball/             iPhone + iPad app
IndoorSoftball Watch App/   watchOS app (embedded in the iOS app)
AppStore/                   App Store Connect + TestFlight metadata
Website/indoor-softball/    support + privacy pages for nettek.uk
```

The project uses Xcode 16+ **folder-synchronised groups**: any Swift file dropped into `Shared/`, `IndoorSoftball/` or `IndoorSoftball Watch App/` is picked up by the right target(s) automatically — no `project.pbxproj` edits needed.

## Building

1. Open `IndoorSoftball.xcodeproj` (Xcode 16 or later).
2. Team is preset to BWY5VL5Y24 with automatic signing; bundle IDs `uk.nettek.IndoorSoftball` and `uk.nettek.IndoorSoftball.watchkitapp`.
3. Run the **IndoorSoftball** scheme on an iPhone/iPad, or the **IndoorSoftball Watch App** scheme on a watch.
4. Version 1.0 (1). Build-number policy as for UmpireClicker: keep the next unused build number in the project and untick "Manage Version and Build Number" at Distribute.
5. TestFlight / App Store Connect: see `AppStore/AppStoreConnect.md` for the bundle IDs, the nettek.uk support and privacy URLs, the privacy answers ("Data Not Collected"), the description, keywords and "What to Test", and the upload checklist. The support and privacy pages to upload are in `Website/indoor-softball/` (they go at https://nettek.uk/indoor-softball/).

Tips: on the watch, set Settings → General → Return to Clock → Indoor Softball → "After 1 hour" so the app stays up between plays. The time-up and 1-minute alerts also arrive as notifications if the app is in the background (add the Time Sensitive Notifications capability if you want them to break through Focus).

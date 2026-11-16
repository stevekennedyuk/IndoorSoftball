# Indoor Softball

Score keeper and half-inning timer for indoor softball — iPhone, iPad and Apple Watch (SwiftUI, iOS 17 / watchOS 10).

## Scoring

Each game uses one of two scoring types, chosen at New Game (and remembered):

**Indoor**

| Button | Points |
|---|---|
| **+1** | +1 |
| **−1** | −1 |
| **HR** | Home run off the back wall: +5 by default, set in Settings |
| **OC** | Out by the catcher at home: −2 by default, set in Settings |

The tallies show **Plus**, **Minus** and **Total** for the half being scored.

**Outdoor** (runs only; the only settings are innings and time per half)

| Button | Runs |
|---|---|
| **+1** | 1 |
| **HR+1** | 2 (home run with 1 runner on) |
| **HR+2** | 3 |
| **HR+3** | 4 |

The tally shows the runs for the half. Undo removes the last tap in either type.

* Innings default 2 (Away bats then Home bats = 1 inning); time per half default 5:00 in 30 s steps; warning at 1:00 left.
* Outs never end a half — only the clock does. When time is up the clock stops at 0:00, turns red and flashes (with haptics and sound) – that half is over, but **+1 / −1 / HR still work until Start Bottom 1 (or End Game) is tapped**.
* Each half keeps a plus tally and a minus tally; the half's score is their sum and can be negative.
* Highest total wins, so −5 beats −10. Ties stand – there are no extra innings.
* Settings (scoring type, innings, time per half, warning time, and the indoor HR and OC values) carry forward to every new game until changed. A game in progress keeps the settings it started with.

## Screens

**iPhone / iPad** — Game tab, laid out to fit without scrolling: scoreboard with AT BAT highlight, big colour-coded clock, Plus / Minus / Total tallies, and +1 / −1 / HR buttons that fill the rest of the screen. When time is up, the clock's main button becomes **Start Bottom 1** (or **End Game**); ending a half early is in the ⋯ menu, and the Scores button shows the tallies so far. The layout is chosen from the space available. Large iPads use two columns with a full-height clock and the line score. iPhones, iPad mini/11″ in portrait and the iPhone Duo (folded or unfolded) use one column. Any phone on its side uses two compact columns. Also History (finished games, share as text) and Settings.

**Watch** — vertical pages: Clock (with mini scoreboard) → +1 / −1 / HR with tallies → Tallies/line score → Controls (next half, ±30 s, corrections, settings, end/discard).

The end-of-game summary shows final scores, the winner, the line score, and for each inning each half's + / − / net with the score at the end of the inning.

## Results files and sharing

- **New Game details:** Home and Away team names and an optional **Location**. All three are remembered for the next game.
- **Start time:** the time play starts is the first time the clock is started.
- **File:** every finished game is saved as a text document in the app's Documents folder, which the Files app shows as On My iPhone/iPad → Indoor Softball. The name is **home-away-location-date&time**, e.g. `Owls-Hawks-Hackney Leisure Centre-2026-11-08 1930.txt`; any name or location left blank becomes Home, Away or Location, e.g. `Home-Away-Location-2026-11-08 1930.txt`. The layout is:

  ```
  Hawks vs Owls : Hackney Leisure Centre : 08/11/2026 : 19:30
  Inning 1
  Hawks: +11 : -2 : 9
  Owls: +8 : -2 : 6
  Inning 2
  Hawks: +9 : -2 : 7
  Owls: +12 : -1 : 11

  End Game
  Hawks: 16
  Owls: 17
  ```

  Each inning line is that team's plus, minus and total for the inning. A half that wasn't played (game ended early) shows "not played".
- **Share results** (final screen and History) opens the share sheet with the results document attached and its text in the message. Mail, Gmail and Outlook also get a subject line. Messages, WhatsApp, AirDrop and Save to Files all work. The app never sends anything itself.
- **History:** edit the teams and location, which renames the file, or share a game again. Deleting a game asks whether to delete its file too.
- **Watch:** games are always Away v Home with no location, and they don't change what the phone remembers. When one reaches the iPhone, History marks it "Scored on Watch · tap to add teams & location". Opening it shows an **Add team names & location** button, which also renames the results file.
- **No permissions:** none are needed. The Info.plist keys `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` make the folder appear in Files.

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
4. Version 1.0 (5). Build-number policy as for UmpireClicker: keep the next unused build number in the project and untick "Manage Version and Build Number" at Distribute.
5. TestFlight / App Store Connect: see `AppStore/AppStoreConnect.md` for the bundle IDs, the nettek.uk support and privacy URLs, the privacy answers ("Data Not Collected"), the description, keywords and "What to Test", and the upload checklist. The support and privacy pages to upload are in `Website/indoor-softball/` (they go at https://nettek.uk/indoor-softball/).

Tips: on the watch, set Settings → General → Return to Clock → Indoor Softball → "After 1 hour" so the app stays up between plays. The time-up and 1-minute alerts also arrive as notifications if the app is in the background (add the Time Sensitive Notifications capability if you want them to break through Focus).

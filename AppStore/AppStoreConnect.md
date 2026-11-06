# Indoor Softball – App Store Connect & TestFlight

## Identity

| Item | Value |
|---|---|
| Publisher / seller | NetTek Ltd |
| Team ID | BWY5VL5Y24 |
| iOS bundle ID | `uk.nettek.IndoorSoftball` |
| watchOS bundle ID | `uk.nettek.IndoorSoftball.watchkitapp` |
| SKU | `uk.nettek.indoorsoftball` |
| Version / build | 1.0 (1). The project always holds the next unused build number, so bump it straight after each confirmed upload. |
| Copyright | © 2026 NetTek Ltd |
| Primary category | Sports |
| Secondary category | Utilities |
| Age rating | 4+ (answer "None" to every content question) |
| Price | Free |
| Devices | iPhone, iPad, Apple Watch (iOS 17+, watchOS 10+) |

## URLs (nettek.uk)

| Item | URL |
|---|---|
| Support URL | https://nettek.uk/indoor-softball/ |
| Marketing URL | https://nettek.uk/indoor-softball/ |
| Privacy Policy URL | https://nettek.uk/indoor-softball/privacy/ |
| Feedback / contact email | support@nettek.uk |

Upload `Website/indoor-softball/` to the web root so both pages resolve before you submit for external TestFlight review. The same URLs and email are in `Shared/Model/AppInfo.swift` (Settings → About in the app).

## App Privacy (App Store Connect → App Privacy)

**Data Not Collected.** The app has no accounts, analytics, ads or network calls. Games and settings stay on the device; the only transfer is between the user's own iPhone and Apple Watch via WatchConnectivity. `PrivacyInfo.xcprivacy` is in both targets: no tracking, no collected data, no required-reason APIs.

## Export compliance

`ITSAppUsesNonExemptEncryption = NO` is set in both targets, so TestFlight won't ask.

## Name & subtitle

- **Name:** Indoor Softball Scorer. ("Indoor Softball" may already be taken; the home-screen name stays "Indoor Softball".)
- **Subtitle (30):** Timed innings, points scoring

## Promotional text (170)

Score indoor softball the easy way: big timer per half inning, one-tap points for every base, home runs and outs – on iPhone, iPad and Apple Watch.

## Description

Indoor Softball Scorer keeps score and time for indoor softball, where half innings are timed and every base counts.

TIMED HALF INNINGS
• Big, colour-coded countdown: green while running, amber near the end, flashing red at TIME
• Haptic and sound alerts, plus notifications if the app is in the background
• After time is up you can still enter the last scores until you start the next half

POINTS SCORING
• Batter scores per base reached off the bat: 1st +1, 2nd +2, 3rd +3, home +4
• Runners crossing home score a point each
• Home run off the back wall +5, plus a point for every runner on base
• Outs cost points: −1 for a batter or runner out, −2 for an out at home by the catcher
• Every value can be changed, with an Outdoor preset (0 per base, home run 4)

CLEAR RESULTS
• A plus and minus tally for every half inning; scores can go negative
• Running score at the end of each inning, final score and winner (−5 beats −10)
• History of finished games, shareable as text

IPHONE, IPAD AND APPLE WATCH
• Score from your wrist with the full Apple Watch app
• Settings and finished games sync between your iPhone and Apple Watch
• Large-screen iPad layout for the scorer's table

No accounts, no ads, no tracking.

## Keywords (100)

softball,indoor,scorer,scoreboard,umpire,timer,innings,points,league,scorekeeper,watch,baseball

## TestFlight

**Beta App Description**
Score keeper and half-inning timer for indoor softball on iPhone, iPad and Apple Watch. Points per base, home runs off the wall and negative points for outs; each half inning is timed.

**What to Test (build 1)**
- Start a game (Game → New Game), set the team names and check the default settings: 2 innings, 5:00 halves, 1 point per base, home run 5, out −1, out at home by the catcher −2.
- Start the clock and score every kind of play. Check the plus, minus and net tallies.
- Let the clock run out. You should get the red flashing TIME, haptics and a sound, and you should still be able to enter scores until you tap "Start …".
- Lock the phone while the clock runs and check that the 1-minute and TIME notifications arrive.
- Finish the game and check the final screen: each inning's tallies, the end-of-inning scores and the winner. A tie stands as a tie.
- Score a game on the Apple Watch and check that it appears in History on the iPhone. Change a setting on one device and check that it changes on the other.
- On iPad, try portrait and landscape.

**Feedback email:** support@nettek.uk

**Beta App Review contact:** Steve Karmeinsky, NetTek Ltd. No sign-in is needed, so leave the demo account blank.

## Upload checklist

1. In App Store Connect, create the app record (bundle ID `uk.nettek.IndoorSoftball`, SKU above).
2. In Xcode, select the **IndoorSoftball** scheme and Any iOS Device (arm64), then Product → Archive. The watch app is embedded automatically.
3. In Organizer, go to Distribute App → App Store Connect and **untick "Manage Version and Build Number"**.
4. Once the upload is confirmed, bump `CURRENT_PROJECT_VERSION` in both targets to the next number.
5. Add internal testers. For external testers, fill in the TestFlight test information above and submit for Beta App Review.

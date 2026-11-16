# Indoor Softball – Android and Wear OS

The Android phone/tablet app and the Wear OS watch app. They follow the iOS
apps in `../iOS` screen for screen and rule for rule.

## Open and run

1. Install Android Studio (Ladybug or newer).
2. **File ▸ Open** and choose this `Android` folder. Let Gradle sync.
3. Pick the `app` configuration for a phone or tablet, or `wear` for a watch,
   and press Run.

From a terminal: `./gradlew :app:assembleDebug :wear:assembleDebug`

## Modules

| Module | What it is |
| --- | --- |
| `shared` | The rules, clock, game engine, storage and results document. Plain Kotlin, no Android. The twin of `iOS/Shared/Model` and `iOS/Shared/Engine`. |
| `app` | Phone and tablet app (Jetpack Compose, Material 3). Min Android 8.0. |
| `wear` | Wear OS app (Wear Compose). Min Wear OS 3. Works on its own; no phone needed during a game. |

## Phone ↔ watch

Uses the Wearable Data Layer:

- Settings go both ways (`/settings`).
- A finished watch game goes to the phone (`/game/<id>`), where it appears in
  History and its Away, Home and Location can be edited before sharing.

For this to work both apps **must have the same application ID
(`uk.nettek.indoorsoftball`) and be signed with the same key.** Debug builds
from one computer already are.

## Keeping in step with iOS

`../SharedTests/cases.json` holds scoring and results-document cases that both
platforms must pass:

    ./gradlew :shared:test              # Android engine
    ../iOS/Tests/run-engine-checks.sh   # iOS engine (needs swiftc)

When a rule changes: add or change a case there first, then change
`shared/…/Model.kt` and `iOS/Shared/Model` until both pass.

## Checking layouts without a device

The real screens are drawn to PNG files by unit tests:

    ./gradlew :app:testDebugUnitTest    # → app/build/screens  (phone, small phone, tablet)
    ./gradlew :wear:testDebugUnitTest   # → wear/build/screens (round 192, round 225, square 180)

## Versions

`build.gradle.kts` in this folder holds `appVersionName` and `appVersionCode`
for both apps. The watch app's version code is 100000 + the phone's, because
Play needs a different code for each. Same policy as iOS: the project always
holds the **next unused** code; raise it straight after an upload.

## Play Store notes

- Upload the phone and watch bundles to the same Play listing (the watch one
  under the Wear OS form factor).
- The apps use `USE_EXACT_ALARM` so the time-up alert fires on the second.
  Play asks for a declaration: the core function is a timer.
- Notifications permission is asked for when the first clock is started.
- No data leaves the device except through the Share sheet. No accounts, no
  analytics, no adverts.

## Not yet checked on real hardware

Builds, lint, shared tests and screen renders pass. Still to try on a device
or emulator: phone ↔ watch sync, time-up alerts with the app in the background,
vibration, and the Share / Save a copy flows.

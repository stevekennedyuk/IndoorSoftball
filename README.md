# Indoor Softball

Score keeper and half-inning timer for indoor (and outdoor) softball, by NetTek Ltd.

| Folder | What it is |
|---|---|
| `iOS/` | iPhone, iPad and Apple Watch app (SwiftUI). Open `iOS/IndoorSoftball.xcodeproj` in Xcode. See `iOS/README.md`. App Store text, screenshots and upload notes are in `iOS/AppStore/`. |
| `Android/` | Android phone/tablet and Wear OS app (Kotlin, Jetpack Compose). Open the `Android` folder in Android Studio. See `Android/README.md`. |
| `Website/` | Support and privacy pages for nettek.uk (shared by both platforms). |
| `icon-source/` | Script that draws the app icon. |

Both platforms follow the same rules: `iOS/README.md` describes the scoring types, the clock and the results document, and `Android/shared` ports the same engine with the same tests.

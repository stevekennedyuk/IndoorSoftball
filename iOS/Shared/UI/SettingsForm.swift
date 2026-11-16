import SwiftUI

/// The game and scoring settings. Used in Settings, in the New Game sheet and on the Watch.
/// Changes are remembered and apply to every new game until changed again.
struct SettingsSections: View {
    @Binding var settings: GameSettings
    var compact = false

    var body: some View {
        Section {
            #if os(watchOS)
            Toggle("Outdoor scoring", isOn: Binding(
                get: { settings.scoring == .outdoor },
                set: { settings.scoring = $0 ? .outdoor : .indoor }))
            #else
            Picker("Scoring", selection: $settings.scoring) {
                ForEach(ScoringType.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            #endif
        } header: {
            Text("Scoring type")
        } footer: {
            if !compact {
                Text(settings.scoring == .indoor
                     ? "Indoor: +1, −1, HR (home run off the back wall) and OC (out by the catcher at home)."
                     : "Outdoor: runs only. +1 for a run, and HR+1, HR+2 or HR+3 for a home run with 1, 2 or 3 runners on (2, 3 or 4 runs).")
            }
        }

        Section {
            Stepper(value: $settings.innings, in: GameSettings.inningsRange) {
                row("Innings", "\(settings.innings)")
            }
            Stepper(value: $settings.halfInningSeconds,
                    in: GameSettings.halfInningRange,
                    step: GameSettings.halfInningStep) {
                row("Time per half", Theme.duration(settings.halfInningSeconds))
            }
            Stepper(value: $settings.warningSeconds, in: GameSettings.warningRange, step: 15) {
                row("Warning at", settings.warningSeconds == 0 ? "Off" : Theme.duration(settings.warningSeconds) + " left")
            }
        } header: {
            Text("Game")
        } footer: {
            if !compact {
                Text("One inning = Away bats then Home bats. Each half inning is timed; scores can still be entered after time is up until the next half is started.")
            }
        }

        if settings.scoring == .indoor {
            Section {
                Stepper(value: $settings.homeRunPoints, in: GameSettings.homeRunRange) {
                    row("Home run (HR)", settings.homeRunPoints.signedString)
                }
                Stepper(value: $settings.outAtHomeByCatcherPoints, in: GameSettings.outRange) {
                    row(compact ? "Catcher out (OC)" : "Out by catcher at home (OC)",
                        settings.outAtHomeByCatcherPoints.signedString)
                }
            } header: {
                Text("Indoor scoring")
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(compact ? .footnote : .body)
            Spacer()
            Text(value)
                .monospacedDigit()
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
    }
}

/// Team name and location fields for a new game.
struct TeamNameSection: View {
    @Binding var away: String
    @Binding var home: String
    @Binding var location: String

    var body: some View {
        Section("Teams") {
            HStack {
                Circle().fill(Theme.away).frame(width: 10, height: 10)
                TextField("Away team (bats first)", text: $away)
            }
            HStack {
                Circle().fill(Theme.home).frame(width: 10, height: 10)
                TextField("Home team", text: $home)
            }
        }
        Section("Location") {
            HStack {
                Image(systemName: "mappin.and.ellipse").foregroundStyle(.secondary)
                TextField("Location (optional)", text: $location)
            }
        }
    }
}

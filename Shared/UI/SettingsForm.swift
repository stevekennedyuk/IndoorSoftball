import SwiftUI

/// The game and scoring settings. Used in Settings, in the New Game sheet and on the Watch.
/// Changes are remembered and apply to every new game until changed again.
struct SettingsSections: View {
    @Binding var settings: GameSettings
    var compact = false

    var body: some View {
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

        Section {
            Stepper(value: $settings.homeRunPoints, in: GameSettings.homeRunRange) {
                row("Home run (HR button)", settings.homeRunPoints.signedString)
            }
        } header: {
            Text("Scoring")
        } footer: {
            if !compact {
                Text("Score with +1 and −1 for each point won or lost, and HR for a home run off the back wall (normally +5 indoors, +4 outdoors).")
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

/// Team name fields for a new game.
struct TeamNameSection: View {
    @Binding var away: String
    @Binding var home: String

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
    }
}

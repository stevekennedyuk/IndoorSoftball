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
            Stepper(value: $settings.pointsPerBase, in: GameSettings.pointsPerBaseRange) {
                row("Per base (batter)", settings.pointsPerBase.signedString)
            }
            Stepper(value: $settings.homeRunPoints, in: GameSettings.homeRunRange) {
                row("Home run (wall)", settings.homeRunPoints.signedString)
            }
            Stepper(value: $settings.runPoints, in: GameSettings.runPointsRange) {
                row("Runner crosses home", settings.runPoints.signedString)
            }
            Stepper(value: $settings.outPoints, in: GameSettings.outRange) {
                row("Batter / runner out", settings.outPoints.signedString)
            }
            Stepper(value: $settings.outAtHomeByCatcherPoints, in: GameSettings.outRange) {
                row("Out at home by catcher", settings.outAtHomeByCatcherPoints.signedString)
            }
        } header: {
            Text("Scoring")
        } footer: {
            Text(examples)
        }

        Section("Presets") {
            Button {
                settings.applyScoring(from: .indoor)
            } label: {
                Label("Indoor rules (1/base, HR 5)", systemImage: "building.2")
            }
            Button {
                settings.applyScoring(from: .outdoorVariant)
            } label: {
                Label("Outdoor variant (0/base, HR 4)", systemImage: "sun.max")
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

    private var examples: String {
        let s = settings
        let p = { (k: ScoreEventKind, r: Int) in ScoringRules.points(for: k, runnersOn: r, settings: s).signedString }
        return "Single \(p(.firstBase, 0)) · double \(p(.secondBase, 0)) · triple \(p(.thirdBase, 0)) · home on the hit \(p(.homeOnHit, 0)) · home run with bases loaded \(p(.homeRun, 3))"
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

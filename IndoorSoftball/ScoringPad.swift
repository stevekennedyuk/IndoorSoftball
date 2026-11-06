import SwiftUI

/// Big, colour-coded scoring buttons. Each shows the points it will add using
/// the game's own settings.
struct ScoringPad: View {
    @Environment(GameStore.self) private var store
    let large: Bool
    @State private var askRunners = false

    var body: some View {
        if let g = store.game {
            let s = g.settings
            VStack(alignment: .leading, spacing: 12) {
                section("Batter reached (off the bat)") {
                    HStack(spacing: 8) {
                        pad(.firstBase, s, Theme.positive)
                        pad(.secondBase, s, Theme.positive)
                        pad(.thirdBase, s, Theme.positive)
                        pad(.homeOnHit, s, Theme.positive)
                    }
                }
                section("Runs") {
                    HStack(spacing: 8) {
                        pad(.runnerHome, s, Theme.positive)
                        Button { askRunners = true } label: {
                            PadLabel(kind: .homeRun,
                                     pointsText: "\(s.homeRunPoints.signedString) +\(s.runPoints)/runner",
                                     color: Theme.warning,
                                     large: large)
                        }
                        .buttonStyle(PadButtonStyle(color: Theme.warning))
                        .frame(maxWidth: .infinity)
                        .layoutPriority(1)
                    }
                }
                section("Outs") {
                    HStack(spacing: 8) {
                        pad(.batterOut, s, Theme.negative)
                        pad(.runnerOut, s, Theme.negative)
                        pad(.outAtHomeByCatcher, s, Theme.negative)
                    }
                }
                HStack(spacing: 8) {
                    Button { store.undo() } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!store.canUndo)

                    Menu {
                        Button { store.record(.adjustPlus) } label: { Label("Correction +1", systemImage: "plus") }
                        Button { store.record(.adjustMinus) } label: { Label("Correction −1", systemImage: "minus") }
                    } label: {
                        Label("Adjust", systemImage: "plusminus")
                            .frame(maxWidth: .infinity)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
            }
            .confirmationDialog("Home run – runners on base?", isPresented: $askRunners, titleVisibility: .visible) {
                ForEach(0...3, id: \.self) { n in
                    let pts = ScoringRules.points(for: .homeRun, runnersOn: n, settings: s)
                    Button("\(n == 0 ? "Bases empty" : n == 3 ? "Bases loaded (3)" : "\(n) on base")  \(pts.signedString)") {
                        store.record(.homeRun, runnersOn: n)
                    }
                }
            } message: {
                Text("Batter scores \(s.homeRunPoints.signedString), each runner on base \(s.runPoints.signedString).")
            }
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func pad(_ kind: ScoreEventKind, _ s: GameSettings, _ color: Color) -> some View {
        Button {
            store.record(kind)
        } label: {
            PadLabel(kind: kind,
                     pointsText: ScoringRules.points(for: kind, settings: s).signedString,
                     color: color,
                     large: large)
        }
        .buttonStyle(PadButtonStyle(color: color))
        .frame(maxWidth: .infinity)
    }
}

struct PadLabel: View {
    let kind: ScoreEventKind
    let pointsText: String
    let color: Color
    let large: Bool

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: kind.symbol)
                .font(large ? .title2 : .title3)
            Text(kind.shortLabel)
                .font(large ? .subheadline.weight(.bold) : .caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(pointsText)
                .font(large ? .headline.monospacedDigit() : .subheadline.weight(.heavy).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, minHeight: large ? 96 : 76)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.longLabel), \(pointsText) points")
    }
}

import SwiftUI

/// The scoring buttons. The game's scoring type decides which set is shown:
/// - Indoor: +1 and −1 (large), then HR (home run), OC (out by the catcher at
///   home) and Undo.
/// - Outdoor: +1 (large) with Undo, then HR+1, HR+2 and HR+3 – a home run with
///   1, 2 or 3 runners on, worth 2, 3 or 4 runs.
/// The top row stretches to fill whatever height is left on screen.
struct ScoringPad: View {
    @Environment(GameStore.self) private var store
    let size: PanelSize

    private var digitFont: CGFloat { size == .large ? 64 : (size == .regular ? 50 : 40) }
    /// Height of the lower row; the top row takes all the remaining height.
    private var lowerRowHeight: CGFloat { size == .large ? 110 : (size == .regular ? 80 : 48) }
    private var gap: CGFloat { size == .compact ? 8 : 10 }
    private var undoWidth: CGFloat { size == .large ? 110 : (size == .regular ? 68 : 60) }
    private var topRowMinHeight: CGFloat { size == .compact ? 62 : 72 }

    var body: some View {
        if let g = store.game {
            if g.settings.scoring == .outdoor {
                outdoorPad
            } else {
                indoorPad(g.settings)
            }
        }
    }

    // MARK: Indoor

    private func indoorPad(_ s: GameSettings) -> some View {
        VStack(spacing: gap) {
            HStack(spacing: gap) {
                bigButton(title: "+1", subtitle: "Point", symbol: "plus", color: Theme.positive) {
                    store.record(.adjustPlus)
                }
                bigButton(title: "−1", subtitle: "Minus", symbol: "minus", color: Theme.negative) {
                    store.record(.adjustMinus)
                }
            }
            .frame(minHeight: topRowMinHeight, maxHeight: .infinity)

            HStack(spacing: gap) {
                bigButton(title: "HR \(s.homeRunPoints.signedString)", subtitle: "Home Run", symbol: "star.fill",
                          color: Theme.warning, digitScale: 0.62) {
                    store.record(.homeRun)
                }
                bigButton(title: "OC \(s.outAtHomeByCatcherPoints.signedString)", subtitle: "Out by Catcher",
                          symbol: "shield.lefthalf.filled", color: Theme.negative, digitScale: 0.62,
                          accessibility: "Out by catcher at home") {
                    store.record(.outAtHomeByCatcher)
                }
                undoButton
            }
            .frame(height: lowerRowHeight)
        }
    }

    // MARK: Outdoor

    private var outdoorPad: some View {
        VStack(spacing: gap) {
            HStack(spacing: gap) {
                bigButton(title: "+1", subtitle: "Run", symbol: "plus", color: Theme.positive) {
                    store.record(.adjustPlus)
                }
                undoButton
            }
            .frame(minHeight: topRowMinHeight, maxHeight: .infinity)

            HStack(spacing: gap) {
                ForEach(1...3, id: \.self) { runners in
                    bigButton(title: "HR+\(runners)", subtitle: "\(runners + 1) runs", symbol: "star.fill",
                              color: Theme.warning, digitScale: 0.62,
                              accessibility: "Home run plus \(runners), \(runners + 1) runs") {
                        store.record(.homeRun, runnersOn: runners)
                    }
                }
            }
            .frame(height: lowerRowHeight)
        }
    }

    // MARK: Pieces

    private var undoButton: some View {
        Button { store.undo() } label: {
            VStack(spacing: 2) {
                Image(systemName: "arrow.uturn.backward").font(.title2.weight(.bold))
                if size != .compact {
                    Text("Undo").font(.caption.weight(.semibold))
                }
            }
            .foregroundStyle(store.canUndo ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(PadButtonStyle(color: .gray))
        .frame(width: undoWidth)
        .disabled(!store.canUndo)
        .accessibilityLabel("Undo last")
    }

    private func bigButton(title: String, subtitle: String, symbol: String, color: Color,
                           digitScale: CGFloat = 1, accessibility: String? = nil,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(title)
                    .font(.system(size: digitFont * digitScale, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                Label(subtitle, systemImage: symbol)
                    .font(size == .large ? .headline : .caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(PadButtonStyle(color: color))
        .accessibilityLabel(accessibility ?? "\(subtitle), \(title)")
    }
}

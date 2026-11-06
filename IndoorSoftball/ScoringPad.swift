import SwiftUI

/// Three big scoring buttons: +1, −1 and Home Run (worth the Home Run setting).
/// The buttons stretch to fill whatever height is left on screen.
struct ScoringPad: View {
    @Environment(GameStore.self) private var store
    let size: PanelSize

    private var digitFont: CGFloat { size == .large ? 64 : (size == .regular ? 50 : 40) }

    var body: some View {
        if let g = store.game {
            let hr = g.settings.homeRunPoints
            VStack(spacing: size == .compact ? 8 : 10) {
                HStack(spacing: size == .compact ? 8 : 10) {
                    bigButton(title: "+1", subtitle: "Point", symbol: "plus", color: Theme.positive) {
                        store.record(.adjustPlus)
                    }
                    bigButton(title: "−1", subtitle: "Minus", symbol: "minus", color: Theme.negative) {
                        store.record(.adjustMinus)
                    }
                }
                .frame(minHeight: 72, maxHeight: .infinity)
                .layoutPriority(2)

                HStack(spacing: size == .compact ? 8 : 10) {
                    bigButton(title: "HR \(hr.signedString)", subtitle: "Home Run", symbol: "star.fill",
                              color: Theme.warning, digitScale: 0.7) {
                        store.record(.homeRun)
                    }
                    Button { store.undo() } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "arrow.uturn.backward").font(.title2.weight(.bold))
                            Text("Undo").font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(store.canUndo ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(PadButtonStyle(color: .gray))
                    .frame(width: size == .large ? 110 : 76)
                    .disabled(!store.canUndo)
                    .accessibilityLabel("Undo last")
                }
                .frame(minHeight: 50, maxHeight: size == .large ? 130 : 96)
                .layoutPriority(1)
            }
        }
    }

    private func bigButton(title: String, subtitle: String, symbol: String, color: Color,
                           digitScale: CGFloat = 1, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(title)
                    .font(.system(size: digitFont * digitScale, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                Label(subtitle, systemImage: symbol)
                    .font(size == .large ? .headline : .caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(PadButtonStyle(color: color))
        .accessibilityLabel("\(subtitle), \(title)")
    }
}

import SwiftUI

/// Three big scoring buttons: +1, −1 and Home Run (worth the Home Run setting).
struct ScoringPad: View {
    @Environment(GameStore.self) private var store
    let large: Bool

    var body: some View {
        if let g = store.game {
            let hr = g.settings.homeRunPoints
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    bigButton(title: "+1", subtitle: "Point", symbol: "plus", color: Theme.positive) {
                        store.record(.adjustPlus)
                    }
                    bigButton(title: "−1", subtitle: "Minus", symbol: "minus", color: Theme.negative) {
                        store.record(.adjustMinus)
                    }
                }
                bigButton(title: "HR  \(hr.signedString)", subtitle: "Home Run", symbol: "star.fill",
                          color: Theme.warning, height: large ? 110 : 88) {
                    store.record(.homeRun)
                }
                Button { store.undo() } label: {
                    Label("Undo last", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!store.canUndo)
            }
        }
    }

    private func bigButton(title: String, subtitle: String, symbol: String, color: Color,
                           height: CGFloat? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: large ? 64 : 52, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Label(subtitle, systemImage: symbol)
                    .font(large ? .headline : .subheadline.weight(.semibold))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, minHeight: height ?? (large ? 170 : 140))
        }
        .buttonStyle(PadButtonStyle(color: color))
        .accessibilityLabel("\(subtitle), \(title)")
    }
}

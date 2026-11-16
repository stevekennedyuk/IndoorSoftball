import SwiftUI

/// Thin progress bar for the half-inning clock.
struct ProgressBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule().fill(color).frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 8)
    }
}

/// Tinted, rounded button used for the scoring pads on iPhone, iPad and Watch.
struct PadButtonStyle: ButtonStyle {
    let color: Color
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(color.opacity(configuration.isPressed ? 0.40 : 0.16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(color.opacity(0.55), lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(isEnabled ? 1 : 0.4)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

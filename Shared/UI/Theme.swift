import SwiftUI

enum Theme {
    static let away = Color(red: 0.26, green: 0.58, blue: 1.00)
    static let home = Color(red: 1.00, green: 0.50, blue: 0.20)
    static let positive = Color(red: 0.22, green: 0.82, blue: 0.42)
    static let negative = Color(red: 1.00, green: 0.32, blue: 0.32)
    static let warning = Color(red: 1.00, green: 0.76, blue: 0.05)
    static let idle = Color(white: 0.55)
    static let powderBlue = Color(red: 0.70, green: 0.83, blue: 0.93)   // umpire shirt blue (app icon)
    static let card = Color(white: 0.13)
    static let cardRaised = Color(white: 0.19)

    static func color(_ team: Team) -> Color { team == .away ? away : home }

    static func pointsColor(_ p: Int) -> Color {
        p > 0 ? positive : (p < 0 ? negative : idle)
    }

    static func clockColor(_ status: ClockStatus) -> Color {
        switch status {
        case .ready: idle
        case .running: positive
        case .paused: Color(red: 0.55, green: 0.70, blue: 1.0)
        case .warning: warning
        case .timeUp: negative
        case .closed: idle
        }
    }

    /// "4:59" while counting down; "0:00" once time is up (the clock stops there).
    static func clock(_ remaining: TimeInterval) -> String {
        let s = Int(max(0, remaining).rounded(.up))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// "5:00", "4:30", "30s" for settings.
    static func duration(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds)s" : String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    static func statusText(_ status: ClockStatus) -> String {
        switch status {
        case .ready: "Ready"
        case .running: "Running"
        case .paused: "Paused"
        case .warning: "Nearly time"
        case .timeUp: "TIME"
        case .closed: "Final"
        }
    }
}

/// A pulsing modifier for the "time up" state.
struct Pulsing: ViewModifier {
    var active: Bool
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .opacity(active && on ? 0.35 : 1)
            .onAppear { start() }
            .onChange(of: active) { _, _ in start() }
    }

    private func start() {
        guard active else {
            withAnimation(.easeOut(duration: 0.1)) { on = false }
            return
        }
        withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) { on = true }
    }
}

extension View {
    func pulsing(_ active: Bool) -> some View { modifier(Pulsing(active: active)) }
}

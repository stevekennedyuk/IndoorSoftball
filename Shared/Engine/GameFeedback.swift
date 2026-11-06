import Foundation

/// Platform hooks the game engine calls: haptics, notifications, screen-awake.
/// Each app supplies its own implementation (iPhone/iPad and Watch).
@MainActor
protocol GameFeedback: AnyObject {
    /// Light confirmation for a scoring tap.
    func scored(points: Int)
    /// The clock has reached the warning threshold.
    func warning()
    /// The clock has hit zero.
    func timeUp()
    /// A half inning or the game has been closed.
    func halfClosed()
    /// Schedule background alerts for the running clock (nil = nothing running).
    func scheduleAlerts(timeUpAt: Date?, warningAt: Date?, halfLabel: String)
    /// Called when a game starts or finishes (e.g. to keep the screen awake).
    func gameActiveChanged(_ active: Bool)
}

/// Does nothing — used in tests and previews.
@MainActor
final class SilentFeedback: GameFeedback {
    var log: [String] = []
    init() {}
    func scored(points: Int) { log.append("scored \(points)") }
    func warning() { log.append("warning") }
    func timeUp() { log.append("timeUp") }
    func halfClosed() { log.append("halfClosed") }
    func scheduleAlerts(timeUpAt: Date?, warningAt: Date?, halfLabel: String) {}
    func gameActiveChanged(_ active: Bool) {}
}

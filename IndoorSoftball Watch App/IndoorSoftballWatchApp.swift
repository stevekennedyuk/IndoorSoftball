import SwiftUI
import WatchKit

@main
struct IndoorSoftballWatchApp: App {
    @State private var store: GameStore
    private let feedback: WatchFeedback

    init() {
        let fb = WatchFeedback()
        let s = GameStore(deviceName: "Watch", feedback: fb)
        _store = State(initialValue: s)
        feedback = fb
        SyncManager.shared.attach(s)
        AlertScheduler.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(store)
                .tint(Theme.positive)
        }
    }
}

/// Wrist haptics and notifications.
@MainActor
final class WatchFeedback: GameFeedback {
    private var device: WKInterfaceDevice { .current() }

    func scored(points: Int) { device.play(points >= 0 ? .click : .directionDown) }

    func warning() { device.play(.notification) }

    func timeUp() {
        Task { @MainActor in
            for i in 0..<4 {
                if i > 0 { try? await Task.sleep(for: .milliseconds(600)) }
                WKInterfaceDevice.current().play(i == 0 ? .notification : .failure)
            }
        }
    }

    func halfClosed() { device.play(.success) }

    func scheduleAlerts(timeUpAt: Date?, warningAt: Date?, halfLabel: String) {
        AlertScheduler.schedule(timeUpAt: timeUpAt, warningAt: warningAt, halfLabel: halfLabel)
    }

    func gameActiveChanged(_ active: Bool) {}
}

import UIKit
import AudioToolbox

/// Haptics, sounds, notifications and screen-awake for iPhone and iPad.
@MainActor
final class PhoneFeedback: GameFeedback {
    private let tap = UIImpactFeedbackGenerator(style: .medium)
    private let notify = UINotificationFeedbackGenerator()

    func scored(points: Int) {
        if points >= 0 { tap.impactOccurred() } else { notify.notificationOccurred(.warning) }
    }

    func warning() {
        notify.notificationOccurred(.warning)
        AudioServicesPlaySystemSound(1057) // short tick
    }

    func timeUp() {
        // Three strong bursts plus a sound — hard to miss in a noisy hall.
        Task { @MainActor [notify] in
            for i in 0..<3 {
                if i > 0 { try? await Task.sleep(for: .milliseconds(450)) }
                notify.notificationOccurred(.error)
                AudioServicesPlayAlertSound(1005)
            }
        }
    }

    func halfClosed() { notify.notificationOccurred(.success) }

    func scheduleAlerts(timeUpAt: Date?, warningAt: Date?, halfLabel: String) {
        AlertScheduler.schedule(timeUpAt: timeUpAt, warningAt: warningAt, halfLabel: halfLabel)
    }

    func gameActiveChanged(_ active: Bool) {
        UIApplication.shared.isIdleTimerDisabled = active
    }
}

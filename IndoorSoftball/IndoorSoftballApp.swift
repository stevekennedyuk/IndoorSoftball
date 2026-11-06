import SwiftUI

@main
struct IndoorSoftballApp: App {
    @State private var store: GameStore
    private let feedback: PhoneFeedback

    init() {
        let fb = PhoneFeedback()
        let device = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        let s = GameStore(deviceName: device, feedback: fb)
        _store = State(initialValue: s)
        feedback = fb
        SyncManager.shared.attach(s)
        AlertScheduler.requestAuthorization()
        // Keep the screen on if we relaunch into a game in progress.
        fb.gameActiveChanged(s.game.map { !$0.isFinished } ?? false)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
                .tint(Theme.positive)
        }
    }
}

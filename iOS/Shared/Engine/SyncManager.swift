#if canImport(WatchConnectivity)
import Foundation
import WatchConnectivity

/// Keeps the iPhone and Apple Watch in step:
/// - Settings changed on either device are copied to the other.
/// - Finished games are copied both ways so History on the phone shows games
///   scored on the watch (and vice versa).
/// Each device scores its own game independently. iPad has no paired watch,
/// so this quietly does nothing there.
@MainActor
final class SyncManager: NSObject {
    static let shared = SyncManager()

    private weak var store: GameStore?
    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    func attach(_ store: GameStore) {
        self.store = store
        store.onSettingsChanged = { [weak self] s in self?.send(settings: s) }
        store.onGameFinished = { [weak self] g in self?.send(game: g) }
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    private func send(settings: GameSettings) {
        guard let session, session.activationState == .activated,
              let data = Persistence.encode(settings) else { return }
        try? session.updateApplicationContext(["settings": data, "sent": Date().timeIntervalSince1970])
    }

    private func send(game: Game) {
        guard let session, session.activationState == .activated,
              let data = Persistence.encode(game) else { return }
        session.transferUserInfo(["game": data])
    }

    fileprivate func handle(_ payload: [String: Any]) {
        if let data = payload["settings"] as? Data, let s = Persistence.decode(GameSettings.self, from: data) {
            store?.receiveRemoteSettings(s)
        }
        if let data = payload["game"] as? Data, let g = Persistence.decode(Game.self, from: data) {
            store?.receiveRemoteGame(g)
        }
    }

    fileprivate func activated() {
        guard let session, let store else { return }
        // Pick up anything sent while we weren't running.
        let ctx = session.receivedApplicationContext
        if !ctx.isEmpty { handle(ctx) }
        else { send(settings: store.settings) }
    }
}

extension SyncManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.activated() }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let payload = Self.sendable(applicationContext)
        Task { @MainActor in self.handle(payload.value) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let payload = Self.sendable(userInfo)
        Task { @MainActor in self.handle(payload.value) }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif

    /// Wraps the plist dictionary so it can cross to the main actor.
    private struct Payload: @unchecked Sendable { let value: [String: Any] }
    nonisolated private static func sendable(_ d: [String: Any]) -> Payload { Payload(value: d) }
}
#endif

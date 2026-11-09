import Foundation
import Observation

/// What the clock is doing, for colouring the UI.
enum ClockStatus: Equatable, Sendable {
    case ready      // not started yet
    case running
    case paused
    case warning    // running, inside the warning window
    case timeUp     // reached zero — half is over, scores still allowed until the next half starts
    case closed     // game finished
}

/// The single source of truth for the app: settings, the game in progress and
/// finished games. All scoring and timing rules live here so the iPhone/iPad
/// and Watch apps behave identically.
@MainActor
@Observable
final class GameStore {
    // MARK: State

    /// Settings for the next game. Saved on change and carried forward until changed.
    var settings: GameSettings {
        didSet {
            guard settings != oldValue else { return }
            persistence.saveSettings(settings)
            if !applyingRemote { onSettingsChanged?(settings) }
        }
    }

    /// The game being scored (or just finished and still on screen).
    private(set) var game: Game? {
        didSet { persistence.saveCurrentGame(game) }
    }

    /// Finished games, newest first.
    private(set) var history: [Game] {
        didSet { persistence.saveHistory(history) }
    }

    /// Updated a few times a second while a game is open; views can read it to refresh.
    private(set) var now: Date = Date()

    // MARK: Collaborators

    @ObservationIgnored let deviceName: String
    @ObservationIgnored private let persistence: Persistence
    @ObservationIgnored weak var feedback: GameFeedback?
    /// Called when settings change locally (to sync to the paired device).
    @ObservationIgnored var onSettingsChanged: ((GameSettings) -> Void)?
    /// Called when a game is finished (to send it to the paired device).
    @ObservationIgnored var onGameFinished: ((Game) -> Void)?
    /// Called whenever a finished game is added to History – locally or from the
    /// paired device – so the iPhone/iPad app can save its results file.
    @ObservationIgnored var onGameArchived: ((Game) -> Void)?
    /// Called when a finished game's team names are changed (old, new).
    @ObservationIgnored var onGameRenamed: ((Game, Game) -> Void)?
    /// Called when games are removed from History; Bool = also delete their files.
    @ObservationIgnored var onGamesDeleted: (([Game], Bool) -> Void)?

    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored private var warnedHalf: Int?
    @ObservationIgnored private var timeUpHalf: Int?
    @ObservationIgnored private var applyingRemote = false

    init(persistence: Persistence = .standard, deviceName: String, feedback: GameFeedback? = nil, startTicker: Bool = true) {
        self.persistence = persistence
        self.deviceName = deviceName
        self.feedback = feedback
        self.settings = persistence.loadSettings()
        self.history = persistence.loadHistory()
        self.game = persistence.loadCurrentGame()
        // Don't replay alerts that already fired before the app was closed.
        if let g = game {
            let rem = g.current.timer.remaining(at: now)
            if rem <= TimeInterval(g.settings.warningSeconds) { warnedHalf = g.currentIndex }
            if rem <= 0 { timeUpHalf = g.currentIndex }
        }
        if startTicker { startTicking() }
    }

    // MARK: Clock

    private func startTicking() {
        ticker?.invalidate()
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    /// Advances the clock and fires warning / time-up alerts once each per half.
    func tick(at date: Date = Date()) {
        now = date
        guard let g = game, !g.isFinished else { return }
        let half = g.current
        guard half.timer.hasStarted else { return }
        let remaining = half.timer.remaining(at: date)
        let warnAt = TimeInterval(g.settings.warningSeconds)
        if warnAt > 0, remaining <= warnAt, remaining > 0, warnedHalf != g.currentIndex {
            warnedHalf = g.currentIndex
            feedback?.warning()
        }
        if remaining <= 0 {
            // Time is up: the clock stops at exactly 0:00 and the half is over.
            // Scores can still be entered until the next half is started.
            if let end = half.timer.endDate {
                var stopped = g
                stopped.halves[g.currentIndex].timer.pause(at: end)
                game = stopped
            }
            if timeUpHalf != g.currentIndex {
                timeUpHalf = g.currentIndex
                warnedHalf = g.currentIndex
                feedback?.timeUp()
            }
        }
    }

    func clockStatus(at date: Date? = nil) -> ClockStatus {
        guard let g = game else { return .ready }
        if g.isFinished { return .closed }
        let t = g.current.timer
        let at = date ?? now
        if t.hasStarted && t.remaining(at: at) <= 0 { return .timeUp }
        if !t.hasStarted { return .ready }
        if !t.isRunning { return .paused }
        if t.remaining(at: at) <= TimeInterval(g.settings.warningSeconds) { return .warning }
        return .running
    }

    func remaining(at date: Date? = nil) -> TimeInterval {
        game?.current.timer.remaining(at: date ?? now) ?? TimeInterval(settings.halfInningSeconds)
    }

    // MARK: Game lifecycle

    /// Starts a new game with the current settings (which are remembered for next time).
    /// `rememberNames: false` (the Watch) uses the names for this game only,
    /// without changing the names remembered in Settings.
    func newGame(awayName: String? = nil, homeName: String? = nil, location: String? = nil,
                 rememberNames: Bool = true, at date: Date = Date()) {
        if rememberNames {
            if let away = awayName { settings.awayName = away }
            if let home = homeName { settings.homeName = home }
            if let loc = location { settings.location = loc }
        }
        settings = settings.sanitized()
        // A finished game on screen is already in history; an unfinished one is abandoned.
        game = Game(settings: settings,
                    awayName: awayName ?? settings.awayName,
                    homeName: homeName ?? settings.homeName,
                    location: rememberNames ? (location ?? settings.location) : location,
                    at: date, scoredOn: deviceName)
        warnedHalf = nil
        timeUpHalf = nil
        now = date
        feedback?.scheduleAlerts(timeUpAt: nil, warningAt: nil, halfLabel: "")
        feedback?.gameActiveChanged(true)
    }

    /// Throws away the game in progress without saving it.
    func discardGame() {
        game = nil
        feedback?.scheduleAlerts(timeUpAt: nil, warningAt: nil, halfLabel: "")
        feedback?.gameActiveChanged(false)
    }

    /// Clears a finished game from the main screen (it stays in history).
    func closeFinishedGame() {
        guard game?.isFinished == true else { return }
        game = nil
    }

    // MARK: Timer control

    func startClock(at date: Date = Date()) {
        guard var g = game, !g.isFinished else { return }
        if g.playStartedAt == nil { g.playStartedAt = date }
        g.halves[g.currentIndex].timer.start(at: date)
        game = g
        now = date
        rescheduleAlerts()
    }

    func pauseClock(at date: Date = Date()) {
        guard var g = game, !g.isFinished else { return }
        g.halves[g.currentIndex].timer.pause(at: date)
        game = g
        now = date
        rescheduleAlerts()
    }

    func toggleClock(at date: Date = Date()) {
        guard let g = game else { return }
        if g.current.timer.isRunning { pauseClock(at: date) } else { startClock(at: date) }
    }

    /// Adds (positive) or takes off (negative) time from the current half's clock.
    func addTime(_ seconds: TimeInterval, at date: Date = Date()) {
        guard var g = game, !g.isFinished else { return }
        g.halves[g.currentIndex].timer.addTime(seconds, at: date)
        game = g
        now = date
        let rem = g.current.timer.remaining(at: date)
        // Allow alerts to fire again if time was added back.
        if rem > 0, timeUpHalf == g.currentIndex { timeUpHalf = nil }
        if rem > TimeInterval(g.settings.warningSeconds), warnedHalf == g.currentIndex { warnedHalf = nil }
        rescheduleAlerts()
    }

    private func rescheduleAlerts() {
        guard let g = game, !g.isFinished, let end = g.current.timer.endDate, end > now else {
            feedback?.scheduleAlerts(timeUpAt: nil, warningAt: nil, halfLabel: "")
            return
        }
        let warn = g.settings.warningSeconds > 0 ? end.addingTimeInterval(-TimeInterval(g.settings.warningSeconds)) : nil
        feedback?.scheduleAlerts(timeUpAt: end, warningAt: (warn ?? now) > now ? warn : nil, halfLabel: g.current.label)
    }

    // MARK: Scoring

    /// Records a scoring event in the open half. Allowed after time is up,
    /// right up until the next half is started.
    @discardableResult
    func record(_ kind: ScoreEventKind, runnersOn: Int = 0, at date: Date = Date()) -> ScoreEvent? {
        guard var g = game, !g.isFinished else { return nil }
        let event = ScoringRules.makeEvent(kind, runnersOn: runnersOn, settings: g.settings, at: date)
        g.halves[g.currentIndex].events.append(event)
        game = g
        feedback?.scored(points: event.points)
        return event
    }

    var canUndo: Bool { !(game?.current.events.isEmpty ?? true) && game?.isFinished == false }

    /// Removes the most recent entry in the open half.
    func undo() {
        guard var g = game, !g.isFinished, !g.current.events.isEmpty else { return }
        g.halves[g.currentIndex].events.removeLast()
        game = g
    }

    /// Removes a specific entry from the open half.
    func deleteEvent(id: UUID) {
        guard var g = game, !g.isFinished else { return }
        g.halves[g.currentIndex].events.removeAll { $0.id == id }
        game = g
    }

    // MARK: Moving between halves

    /// Closes the open half and opens the next one. Scores can no longer be
    /// changed for the closed half. On the last half use `finishGame()`.
    func startNextHalf(at date: Date = Date()) {
        guard var g = game, !g.isFinished, !g.isLastHalf else { return }
        g.halves[g.currentIndex].timer.stop(at: date)
        g.halves[g.currentIndex].closedAt = date
        g.currentIndex += 1
        game = g
        now = date
        warnedHalf = nil
        timeUpHalf = nil
        feedback?.halfClosed()
        rescheduleAlerts()
    }

    /// Used by the clock's "Start Bottom 1" button once time is up: locks the
    /// finished half and starts the next half's clock in one tap.
    func startNextHalfAndClock(at date: Date = Date()) {
        guard let g = game, !g.isFinished, !g.isLastHalf else { return }
        startNextHalf(at: date)
        startClock(at: date)
    }

    /// Ends the game (normally after the last half; can also end early).
    func finishGame(at date: Date = Date()) {
        guard var g = game, !g.isFinished else { return }
        g.halves[g.currentIndex].timer.stop(at: date)
        g.halves[g.currentIndex].closedAt = date
        g.phase = .finished
        g.endedAt = date
        game = g
        now = date
        upsertHistory(g)
        feedback?.halfClosed()
        feedback?.scheduleAlerts(timeUpAt: nil, warningAt: nil, halfLabel: "")
        feedback?.gameActiveChanged(false)
        onGameFinished?(g)
    }

    // MARK: History

    private func upsertHistory(_ g: Game) {
        var h = history.filter { $0.id != g.id }
        h.append(g)
        h.sort { $0.playStart > $1.playStart }
        history = h
        onGameArchived?(g)
    }

    /// Removes games from History; `deleteFiles` also removes their results files.
    func deleteHistory(ids: Set<UUID>, deleteFiles: Bool = false) {
        let removed = history.filter { ids.contains($0.id) }
        history.removeAll { ids.contains($0.id) }
        onGamesDeleted?(removed, deleteFiles)
    }

    /// Changes the team names and location of a finished game (e.g. one scored on
    /// the Watch as Away v Home). Its results file is renamed to match.
    func updateDetails(gameID: UUID, away: String, home: String, location: String) {
        let a = away.trimmingCharacters(in: .whitespaces)
        let h = home.trimmingCharacters(in: .whitespaces)
        let l = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let i = history.firstIndex(where: { $0.id == gameID }) else { return }
        let old = history[i]
        var new = old
        new.awayName = a.isEmpty ? "Away" : a
        new.homeName = h.isEmpty ? "Home" : h
        new.location = l.isEmpty ? nil : l
        guard new != old else { return }
        history[i] = new
        if game?.id == gameID { game = new }
        onGameRenamed?(old, new)
    }

    // MARK: Sync from the paired device

    func receiveRemoteSettings(_ s: GameSettings) {
        applyingRemote = true
        settings = s.sanitized()
        applyingRemote = false
    }

    func receiveRemoteGame(_ g: Game) {
        guard g.isFinished else { return }
        upsertHistory(g)
    }
}

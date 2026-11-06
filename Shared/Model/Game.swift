import Foundation

enum Team: String, Codable, CaseIterable, Sendable {
    case away, home
}

/// A countdown clock for one half inning. Stored as wall-clock values so it
/// stays correct while the app is in the background or the watch screen is off.
struct HalfTimer: Codable, Equatable, Sendable {
    var duration: TimeInterval
    /// Time run before the current running stretch.
    var accumulated: TimeInterval = 0
    /// When the current running stretch began (nil = paused / not started).
    var runningSince: Date? = nil

    var isRunning: Bool { runningSince != nil }
    var hasStarted: Bool { isRunning || accumulated > 0 }

    func elapsed(at now: Date) -> TimeInterval {
        accumulated + (runningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    /// Seconds left (never below zero once the store has stopped the clock).
    func remaining(at now: Date) -> TimeInterval {
        duration - elapsed(at: now)
    }

    func isExpired(at now: Date) -> Bool { remaining(at: now) <= 0 }

    /// When the clock will hit zero, if running.
    var endDate: Date? {
        guard let since = runningSince else { return nil }
        return since.addingTimeInterval(duration - accumulated)
    }

    /// 0...1 fraction used.
    func progress(at now: Date) -> Double {
        guard duration > 0 else { return 1 }
        return min(1, max(0, elapsed(at: now) / duration))
    }

    mutating func start(at now: Date) {
        guard runningSince == nil else { return }
        runningSince = now
    }

    mutating func pause(at now: Date) {
        guard let since = runningSince else { return }
        accumulated += max(0, now.timeIntervalSince(since))
        runningSince = nil
    }

    /// Adds (or with a negative value removes) time from the clock.
    mutating func addTime(_ seconds: TimeInterval, at now: Date) {
        // Adjust what has been used, never below zero used.
        let used = elapsed(at: now)
        let newUsed = max(0, used - seconds)
        if runningSince != nil {
            accumulated = newUsed
            runningSince = now
        } else {
            accumulated = newUsed
        }
    }

    /// Stops the clock for good (used when the half is closed).
    mutating func stop(at now: Date) { pause(at: now) }
}

struct HalfInning: Codable, Identifiable, Equatable, Sendable {
    /// 0-based: 0 = Top 1, 1 = Bottom 1, 2 = Top 2…
    let index: Int
    var events: [ScoreEvent] = []
    var timer: HalfTimer
    var closedAt: Date? = nil

    var id: Int { index }
    var inning: Int { index / 2 + 1 }
    var isTop: Bool { index % 2 == 0 }
    var battingTeam: Team { isTop ? .away : .home }

    var positive: Int { events.filter { $0.points > 0 }.reduce(0) { $0 + $1.points } }
    var negative: Int { events.filter { $0.points < 0 }.reduce(0) { $0 + $1.points } }
    var net: Int { events.reduce(0) { $0 + $1.points } }

    var label: String { "\(isTop ? "Top" : "Bottom") \(inning)" }
    var shortLabel: String { "\(isTop ? "▲" : "▼")\(inning)" }
}

/// A whole game. Away bats in the top (even-indexed) halves.
struct Game: Codable, Identifiable, Equatable, Sendable {
    enum Phase: String, Codable, Sendable { case inProgress, finished }

    var id: UUID = UUID()
    var settings: GameSettings
    var awayName: String
    var homeName: String
    var halves: [HalfInning]
    /// The half currently open for scoring.
    var currentIndex: Int = 0
    var phase: Phase = .inProgress
    var startedAt: Date
    var endedAt: Date? = nil
    /// "iPhone", "iPad", "Watch" — where it was scored.
    var scoredOn: String = ""

    init(settings: GameSettings, awayName: String, homeName: String, at date: Date = Date(), scoredOn: String = "") {
        let s = settings.sanitized()
        self.settings = s
        self.awayName = awayName.trimmingCharacters(in: .whitespaces).isEmpty ? "Away" : awayName
        self.homeName = homeName.trimmingCharacters(in: .whitespaces).isEmpty ? "Home" : homeName
        self.halves = (0..<s.halvesCount).map {
            HalfInning(index: $0, timer: HalfTimer(duration: TimeInterval(s.halfInningSeconds)))
        }
        self.startedAt = date
        self.scoredOn = scoredOn
    }

    // MARK: Derived

    var isFinished: Bool { phase == .finished }
    var current: HalfInning { halves[currentIndex] }
    var isLastHalf: Bool { currentIndex == halves.count - 1 }
    var inningsCount: Int { halves.count / 2 }

    func name(_ team: Team) -> String { team == .away ? awayName : homeName }

    /// Halves that have been reached (closed or currently open).
    var playedHalves: ArraySlice<HalfInning> { halves[0...currentIndex] }

    func halves(for team: Team) -> [HalfInning] {
        halves.filter { $0.battingTeam == team }
    }

    func half(team: Team, inning: Int) -> HalfInning? {
        let idx = (inning - 1) * 2 + (team == .away ? 0 : 1)
        return halves.indices.contains(idx) ? halves[idx] : nil
    }

    /// Whether a half has been reached yet.
    func isReached(_ half: HalfInning) -> Bool { half.index <= currentIndex }

    func total(_ team: Team) -> Int {
        playedHalves.filter { $0.battingTeam == team }.reduce(0) { $0 + $1.net }
    }

    func positiveTotal(_ team: Team) -> Int {
        playedHalves.filter { $0.battingTeam == team }.reduce(0) { $0 + $1.positive }
    }

    func negativeTotal(_ team: Team) -> Int {
        playedHalves.filter { $0.battingTeam == team }.reduce(0) { $0 + $1.negative }
    }

    /// Team's running total at the end of the given inning (1-based).
    func cumulative(_ team: Team, throughInning inning: Int) -> Int {
        halves.filter { $0.battingTeam == team && $0.inning <= inning && isReached($0) }
            .reduce(0) { $0 + $1.net }
    }

    /// Highest score wins (so −5 beats −10). nil = tie (ties stand — no extra innings).
    var leader: Team? {
        let a = total(.away), h = total(.home)
        if a == h { return nil }
        return a > h ? .away : .home
    }

    var winner: Team? { isFinished ? leader : nil }

    var resultText: String {
        let a = total(.away), h = total(.home)
        guard let w = leader else { return "Tied \(a.scoreString) – \(h.scoreString)" }
        let (ws, ls) = w == .away ? (a, h) : (h, a)
        return "\(name(w)) win \(ws.scoreString) – \(ls.scoreString)"
    }
}
